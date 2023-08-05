//
//  VolumeData.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation
import MetalKit

class VolumeData{
    let device : MTLDevice?
    let psoGenMLCC : MTLComputePipelineState?
    let psoQuasiCC : MTLComputePipelineState?
    let psoGenMLFCC : MTLComputePipelineState?
    let psoQuasiFCC : MTLComputePipelineState?

    var dVolume : MTLTexture?
    var dVolumeQI : MTLTexture?
    
    var aspect_ratio : simd_float4?
    var scale : simd_float4?
    var dim : simd_float4?
    var res : simd_float4?
    var level : Float?
    
    var M : simd_float4x4
    var QI : Bool
    
    
    init(with device : MTLDevice?, library : MTLLibrary?)
    {
        guard let device, let library else { fatalError("Error") }
        self.device = device

        let FUNC_genMLCC = library.makeFunction(name: "genMLDataCC")
        let FUNC_genMLFCC = library.makeFunction(name: "genMLDataFCC")

        let FUNC_quasiCC = library.makeFunction(name: "applyQuasiInterpolatorCC")
        let FUNC_quasiFCC = library.makeFunction(name: "applyQuasiInterpolatorFCC")

        self.psoGenMLCC = try? device.makeComputePipelineState(function: FUNC_genMLCC!)
        self.psoQuasiCC = try? device.makeComputePipelineState(function: FUNC_quasiCC!)
        
        self.psoGenMLFCC = try? device.makeComputePipelineState(function: FUNC_genMLFCC!)
        self.psoQuasiFCC = try? device.makeComputePipelineState(function: FUNC_quasiFCC!)
        
        self.M = simd_float4x4(diagonal: simd_float4(simd_float3(repeating:0.5), 1))
        
        self.QI = false
    }
    
    func getData() -> MTLTexture? {
        if QI {
            return self.dVolumeQI
        } else {
            return self.dVolume
        }
    }
    
    func genMLData(resolution : MTLSize?, cmdBuffer : MTLCommandBuffer?, lattice:LatticeType)
    {
        guard let cmdBuffer, let resolution else { return }
        switch lattice {
            case .LT_CC :
                self.res = simd_make_float4(Float(resolution.width),
                                            Float(resolution.height),
                                            Float(resolution.depth),
                                            1.0)
                self.dim = simd_make_float4(Float(resolution.width),
                                            Float(resolution.height),
                                            Float(resolution.depth),
                                            1.0)
            case .LT_FCC :
                self.res = simd_make_float4(Float(resolution.width),
                                            Float(resolution.height),
                                            Float(resolution.depth),
                                            4.0)
                self.dim = simd_make_float4(Float(resolution.width*2),
                                            Float(resolution.height*2),
                                            Float(resolution.depth*2),
                                            1.0)
        }
        self.aspect_ratio = simd_make_float4(1, 1, 1, 1)

        let tex_descr = MTLTextureDescriptor()
        tex_descr.textureType = MTLTextureType.type3D
        switch lattice {
            case .LT_FCC : tex_descr.pixelFormat = MTLPixelFormat.rgba32Float
            case .LT_CC :tex_descr.pixelFormat = MTLPixelFormat.r32Float
        }
        tex_descr.width = resolution.width
        tex_descr.height = resolution.height
        tex_descr.depth = resolution.depth
        tex_descr.storageMode = .private
        tex_descr.usage = [MTLTextureUsage.shaderWrite, MTLTextureUsage.shaderRead]
        
        self.dVolume = self.device?.makeTexture(descriptor: tex_descr)
        self.dVolumeQI = self.device?.makeTexture(descriptor: tex_descr)
        
        
        let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()
        switch lattice {
            case .LT_CC: cmdEncoder?.setComputePipelineState(self.psoGenMLCC!)
            case .LT_FCC: cmdEncoder?.setComputePipelineState(self.psoGenMLFCC!)
        }
        cmdEncoder?.setTexture(self.dVolume, index: 0)
        cmdEncoder?.setBytes(&self.dim!, length: MemoryLayout<simd_float4>.size, index: 0)
        
        let threadsPerGroup = MTLSizeMake(8, 8, 8)
        let threadBlocksPerGrid = MTLSizeMake((resolution.width+threadsPerGroup.width-1)/threadsPerGroup.width,
                                              (resolution.height+threadsPerGroup.height-1)/threadsPerGroup.height,
                                              (resolution.depth+threadsPerGroup.depth-1)/threadsPerGroup.depth)
        cmdEncoder?.dispatchThreadgroups(threadBlocksPerGrid,
                                         threadsPerThreadgroup: threadsPerGroup)
        cmdEncoder?.endEncoding()
    }
    
    
    func applyQuasiInterpolator(cmdBuffer : MTLCommandBuffer?, lattice:LatticeType, QICoef:simd_float4?)
    {
        guard let cmdBuffer else { return }
        guard let dVolume = self.dVolume else { return}
        
        let tex_descr = MTLTextureDescriptor()
        tex_descr.textureType = MTLTextureType.type3D
        switch lattice {
            case .LT_FCC : tex_descr.pixelFormat = MTLPixelFormat.rgba32Float
            case .LT_CC :tex_descr.pixelFormat = MTLPixelFormat.r32Float
        }
        tex_descr.width = dVolume.width
        tex_descr.height = dVolume.height
        tex_descr.depth = dVolume.depth
        tex_descr.storageMode = .private
        tex_descr.usage = [MTLTextureUsage.shaderWrite, MTLTextureUsage.shaderRead]
        
        self.dVolumeQI = self.device?.makeTexture(descriptor: tex_descr)

        let threadsPerGroup = MTLSizeMake(8, 8, 8)
        let threadBlocksPerGrid = MTLSizeMake((dVolume.width+threadsPerGroup.width-1)/threadsPerGroup.width,
                                              (dVolume.height+threadsPerGroup.height-1)/threadsPerGroup.height,
                                              (dVolume.depth+threadsPerGroup.depth-1)/threadsPerGroup.depth)
  
        let cmdEncoder = cmdBuffer.makeComputeCommandEncoder()
        switch lattice {
            case .LT_CC : cmdEncoder?.setComputePipelineState(self.psoQuasiCC!)
            case .LT_FCC : cmdEncoder?.setComputePipelineState(self.psoQuasiFCC!)
        }
        var coef = QICoef
        cmdEncoder?.setTexture(self.dVolumeQI, index: 0)
        cmdEncoder?.setTexture(self.dVolume, index: 1)
        cmdEncoder?.setBytes(&self.dim!, length: MemoryLayout<simd_float4>.size, index: 0)
        cmdEncoder?.setBytes(&coef, length: MemoryLayout<simd_float4>.size, index: 1)
        
        cmdEncoder?.dispatchThreadgroups(threadBlocksPerGrid,
                                         threadsPerThreadgroup: threadsPerGroup)
        cmdEncoder?.endEncoding()
    }
    
    func genMLDataWithQI(resolution : MTLSize?, cmdBuffer : MTLCommandBuffer?, lattice:LatticeType, QICoef:simd_float4?)
    {
        guard let cmdBuffer else { return }
        self.genMLData(resolution: resolution,
                       cmdBuffer: cmdBuffer,
                       lattice: lattice)
        self.applyQuasiInterpolator(cmdBuffer: cmdBuffer,
                                    lattice: lattice,
                                    QICoef: QICoef)
    }
    
    func applyMap(map m : simd_float4x4)
    {
        self.M = simd_mul(m, self.M)
    }
    
}
