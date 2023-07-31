//
//  ShaderTypes.h
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>
// Buffer index values shared between shader and C code to ensure Metal shader buffer inputs
// match Metal API buffer set calls.
enum VertexInputIndex
{
    VertexInputIndexVertices     = 0,
    VertexInputIndexViewportSize = 1,
};

//  This structure defines the layout of vertices sent to the vertex
//  shader. This header is shared between the .metal shader and C code, to guarantee that
//  the layout of the vertex array in the C code matches the layout that the .metal
//  vertex shader expects.
struct Vertex
{
    vector_float2 position;
    vector_float2 texCoordinate;
};

struct Ray
{
    vector_float4 begin;
    vector_float4 end;
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
    ST_NR_SHADERS
};

enum FunctionConstant
{
    FC_SHADER_TYPE=0,
    FC_KERNEL_TYPE,
    FC_IS_TILED
};


#endif /* ShaderTypes_h */
