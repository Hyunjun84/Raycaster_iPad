//
//  MatrixHelper.swift
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

import Foundation
import simd

func rotate(axis ax:simd_float3, angle ang:Float) -> simd_float4x4 {
    let w = simd_normalize(ax)
    let ca = cos(ang)
    let sa = sin(ang)
    let oca = 1-ca
    let ws = w*sa
    
    let R = simd_float4x4(
        simd_float4(oca*w.x*w.x+ca, oca*w.x*w.y+ws.z, oca*w.x*w.z-ws.y, 0),
        simd_float4(oca*w.x*w.y-ws.z, oca*w.y*w.y+ca, oca*w.y*w.z+ws.x, 0),
        simd_float4(oca*w.x*w.z+ws.y, oca*w.y*w.z-ws.x, oca*w.z*w.z+ca, 0),
        simd_float4(0, 0, 0, 1))
    
    return R
}

func translate(direction dir : simd_float3) -> simd_float4x4 {
    return simd_float4x4(simd_float4(1, 0, 0, 0),
                         simd_float4(0, 1, 0, 0),
                         simd_float4(0, 0, 1, 0),
                         simd_float4(dir.x,dir.y,dir.z, 1) )
}

func scale(_ factor : simd_float3) -> simd_float4x4 {
    return simd_float4x4(diagonal: simd_float4(factor, 1))
}

func lookat(eye e : simd_float3, center c : simd_float3, up n : simd_float3) -> simd_float4x4
{
    var f = e-c
    f = simd_normalize(f)
    var l = simd_cross(n, f)
    l = simd_normalize(l)

    let u = simd_cross(f, l)
    
    return simd_float4x4(simd_float4(l[0], u[0], f[0], 0),
                         simd_float4(l[1], u[1], f[1], 0),
                         simd_float4(l[2], u[2], f[2], 0),
                         simd_float4(-simd_dot(l, e), -simd_dot(u, e), -simd_dot(f, e), 1));
}

func ortho(left l : Float, right r : Float, bottom b : Float, top t : Float, near n : Float, far f : Float) -> simd_float4x4
{
    return simd_float4x4(simd_float4(2/(r-l), 0, 0, 0),
                         simd_float4(0, 2/(t-b), 0, 0),
                         simd_float4(0, 0, 2/(n-f), 0),
                         simd_float4((l+r)/(l-r),(b+t)/(b-t),(n+f)/(n-f),1));

}

func perspective(_ fov : Float, aspectRatio aspect : Float, near n : Float, far f : Float) -> simd_float4x4
{
    let p00 = 1.0/tan(fov/2.0)
    let p11 = p00/aspect
    let p22 = (n+f)/(n-f)
    let p23 = (2*n*f)/(n-f)
    
    return simd_float4x4(simd_float4(p00, 0, 0, 0),
                         simd_float4(0, p11, 0, 0),
                         simd_float4(0, 0, p22, -1.0),
                         simd_float4(0, 0, p23, 0))
}
