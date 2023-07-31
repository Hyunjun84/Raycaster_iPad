//
//  Camera.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation
import simd


struct Camera
{
    var V : simd_float4x4  = simd_float4x4(diagonal: simd_float4(repeating: 1))
    var P : simd_float4x4  = simd_float4x4(diagonal: simd_float4(repeating: 1))
    var VP : simd_float4x4 = simd_float4x4(diagonal: simd_float4(repeating: 1))
    var fov : Float = 0.0
    var aspectRatio : Float = 1.0
    
    mutating func setFov(FOV fov:Float?, aspectRatio ratio:Float?)
    {
        if fov != nil  {
            self.fov = fov!
        }
        if ratio != nil {
            self.aspectRatio = ratio!
        }
        
        if(self.fov == 0.0) {
            self.V = lookat(eye:simd_float3(0, 0, 10),
                            center:simd_float3(repeating: 0),
                            up:simd_float3(0, 1, 0))
            self.P = ortho(left:-1,
                           right:1,
                           bottom:-self.aspectRatio,
                           top:self.aspectRatio,
                           near:-1,
                           far:1)
        } else {
            let fovR = self.fov/180*Float.pi
            let hfov = fovR*0.5
            let cotan_hfov = 1/tan(hfov)
            
            V = lookat(eye: simd_float3(0, 0, cotan_hfov),
                       center: simd_float3(0, 0, 0),
                       up: simd_float3(0, 1, 0))
            P = perspective(fovR,
                            aspectRatio: self.aspectRatio,
                            near: cotan_hfov,
                            far: 2+cotan_hfov)
        }
        
        VP = simd_mul(V, P)
    }
}



