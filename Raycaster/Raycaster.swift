//
//  Raycaster.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation
import MetalKit
import simd

enum defferredBufferType : Int, CaseIterable {
    case DBT_POS = 0
    case DBT_GRAD
    case DBT_H_II
    case DBT_H_IJ
}

class Raycaster {
    var _PSO_raycast : [MTLComputePipelineState?] = []
    var _PSO_raycastTiled : [MTLComputePipelineState?] = []
    var _PSO_evalGradient : [MTLComputePipelineState?] = []
    let _PSO_initTiledBuffer : MTLComputePipelineState?
    let _PSO_updateTiledBuffer : MTLComputePipelineState?
    
    var d_defferredFineBuffer : [MTLTexture?] = []
    var d_defferredCoarseBuffer : [MTLTexture?] = []
    
    var currentkernel : Int = 0

    init(device:MTLDevice?, library:MTLLibrary?, raySpaceBound:MTLSize?)
    {
        guard let device, let library, let raySpaceBound else { fatalError("Error : Unable to create raycaster.") }
        
        // make compute PSOs
        for var kernelType in 0..<KT_NR_KERNELS.rawValue {
            let constantValue = MTLFunctionConstantValues()
            constantValue.setConstantValue(&kernelType,
                                          type: MTLDataType.int,
                                          index: Int(FC_KERNEL_TYPE.rawValue))
            let FUNC_evalGradient = try? library.makeFunction(name: "evalDifferences", constantValues: constantValue)
            
            var isTiled = false
            constantValue.setConstantValue(&isTiled,
                                          type: MTLDataType.bool,
                                          index: Int(FC_IS_TILED.rawValue))
            let FUNC_raycast = try? library.makeFunction(name: "raycast", constantValues: constantValue)
            isTiled = true
            constantValue.setConstantValue(&isTiled,
                                          type: MTLDataType.bool,
                                          index: Int(FC_IS_TILED.rawValue))
            let FUNC_raycastTiled = try? library.makeFunction(name: "raycast", constantValues: constantValue)

            let PSO_raycast = try? device.makeComputePipelineState(function: FUNC_raycast!)
            let PSO_raycastTiled = try? device.makeComputePipelineState(function: FUNC_raycastTiled!)
            let PSO_evalGradient = try? device.makeComputePipelineState(function: FUNC_evalGradient!)
            
            self._PSO_raycast.append(PSO_raycast)
            self._PSO_raycastTiled.append(PSO_raycastTiled)
            self._PSO_evalGradient.append(PSO_evalGradient)
        }
        
        let FUNC_initTiledBuffer = library.makeFunction(name: "initTiledBuffer")
        self._PSO_initTiledBuffer = try? device.makeComputePipelineState(function: FUNC_initTiledBuffer!)
        let FUNC_updateTiledBuffer = library.makeFunction(name: "updateTiledBuffer")
        self._PSO_updateTiledBuffer = try? device.makeComputePipelineState(function: FUNC_updateTiledBuffer!)

        // make defferred textures
        let tex_descr = MTLTextureDescriptor()
        tex_descr.textureType = .type2D
        tex_descr.pixelFormat = .rgba16Float
        tex_descr.width = raySpaceBound.width
        tex_descr.height = raySpaceBound.height
        tex_descr.storageMode = .private
        tex_descr.usage = [.shaderWrite, .shaderRead]
        for _ in defferredBufferType.allCases {
            self.d_defferredFineBuffer.append(device.makeTexture(descriptor: tex_descr))
        }

        tex_descr.width = 128
        tex_descr.height = 128
        for _ in defferredBufferType.allCases {
            self.d_defferredCoarseBuffer.append(device.makeTexture(descriptor: tex_descr))
        }
        
    }
    
    func getQICoeff() -> simd_float4
    {
        let krn = KernelType(rawValue: UInt32(self.currentkernel))
        switch krn {
            case KT_CC6 : return simd_float4(2, -1/6, 0, 0)
            case KT_FCCV2 : return simd_float4(1, 0, 0, 0)
            case KT_FCCV3 : return simd_float4(36/24, -1/24, 0.0, 0.0)
            default : return simd_float4(1, 0, 0, 0)
        }
    }
    func setKernel(KernelType krn : KernelType) {
        self.currentkernel = Int(krn.rawValue)
    }
    
    func raycastingTiled(commanBuffer cmdBuffer:MTLCommandBuffer?,
                         data:VolumeData?,
                         camera:Camera,
                         tileOffset:simd_uint2,
                         tileScale:simd_uint2,
                         isUpdate:Bool)
    {
        let cmptEncoder = cmdBuffer?.makeComputeCommandEncoder()
        let threadsPerGroup = MTLSizeMake(8,8,1)
        let threadBlocksPerGridTiled = MTLSizeMake(128/threadsPerGroup.width,
                                                   128/threadsPerGroup.height,
                                                   1)
        
        var invMVP : simd_float4x4 = simd_mul(simd_mul(camera.P, camera.V), data!.M).inverse

        var scale = tileScale
        var offset = tileOffset
        
        // raycasting
        cmptEncoder?.setComputePipelineState(self._PSO_raycastTiled[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferredCoarseBuffer[defferredBufferType.DBT_POS.rawValue], index: 0)
        cmptEncoder?.setTexture(data!.getData(), index: 1)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 0)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        cmptEncoder?.setBytes(&data!.level,
                              length: MemoryLayout<Float>.size,
                              index: 2)
        cmptEncoder?.setBytes(&invMVP,
                              length: MemoryLayout<simd_float4x4>.size,
                              index: 3)
        cmptEncoder?.setBytes(&offset,
                              length: MemoryLayout<vector_float4>.size,
                              index: 4)
        cmptEncoder?.setBytes(&scale,
                              length: MemoryLayout<vector_float4>.size,
                              index: 5)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // compute differences
        cmptEncoder?.setComputePipelineState(self._PSO_evalGradient[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferredCoarseBuffer[defferredBufferType.DBT_GRAD.rawValue], index: 0)
        cmptEncoder?.setTexture(self.d_defferredCoarseBuffer[defferredBufferType.DBT_H_II.rawValue], index: 1)
        cmptEncoder?.setTexture(self.d_defferredCoarseBuffer[defferredBufferType.DBT_H_IJ.rawValue], index: 2)
        cmptEncoder?.setTexture(self.d_defferredCoarseBuffer[defferredBufferType.DBT_POS.rawValue], index: 3)
        cmptEncoder?.setTexture(data!.getData(), index: 4)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 0)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // update buffer
        if isUpdate {
            cmptEncoder?.setComputePipelineState(self._PSO_updateTiledBuffer!)
            cmptEncoder?.setBytes(&offset,
                                  length: MemoryLayout<vector_uint2>.size,
                                  index: 1)
        } else {
            cmptEncoder?.setComputePipelineState(self._PSO_initTiledBuffer!)
        }
        cmptEncoder?.setBytes(&scale,
                              length: MemoryLayout<vector_uint2>.size,
                              index: 0)

        cmptEncoder?.setTextures(self.d_defferredFineBuffer, range: 0..<4)
        cmptEncoder?.setTextures(self.d_defferredCoarseBuffer, range: 4..<8)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        cmptEncoder?.endEncoding()
    }
    
    func raycasting(commanBuffer cmdBuffer:MTLCommandBuffer?,
                         data:VolumeData?,
                         camera:Camera)
    {
        let cmptEncoder = cmdBuffer?.makeComputeCommandEncoder()
        let threadsPerGroup = MTLSizeMake(8,8,1)
        let threadBlocksPerGridTiled = MTLSizeMake(self.d_defferredFineBuffer[0]!.width/threadsPerGroup.width,
                                                   self.d_defferredFineBuffer[0]!.height/threadsPerGroup.height,
                                                   1)
        
        var invMVP : simd_float4x4 = simd_mul(simd_mul(camera.P, camera.V), data!.M).inverse

        // raycasting
        cmptEncoder?.setComputePipelineState(self._PSO_raycast[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferredFineBuffer[defferredBufferType.DBT_POS.rawValue], index: 0)
        cmptEncoder?.setTexture(data!.getData(), index: 1)
        
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 0)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        cmptEncoder?.setBytes(&data!.level,
                              length: MemoryLayout<Float>.size,
                              index: 2)
        cmptEncoder?.setBytes(&invMVP,
                              length: MemoryLayout<simd_float4x4>.size,
                              index: 3)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // compute differences
        cmptEncoder?.setComputePipelineState(self._PSO_evalGradient[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferredFineBuffer[defferredBufferType.DBT_GRAD.rawValue], index: 0)
        cmptEncoder?.setTexture(self.d_defferredFineBuffer[defferredBufferType.DBT_H_II.rawValue], index: 1)
        cmptEncoder?.setTexture(self.d_defferredFineBuffer[defferredBufferType.DBT_H_IJ.rawValue], index: 2)
        cmptEncoder?.setTexture(self.d_defferredFineBuffer[defferredBufferType.DBT_POS.rawValue], index: 3)
        cmptEncoder?.setTexture(data!.getData(), index: 4)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 0)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        cmptEncoder?.endEncoding()
    }
    
    func getdefferredBuffer() -> [MTLTexture?]
    {
        return self.d_defferredFineBuffer
    }

    func getIntermediatedefferredBuffer() -> [MTLTexture?]
    {
        return self.d_defferredCoarseBuffer
    }

}
