//
//  Raycaster.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation
import MetalKit
import simd

enum DefferedBufferType : Int, CaseIterable {
    case DBT_POS = 0
    case DBT_GRAD
    case DBT_H_II
    case DBT_H_IJ
}

class Raycaster {
    let _device : MTLDevice?
    
    var _PSO_raycast : [MTLComputePipelineState?] = []
    var _PSO_evalGradient : [MTLComputePipelineState?] = []
    let _PSO_genRay : MTLComputePipelineState?
    let _PSO_genRayTiled : MTLComputePipelineState?
    let _PSO_initTiledBuffer : MTLComputePipelineState?
    let _PSO_updateTiledBuffer : MTLComputePipelineState?
    
    let _raySpaceBound : MTLSize?
    
    let d_rays : MTLBuffer?
    var d_defferedFineBuffer : [MTLTexture?] = []
    var d_defferedCoarseBuffer : [MTLTexture?] = []
    
    var currentkernel : Int = 0

    init(device:MTLDevice?, library:MTLLibrary?, raySpaceBound:MTLSize)
    {
        self._raySpaceBound  = raySpaceBound
        self._device = device
        
        // make compute PSOs
        for var kernelType in 0..<KT_NR_KERNELS.rawValue {
            let constantValue = MTLFunctionConstantValues()
            constantValue.setConstantValue(&kernelType,
                                          type: MTLDataType.int,
                                          index: Int(FC_KERNEL_TYPE.rawValue))
            
            let FUNC_raycast = try? library?.makeFunction(name: "raycast", constantValues: constantValue)
            let FUNC_evalGradient = try? library?.makeFunction(name: "evalDifferences", constantValues: constantValue)
            let PSO_raycast = try? device?.makeComputePipelineState(function: FUNC_raycast!)
            let PSO_evalGradient = try? device?.makeComputePipelineState(function: FUNC_evalGradient!)
            
            self._PSO_raycast.append(PSO_raycast)
            self._PSO_evalGradient.append(PSO_evalGradient)
        }
        
        let FUNC_initTiledBuffer = library?.makeFunction(name: "initTiledBuffer")
        self._PSO_initTiledBuffer = try? device?.makeComputePipelineState(function: FUNC_initTiledBuffer!)
        let FUNC_updateTiledBuffer = library?.makeFunction(name: "updateTiledBuffer")
        self._PSO_updateTiledBuffer = try? device?.makeComputePipelineState(function: FUNC_updateTiledBuffer!)
        
        let constantValue = MTLFunctionConstantValues()
        var isTiled = true
        constantValue.setConstantValue(&isTiled, type: MTLDataType.bool, index: Int(FC_IS_TILED.rawValue))
        let FUNC_genRayTiled = try? library?.makeFunction(name: "genRay", constantValues: constantValue)
        isTiled = false
        constantValue.setConstantValue(&isTiled, type: MTLDataType.bool, index: Int(FC_IS_TILED.rawValue))
        let FUNC_genRay = try? library?.makeFunction(name: "genRay", constantValues: constantValue)
        
        self._PSO_genRayTiled = try? device?.makeComputePipelineState(function: FUNC_genRayTiled!)
        self._PSO_genRay = try? device?.makeComputePipelineState(function: FUNC_genRay!)
        
        // make deffered textures
        let nrRays = Int(raySpaceBound.width*raySpaceBound.height)
        self.d_rays = self._device?.makeBuffer(length: nrRays*MemoryLayout<Ray>.size,
                                               options: .storageModePrivate)

        let tex_descr = MTLTextureDescriptor()
        tex_descr.textureType = .type2D
        tex_descr.pixelFormat = .rgba16Float
        tex_descr.width = raySpaceBound.width
        tex_descr.height = raySpaceBound.height
        tex_descr.storageMode = .private
        tex_descr.usage = [.shaderWrite, .shaderRead]
        for _ in DefferedBufferType.allCases {
            self.d_defferedFineBuffer.append(self._device?.makeTexture(descriptor: tex_descr))
        }

        tex_descr.width = 128
        tex_descr.height = 128
        for _ in DefferedBufferType.allCases {
            self.d_defferedCoarseBuffer.append(self._device?.makeTexture(descriptor: tex_descr))
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
    
    func raycasting(queue:MTLCommandQueue?, data:VolumeData?, camera:Camera)
    {
        let cmdBuffer = queue?.makeCommandBuffer()
        let cmptEncoder = cmdBuffer?.makeComputeCommandEncoder()
        let threadsPerGroup = MTLSizeMake(16,16,1)
        let threadBlocksPerGrid = MTLSizeMake((self._raySpaceBound!.width+threadsPerGroup.width-1)/threadsPerGroup.width,
                                              (self._raySpaceBound!.height+threadsPerGroup.height-1)/threadsPerGroup.height,
                                              1)
        var invMVP : simd_float4x4 = simd_mul(simd_mul(camera.P, camera.V), data!.M).inverse

        cmptEncoder?.setComputePipelineState(self._PSO_genRay!)
        cmptEncoder?.setBuffer(self.d_rays,
                               offset: 0,
                               index: 0)
        cmptEncoder?.setBytes(&invMVP,
                              length: MemoryLayout<simd_float4x4>.size,
                              index: 1)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 2)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGrid,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // raycasting
        cmptEncoder?.setComputePipelineState(self._PSO_raycast[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferedFineBuffer[DefferedBufferType.DBT_POS.rawValue], index: 0)
        cmptEncoder?.setTexture(data!.getData(), index: 1)
        cmptEncoder?.setBuffer(self.d_rays, offset: 0, index: 0)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 2)
        cmptEncoder?.setBytes(&data!.level,
                              length: MemoryLayout<Float>.size,
                              index: 3)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGrid,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // compute differences
        cmptEncoder?.setComputePipelineState(self._PSO_evalGradient[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferedFineBuffer[DefferedBufferType.DBT_GRAD.rawValue], index: 0)
        cmptEncoder?.setTexture(self.d_defferedFineBuffer[DefferedBufferType.DBT_H_II.rawValue], index: 1)
        cmptEncoder?.setTexture(self.d_defferedFineBuffer[DefferedBufferType.DBT_H_IJ.rawValue], index: 2)
        cmptEncoder?.setTexture(self.d_defferedFineBuffer[DefferedBufferType.DBT_POS.rawValue], index: 3)
        cmptEncoder?.setTexture(data!.getData(), index: 4)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 0)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGrid,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        cmptEncoder?.endEncoding()
        cmdBuffer?.commit()
    }
    
    func raycastingTiled(commanBuffer cmdBuffer:MTLCommandBuffer?,
                         data:VolumeData?,
                         camera:Camera,
                         tileOffset:simd_uint2,
                         tileScale:simd_uint2,
                         isUpdate:Bool)
    {
        //let cmdBuffer = queue?.makeCommandBuffer()
        let cmptEncoder = cmdBuffer?.makeComputeCommandEncoder()
        let threadsPerGroup = MTLSizeMake(8,8,1)
        let threadBlocksPerGridTiled = MTLSizeMake(128/threadsPerGroup.width,
                                                   128/threadsPerGroup.height,
                                                   1)
        
        var invMVP : simd_float4x4 = simd_mul(simd_mul(camera.P, camera.V), data!.M).inverse

        var scale = tileScale
        var offset = tileOffset
        
        cmptEncoder?.setComputePipelineState(self._PSO_genRayTiled!)
        cmptEncoder?.setBuffer(self.d_rays,
                               offset: 0,
                               index: 0)
        cmptEncoder?.setBytes(&invMVP,
                              length: MemoryLayout<simd_float4x4>.size,
                              index: 1)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 2)
        cmptEncoder?.setBytes(&offset,
                              length: MemoryLayout<vector_float4>.size,
                              index: 3)
        cmptEncoder?.setBytes(&scale,
                              length: MemoryLayout<vector_float4>.size,
                              index: 4)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // raycasting
        cmptEncoder?.setComputePipelineState(self._PSO_raycast[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferedCoarseBuffer[DefferedBufferType.DBT_POS.rawValue], index: 0)
        cmptEncoder?.setTexture(data!.getData(), index: 1)
        cmptEncoder?.setBuffer(self.d_rays, offset: 0, index: 0)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 2)
        cmptEncoder?.setBytes(&data!.level,
                              length: MemoryLayout<Float>.size,
                              index: 3)
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // compute differences
        cmptEncoder?.setComputePipelineState(self._PSO_evalGradient[currentkernel]!)
        cmptEncoder?.setTexture(self.d_defferedCoarseBuffer[DefferedBufferType.DBT_GRAD.rawValue], index: 0)
        cmptEncoder?.setTexture(self.d_defferedCoarseBuffer[DefferedBufferType.DBT_H_II.rawValue], index: 1)
        cmptEncoder?.setTexture(self.d_defferedCoarseBuffer[DefferedBufferType.DBT_H_IJ.rawValue], index: 2)
        cmptEncoder?.setTexture(self.d_defferedCoarseBuffer[DefferedBufferType.DBT_POS.rawValue], index: 3)
        cmptEncoder?.setTexture(data!.getData(), index: 4)
        cmptEncoder?.setBytes(&data!.dim,
                              length: MemoryLayout<vector_float4>.size,
                              index: 0)
        cmptEncoder?.setBytes(&data!.aspect_ratio,
                              length: MemoryLayout<vector_float4>.size,
                              index: 1)
        
        cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                          threadsPerThreadgroup: threadsPerGroup)
        
        // update backbuffer
        for t in DefferedBufferType.allCases {
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
            cmptEncoder?.setTexture(self.d_defferedFineBuffer[t.rawValue], index: 0)
            cmptEncoder?.setTexture(self.d_defferedCoarseBuffer[t.rawValue], index: 1)
            cmptEncoder?.dispatchThreadgroups(threadBlocksPerGridTiled,
                                              threadsPerThreadgroup: threadsPerGroup)
        }
        cmptEncoder?.endEncoding()
    }
    
    func getDefferedBuffer() -> [MTLTexture?]
    {
        return self.d_defferedFineBuffer
    }

    func getIntermediateDefferedBuffer() -> [MTLTexture?]
    {
        return self.d_defferedCoarseBuffer
    }

}
