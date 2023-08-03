//
//  Raycaster.metal
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#include <metal_stdlib>
#include "ShaderTypes.h"
#include "FCCV.h"
#include "CC6.h"

using namespace metal;

constant int kernelType [[ function_constant(FC_KERNEL_TYPE) ]];
constant bool isTiled [[ function_constant(FC_IS_TILED) ]];

float eval(texture3d<float, access::sample> Vol, float3 p)
{
    float val = 0;
    switch (kernelType) {
        case KT_CC6 : val = eval_cc6(Vol, p); break;
        case KT_FCCV2 : val = eval_fccv2(Vol, p); break;
        case KT_FCCV3 : val = eval_fccv3(Vol, p); break;
    }
    return val;
}

float3 eval_g(texture3d<float, access::sample> Vol, float3 p)
{
    float3 val = 0;
    switch (kernelType) {
        case KT_CC6 : val = eval_grad_cc6(Vol, p); break;
        case KT_FCCV2 : val = eval_grad_fccv2(Vol, p); break;
        case KT_FCCV3 : val = eval_grad_fccv3(Vol, p); break;
    }
    return val;

}

Hessian eval_H(texture3d<float, access::sample> Vol, float3 p)
{
    Hessian val = {float4(0), float4(0)};
    switch (kernelType) {
        case KT_CC6 : val = eval_Hessian_cc6(Vol, p); break;
        case KT_FCCV2 : val = eval_Hessian_fccv2(Vol, p); break;
        case KT_FCCV3 : val = eval_Hessian_fccv3(Vol, p); break;
    }
    return val;

}

float3 ray2tex(float3 p, float3 scale, float3 dim)
{
    return (p/scale*0.5+0.5)*dim-0.5;
}

float3 tex2ray(float3 p, float3 scale, float3 dim)
{
    return ((p+0.5)/dim.xyz-0.5)*2.0*scale;
}

kernel void raycast(texture2d<float, access::write> Pos [[ texture(0) ]],
                    texture3d<float, access::sample> Vol [[ texture(1) ]],
                    constant float4& aspectRatio [[ buffer(0) ]],
                    constant float4& dim [[ buffer(1) ]],
                    constant float& level [[ buffer(2) ]],
                    constant float4x4& invMVP [[ buffer(3) ]],
                    constant uint2& tileOffset [[ buffer(4), function_constant(isTiled) ]],
                    constant uint2& tileScale [[ buffer(5), function_constant(isTiled) ]],
                    uint2 tid [[ thread_position_in_grid ]],
                    uint2 tsz [[ threads_per_grid ]])
{
    // generate rays
    float4 b;
    if (isTiled) {
        b = float4(float2(tid*tileScale+tileOffset)/float2(tsz*tileScale-1)*2-1.0f, -1.0, 1.0f);
    } else {
        b = float4(float2(tid*2)/float2(tsz-1)-1.0f, -1.0, 1.0f);
    }
    float4 e = float4(b.xy, 1.0, 1.0f);
    
    b = invMVP*b;
    e = invMVP*e;
    b /= b.w;
    e /= e.w;
    
    float4 d = float4(normalize(e.xyz-b.xyz), 0);
    
    float2 hit_yz = float2(-aspectRatio.x-b.x, aspectRatio.x-b.x)/d.x;
    float2 hit_zx = float2(-aspectRatio.y-b.y, aspectRatio.y-b.y)/d.y;
    float2 hit_xy = float2(-aspectRatio.z-b.z, aspectRatio.z-b.z)/d.z;
    
    if(d.x == 0) hit_yz = NAN;
    if(d.y == 0) hit_zx = NAN;
    if(d.z == 0) hit_xy = NAN;
    
    hit_yz = float2(fmin(hit_yz.x, hit_yz.y), fmax(hit_yz.x, hit_yz.y));
    hit_zx = float2(fmin(hit_zx.x, hit_zx.y), fmax(hit_zx.x, hit_zx.y));
    hit_xy = float2(fmin(hit_xy.x, hit_xy.y), fmax(hit_xy.x, hit_xy.y));

    e.xyz = b.xyz+d.xyz*fmin3(hit_yz.y, hit_zx.y, hit_xy.y);
    b.xyz = b.xyz+d.xyz*fmax3(hit_yz.x, hit_zx.x, hit_xy.x);
    
    if(any(fabs(b)>1.0+1e-3) || any(fabs(e)>1.0+1e-3)) {
        b = float4(0);
        e = float4(0);
    }
    
    e.xyz = ray2tex(e.xyz, aspectRatio.xyz, dim.xyz);
    b.xyz = ray2tex(b.xyz, aspectRatio.xyz, dim.xyz);

    // raycasting
    const float ray_step = 0.1;
    const float max_ray_len = distance(b.xyz, e.xyz);
    const int max_iter = min(10000, int(max_ray_len/ray_step)+1);

    float voxel = eval(Vol, b.xyz);
    float voxel_prev = voxel;
    
    const float orientation = voxel<level ? 1.0f : -1.0f;
    d.xyz = normalize(e.xyz-b.xyz)*ray_step;
    
    float4 val = float4(0);
    float3 p = b.xyz;
    float3 p_prev = p;
    for(int i=0; i<max_iter; i++) {
        p += d.xyz;
        voxel = eval(Vol,p);
        if(orientation*voxel > orientation*level) {
            if(fabs(voxel-voxel_prev) > 1E-8) {
                p = (p*(voxel_prev-level)-p_prev*(voxel-level)) / (voxel_prev-voxel);
            }
            val = float4(tex2ray(p.xyz, aspectRatio.xyz, dim.xyz), orientation);
            break;
        }
        voxel_prev = voxel;
        p_prev = p;
    }
    Pos.write(val, tid);
}

kernel void evalDifferences(texture2d<float, access::write> Gradient [[ texture(0) ]],
                            texture2d<float, access::write> HessianII [[ texture(1) ]],
                            texture2d<float, access::write> HessianIJ [[ texture(2) ]],
                            texture2d<float, access::read> Position [[ texture(3) ]],
                            texture3d<float, access::sample> Vol [[ texture(4) ]],
                            constant float4& dim [[ buffer(0) ]],
                            constant float4& scale [[ buffer(1) ]],
                            uint2 tid [[ thread_position_in_grid ]],
                            uint2 tsz [[ threads_per_grid ]])
{
    float4 p = Position.read(tid);
    
    p.xyz = ray2tex(p.xyz, scale.xyz, dim.xyz);

    float3 g = (float3)(0);
    Hessian H = {float4(0), float4(0)};

    if(p.w!=0)  {
        float3 s = max3(dim.x, dim.y, dim.z)*scale.xyz;
        g = eval_g(Vol, p.xyz);
        H = eval_H(Vol, p.xyz);
        g *= s;
        H.dii.xyz *= s*s;
        H.dij.xyz *= s.yzx*s.zxy;
    }
    
    Gradient.write(float4(g,1), tid);
    HessianII.write(H.dii, tid);
    HessianIJ.write(H.dij, tid);
}

kernel void initTiledBuffer(array<texture2d<float, access::write>, 4> Out [[ texture(0) ]],
                             array<texture2d<float, access::sample>, 4> In [[ texture(4) ]],
                             constant uint2& tileScale [[ buffer(0) ]],
                             uint2 tid [[ thread_position_in_grid ]],
                             uint2 tsz [[ threads_per_grid ]])
{
    constexpr sampler sp_lin(coord::normalized,
                             filter::linear,
                             address::clamp_to_edge);

    for(int t=0; t<4; t++) {
        for(int i=0; i<8; i++) {
            for(int j=0; j<8; j++) {
                float2 fid = (float2(tid*tileScale+uint2(i,j))+0.5f*float2(tileScale))/float2(tsz*tileScale);
                float4 val = In[t].sample(sp_lin, fid);
                Out[t].write(val, tid*tileScale+uint2(i,j));
            }
        }
    }
}


kernel void updateTiledBuffer(array<texture2d<float, access::write>, 4> Out [[ texture(0) ]],
                               array<texture2d<float, access::sample>, 4> In [[ texture(4) ]],
                               constant uint2& tileScale [[ buffer(0) ]],
                               constant uint2& tileOffset [[ buffer(1) ]],
                               uint2 tid [[ thread_position_in_grid ]])
{
    for(int t=0; t<4; t++) {
        float4 val = In[t].read(tid);
        Out[t].write(val, tid*tileScale+tileOffset);
    }
}
