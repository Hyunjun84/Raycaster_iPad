//
//  VolumeData.metal
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#include <metal_stdlib>
using namespace metal;

constexpr sampler sp_texel(coord::pixel,
                           filter::nearest,
                           address::clamp_to_edge);

[[kernel]] void genMLDataCC(texture3d<float, access::write> Vol [[texture(0)]],
                      constant float4& dim [[ buffer(0) ]],
                      uint3 tid [[ thread_position_in_grid ]],
                      uint3 tsz [[ threads_per_grid ]])
{
    if(any(tid>=uint3(dim.xyz))) return;
    float4 p = float4(float3(tid)/(dim.xyz-1)*2-1, 1);
    
    const float alpha = 0.25f;
    const float fm = 6;
    float r = 1.f - sinpi(p.z*0.5f) + alpha*(1.f + cospi(2.f*fm*cospi(sqrt(p.x*p.x+p.y*p.y)*0.5f)));
    float val = r/(2.f*(1.f+alpha));
    
    Vol.write(val, tid);
}

[[kernel]] void genMLDataFCC(texture3d<float, access::write> Vol [[texture(0)]],
                      constant float4& dim [[ buffer(0) ]],
                      uint3 tid [[ thread_position_in_grid ]],
                      uint3 tsz [[ threads_per_grid ]])
{
    if(any(tid>=uint3(dim.xyz/2))) return;
    float3 fcc = float3(tid)*2;
 
    // (0,0,0), (0,1,1), (1,0,1), (1,1,0)
    float4 px = float4(fcc.x, fcc.x, fcc.x+1, fcc.x+1)/(dim.x-1)*2.0f - 1.0f;;
    float4 py = float4(fcc.y, fcc.y+1, fcc.y, fcc.y+1)/(dim.y-1)*2.0f - 1.0f;;
    float4 pz = float4(fcc.z, fcc.z+1, fcc.z+1, fcc.z)/(dim.z-1)*2.0f - 1.0f;;
    
    const float alpha = 0.25f;
    const float fm = 6;
    float4 r = 1.f - sinpi(pz*0.5f) + alpha*(1.f + cospi(2.f*fm*cospi(sqrt(px*px+py*py)*0.5f)));
    float4 val = r/(2.f*(1.f+alpha));
    
    
    Vol.write(val, tid);
}

[[kernel]] void applyQuasiInterpolatorCC(texture3d<float, access::write> Out [[texture(0)]],
                                       texture3d<float, access::sample> In [[texture(1)]],
                                       constant float4& dim [[ buffer(0) ]],
                                       constant float4& coef [[ buffer(1) ]],
                                       uint3 tid [[ thread_position_in_grid ]],
                                       uint3 tsz [[ threads_per_grid ]])
{
    if(any(tid>=uint3(dim.xyz))) return;
    
    float3 fid = float3(tid);
   
    // (0,0,0)
    float ret = In.sample(sp_texel, fid).x*coef.x;
    
    //+-{ (1, 0, 0) (0, 1, 0) (0, 0, 1) }
    ret += In.sample(sp_texel, fid+float3( 1, 0, 0)).x*coef.y;
    ret += In.sample(sp_texel, fid+float3(-1, 0, 0)).x*coef.y;
    ret += In.sample(sp_texel, fid+float3( 0, 1, 0)).x*coef.y;
    ret += In.sample(sp_texel, fid+float3( 0,-1, 0)).x*coef.y;
    ret += In.sample(sp_texel, fid+float3( 0, 0, 1)).x*coef.y;
    ret += In.sample(sp_texel, fid+float3( 0, 0,-1)).x*coef.y;
    
    //+-{ (1, 1, 0) (1, 0, 1) (0, 1, 1) }
    ret += In.sample(sp_texel, fid+float3( 0, 1, 1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 0,-1, 1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 0,-1,-1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 0, 1,-1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 1, 0, 1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 1, 0,-1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3(-1, 0,-1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3(-1, 0, 1)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 1, 1, 0)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3( 1,-1, 0)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3(-1,-1, 0)).x*coef.z;
    ret += In.sample(sp_texel, fid+float3(-1, 1, 0)).x*coef.z;

    //+-{ (1, 1, 1) }
    ret += In.sample(sp_texel, fid+float3( 1, 1, 1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3( 1,-1, 1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3( 1,-1,-1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3( 1, 1,-1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3(-1, 1, 1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3(-1,-1, 1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3(-1,-1,-1)).x*coef.w;
    ret += In.sample(sp_texel, fid+float3(-1, 1,-1)).x*coef.w;


    Out.write(ret,tid);
}

[[kernel]] void applyQuasiInterpolatorFCC(texture3d<float, access::write> Out [[texture(0)]],
                                       texture3d<float, access::sample> In [[texture(1)]],
                                       constant float4& dim [[ buffer(0) ]],
                                       constant float4& coef [[ buffer(1) ]],
                                       uint3 tid [[ thread_position_in_grid ]],
                                       uint3 tsz [[ threads_per_grid ]])
{
    if(any(tid>=uint3(dim.xyz))) return;
    
    float3 fid = float3(tid);
    // (0, 0, 0) += (0, 0, 0)*c0 : ret.x + (0, 0, 0).x*coef.x
    // (0, 1, 1) += (0, 1, 1)*c0 : ret.y + (0, 0, 0).y*coef.x
    // (1, 0, 1) += (1, 0, 1)*c0 : ret.z + (0, 0, 0).z*coef.x
    // (1, 1, 0) += (1, 1, 0)*c0 : ret.w + (0, 0, 0).w*coef.x

    // (0, 0, 0) += (0, 1, 1)*c1 : ret.x + (0, 0, 0).y*coef.y
    // (0, 1, 1) += (1, 0, 1)*c1 : ret.y + (0, 0, 0).z*coef.y
    // (1, 0, 1) += (1, 1, 0)*c1 : ret.z + (0, 0, 0).w*coef.y
    // (1, 1, 0) += (0, 0, 0)*c1 : ret.w + (0, 0, 0).x*coef.y

    // (0, 0, 0) += (1, 0, 1)*c1 : ret.x + (0, 0, 0).z*coef.y
    // (0, 1, 1) += (1, 1, 0)*c1 : ret.y + (0, 0, 0).w*coef.y
    // (1, 0, 1) += (0, 0, 0)*c1 : ret.z + (0, 0, 0).x*coef.y
    // (1, 1, 0) += (0, 1, 1)*c1 : ret.w + (0, 0, 0).y*coef.y

    // (0, 0, 0) += (1, 1, 0)*c1 : ret.x + (0, 0, 0).w*coef.y
    // (0, 1, 1) += (0, 0, 0)*c1 : ret.y + (0, 0, 0).x*coef.y
    // (1, 0, 1) += (0, 1, 1)*c1 : ret.z + (0, 0, 0).y*coef.y
    // (1, 1, 0) += (1, 0, 1)*c1 : ret.w + (0, 0, 0).z*coef.y
    float4 tmp = In.sample(sp_texel, fid);
    float4 ret = tmp*coef.x;
    ret += (tmp.yzwx + tmp.zwxy + tmp.wxyz)*coef.y;


    // (0, 0, 0) += (-1, 0, 1)*c1 : ret.x + (-1, 0, 0).z*coef.y
    // (0, 0, 0) += (-1, 1, 0)*c1 : ret.x + (-1, 0, 0).w*coef.y
    // (0, 1, 1) += (-1, 0, 1)*c1 : ret.y + (-1, 0, 0).z*coef.y
    // (0, 1, 1) += (-1, 1, 0)*c1 : ret.y + (-1, 0, 0).w*coef.y

    // (0, 0, 0) += (-2, 0, 0)*c2 : ret.x + (-1, 0, 0).x*coef.z
    // (0, 1, 1) += (-2, 1, 1)*c2 : ret.y + (-1, 0, 0).y*coef.z
    // (1, 0, 1) += (-1, 0, 1)*c2 : ret.z + (-1, 0, 0).z*coef.z
    // (1, 1, 0) += (-1, 1, 0)*c2 : ret.w + (-1, 0, 0).w*coef.z
    tmp = In.sample(sp_texel, fid+float3(-1,0,0));
    ret.xy += (tmp.z+tmp.w)*coef.y;
    ret += tmp*coef.z;


    // (1, 0, 1) += (2, 0, 0)*c1 : ret.z + (1, 0, 0).x*coef.y
    // (1, 0, 1) += (2, 1, 1)*c1 : ret.z + (1, 0, 0).y*coef.y
    // (1, 1, 0) += (2, 0, 0)*c1 : ret.w + (1, 0, 0).x*coef.y
    // (1, 1, 0) += (2, 1, 1)*c1 : ret.w + (1, 0, 0).y*coef.y
    
    // (0, 0, 0) += (2, 0, 0)*c2 : ret.x + (1, 0, 0).x*coef.z
    // (0, 1, 1) += (2, 1, 1)*c2 : ret.y + (1, 0, 0).y*coef.z
    // (1, 0, 1) += (3, 0, 1)*c2 : ret.z + (1, 0, 0).z*coef.z
    // (1, 1, 0) += (3, 1, 0)*c2 : ret.w + (1, 0, 0).w*coef.z
    tmp = In.sample(sp_texel, fid+float3(1,0,0));
    ret.zw += (tmp.x+tmp.y)*coef.y;
    ret += tmp*coef.z;


    // (0, 1, 1) += (0, 2, 0)*c1 : ret.y + (0, 1, 0).x*coef.y
    // (0, 1, 1) += (1, 2, 1)*c1 : ret.y + (0, 1, 0).z*coef.y
    // (1, 1, 0) += (0, 2, 0)*c1 : ret.w + (0, 1, 0).x*coef.y
    // (1, 1, 0) += (1, 2, 1)*c1 : ret.w + (0, 1, 0).z*coef.y
    
    // (0, 0, 0) += (0, 2, 0)*c2 : ret.x + (0, 1, 0).x*coef.z
    // (0, 1, 1) += (0, 3, 1)*c2 : ret.y + (0, 1, 0).y*coef.z
    // (1, 0, 1) += (1, 2, 1)*c2 : ret.z + (0, 1, 0).z*coef.z
    // (1, 1, 0) += (1, 3, 0)*c2 : ret.w + (0, 1, 0).w*coef.z
    tmp = In.sample(sp_texel, fid+float3(0,1,0));
    ret.yw += (tmp.x + tmp.z)*coef.y;
    ret += tmp*coef.z;


    // (0, 0, 0) += (0, -1, 1)*c1 : ret.x + (0, -1, 0).y*coef.y
    // (0, 0, 0) += (1, -1, 0)*c1 : ret.x + (0, -1, 0).w*coef.y
    // (1, 0, 1) += (0, -1, 1)*c1 : ret.z + (0, -1, 0).y*coef.y
    // (1, 0, 1) += (1, -1, 0)*c1 : ret.z + (0, -1, 0).w*coef.y
    
    // (0, 0, 0) += (0, -2, 0)*c2 : ret.x + (0, -1, 0).x*coef.z
    // (0, 1, 1) += (0, -1, 1)*c2 : ret.y + (0, -1, 0).y*coef.z
    // (1, 0, 1) += (1, -2, 1)*c2 : ret.z + (0, -1, 0).z*coef.z
    // (1, 1, 0) += (1, -1, 0)*c2 : ret.w + (0, -1, 0).w*coef.z
    tmp = In.sample(sp_texel, fid+float3(0,-1,0));
    ret.xz += (tmp.y + tmp.w)*coef.y;
    ret += tmp*coef.z;


    // (0, 0, 0) += (0, 1, -1)*c1 : ret.x + (0, 0, -1).y*coef.y
    // (0, 0, 0) += (1, 0, -1)*c1 : ret.x + (0, 0, -1).z*coef.y
    // (1, 1, 0) += (0, 1, -1)*c1 : ret.w + (0, 0, -1).y*coef.y
    // (1, 1, 0) += (1, 0, -1)*c1 : ret.w + (0, 0, -1).z*coef.y
    
    // (0, 0, 0) += (0, 0, -2)*c2 : ret.x + (0, 0, -1).x*coef.z
    // (0, 1, 1) += (0, 1, -1)*c2 : ret.y + (0, 0, -1).y*coef.z
    // (1, 0, 1) += (1, 0, -1)*c2 : ret.z + (0, 0, -1).z*coef.z
    // (1, 1, 0) += (1, 1, -2)*c2 : ret.w + (0, 0, -1).w*coef.z
    tmp = In.sample(sp_texel, fid+float3(0,0,-1));
    ret.xw += (tmp.y + tmp.z)*coef.y;
    ret += tmp*coef.z;

    // (0, 1, 1) += (0, 0, 2)*c1 : ret.y + (0, 0, 1).x*coef.y
    // (0, 1, 1) += (1, 1, 2)*c1 : ret.y + (0, 0, 1).w*coef.y
    // (1, 0, 1) += (0, 0, 2)*c1 : ret.z + (0, 0, 1).x*coef.y
    // (1, 0, 1) += (1, 1, 2)*c1 : ret.z + (0, 0, 1).w*coef.y

    // (0, 0, 0) += (0, 0, 2)*c2 : ret.x + (0, 0, 1).x*coef.z
    // (0, 1, 1) += (0, 1, 3)*c2 : ret.y + (0, 0, 1).y*coef.z
    // (1, 0, 1) += (1, 0, 3)*c2 : ret.z + (0, 0, 1).z*coef.z
    // (1, 1, 0) += (1, 1, 2)*c2 : ret.w + (0, 0, 1).w*coef.z
    tmp = In.sample(sp_texel, fid+float3(0,0,1));
    ret.yz += (tmp.x + tmp.w)*coef.y;
    ret += tmp*coef.z;

    // (1, 1, 0) += (2, 2, 0)*c1 : ret.w + (1, 1, 0).x*coef.y
    ret.w += In.sample(sp_texel, fid+float3(1,1,0)).x*coef.y;

    // (0, 1, 1) += (-1, 2, 1)*c1 : ret.y + (-1, 1, 0).z*coef.y
    ret.y += In.sample(sp_texel, fid+float3(-1,1,0)).z*coef.y;

    // (0, 0, 0) += (-1, -1, 0)*c1 : ret.x + (-1, -1, 0).w*coef.y
    ret.x += In.sample(sp_texel, fid+float3(-1,-1,0)).w*coef.y;

    // (1, 0, 1) += (2, -1, 1)*c1 : ret.z + (1, -1, 0).y*coef.y
    ret.z += In.sample(sp_texel, fid+float3(1,-1,0)).y*coef.y;

    // (1, 0, 1) += (2, 0, 2)*c1 : ret.z + (1, 0, 1).x*coef.y
    ret.z += In.sample(sp_texel, fid+float3(1,0,1)).x*coef.y;

    // (1, 1, 0) += (2, 1, -1)*c1 : ret.w + (1, 0, -1).y*coef.y
    ret.w += In.sample(sp_texel, fid+float3(1,0,-1)).y*coef.y;

    // (0, 0, 0) += (-1, 0, -1)*c1 : ret.x + (-1, 0, -1).z*coef.y
    ret.x += In.sample(sp_texel, fid+float3(-1,0,-1)).z*coef.y;

    // (0, 1, 1) += (-1, 1, 2)*c1 : ret.y + (-1, 0, 1).w*coef.y
    ret.y += In.sample(sp_texel, fid+float3(-1,0,1)).w*coef.y;

    // (0, 1, 1) += (0, 2, 2)*c1 : ret.y + (0, 1, 1).x*coef.y
    ret.y += In.sample(sp_texel, fid+float3(0,1,1)).x*coef.y;

    // (1, 0, 1) += (1, -1, 2)*c1 : ret.z + (0, -1, 1).w*coef.y
    ret.z += In.sample(sp_texel, fid+float3(0,-1,1)).w*coef.y;

    // (0, 0, 0) += (0, -1, -1)*c1 : ret.x + (0, -1, -1).y*coef.y
    ret.x += In.sample(sp_texel, fid+float3(0,-1,-1)).y*coef.y;

    // (1, 1, 0) += (1, 2, -1)*c1 : ret.w + (0, 1, -1).z*coef.y
    ret.w += In.sample(sp_texel, fid+float3(0,1,-1)).z*coef.y;

    Out.write(ret, tid);
}
