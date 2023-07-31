//
//  CC6.h
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#ifndef CC6_h
#define CC6_h

#include <metal_stdlib>
using namespace metal;

void fetch_cc6_coefficients(thread float* c, texture3d<float, access::sample> Vol, float3 org, float3 R, float3x3 P);
float eval_cc6(texture3d<float, access::sample> Vol, float3 p_in);
float3 eval_grad_cc6(texture3d<float, access::sample> Vol, float3 p_in);
Hessian eval_Hessian_cc6(texture3d<float, access::sample> Vol, float3 p_in);

#endif /* CC6_h */
