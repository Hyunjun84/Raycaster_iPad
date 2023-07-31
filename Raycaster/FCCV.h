//
//  FCCV.h
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#ifndef FCCV_h
#define FCCV_h

#include <metal_stdlib>
using namespace metal;

float3 find_origin(float3 p);

void fetch_fccv2_coefficients(thread float* c, texture3d<float, access::sample> Vol, float3 org, float3 R, float3x3 P);
float eval_fccv2(texture3d<float, access::sample> Vol, float3 p_in);
float3 eval_grad_fccv2(texture3d<float, access::sample> Vol, float3 p_in);
Hessian eval_Hessian_fccv2(texture3d<float, access::sample> Vol, float3 p_in);

void fetch_fccv3_coefficients(thread float* c, texture3d<float, access::sample> Vol, float3 org, float3 R, float3x3 P);
float eval_fccv3(texture3d<float, access::sample> Vol, float3 p_in);
float3 eval_grad_fccv3(texture3d<float, access::sample> Vol, float3 p_in);
Hessian eval_Hessian_fccv3(texture3d<float, access::sample> Vol, float3 p_in);

#endif /* FCCV_h */
