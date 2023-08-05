//
//  ShaderTypes.h
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

enum VertexInputIndex
{
    VertexInputIndexVertices     = 0,
    VertexInputIndexViewportSize = 1,
};

struct Vertex
{
    vector_float2 position;
    vector_float2 texCoordinate;
};

struct Hessian
{
    vector_float4 dii;
    vector_float4 dij;
};

struct Light
{
    vector_float4 position;
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
};

struct Material
{
    vector_float3 ambient;
    vector_float3 diffuse;
    vector_float3 specular;
    float shininess;
};

enum KernelType
{
    KT_FCCV2=0,
    KT_FCCV3,
    KT_CC6,
    KT_NR_KERNELS
};

enum ShaderType
{
    ST_BLINN_PHONG=0,
    ST_CURVATURE,
    ST_ERROR,
    ST_NR_SHADERS
};

enum FunctionConstant
{
    FC_SHADER_TYPE=0,
    FC_KERNEL_TYPE,
    FC_IS_TILED
};

#endif /* ShaderTypes_h */
