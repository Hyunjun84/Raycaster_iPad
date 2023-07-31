//
//  Shaders.metal
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"

constant int shaderType [[ function_constant(FC_SHADER_TYPE) ]];
constexpr sampler linear_sampler(coord::normalized,
                                 filter::linear,
                                 address::clamp_to_edge);

// Vertex shader outputs and fragment shader inputs
struct RasterizerData
{
    float4 position [[position]];
    float2 texCoordinate;
};

vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant Vertex *vertices [[buffer(VertexInputIndexVertices)]])
{
    RasterizerData out;
    out.position = float4(vertices[vertexID].position, 0.0f, 1.0f);
    out.texCoordinate = vertices[vertexID].texCoordinate;
    
    return out;
}

float4 BlinnPhong(float3 n, float4 eye, Light light, Material material)
{
    float3 l;
    
    l = normalize((light.position - eye*light.position.w).xyz);
    
    float3 v = -normalize(eye.xyz);
    float3 h = normalize(l + v);
    
    float l_dot_n = max(dot(l,n), 0.0f);
    float3 ambient = light.ambient * material.ambient;
    float3 diffuse = light.diffuse * material.diffuse * l_dot_n;
    float3 specular = float3(0);

    if(l_dot_n >= 0.0) {
        specular = light.specular * material.specular * pow(max(dot(h, n), 0.0), material.shininess);
    }
    return float4(ambient + diffuse + specular, 1);
}

float4 MinMaxCurvature(float3 g, float3 dii, float3 dij, texture2d<float,access::sample> ColorMap)
{
    float3x3 H = float3x3(dii.x, dij.z, dij.y,
                          dij.z, dii.y, dij.x,
                          dij.y, dij.x, dii.z);
    
    float one_over_len_g = 1.0/length(g);
    float3 n = g*one_over_len_g;
    float3x3 P = float3x3(1-n.x*n.x,  -n.x*n.y,  -n.x*n.z,
                           -n.x*n.y, 1-n.y*n.y,  -n.y*n.z,
                           -n.x*n.z,  -n.y*n.z, 1-n.z*n.z);
    float3x3 M = (-1.0*P)*H*P*one_over_len_g;
    float T = M[0][0] + M[1][1] + M[2][2];
    float3x3 MMt = M*transpose(M);
    float F = sqrt(MMt[0][0] + MMt[1][1] + MMt[2][2]);
    float k_max = (T + sqrt(2.0*F*F - T*T))*0.5;
    float k_min = (T - sqrt(2.0*F*F - T*T))*0.5;
    
    float scale_k = 0.005;
    float2 tc = float2(scale_k*float2(k_max, k_min)+0.5);
    return ColorMap.sample(linear_sampler, tc);
}

fragment float4 fragmentShader(RasterizerData in [[stage_in]],
                               constant float4x4& MV [[ buffer(0) ]],
                               constant Light& light [[buffer(1)]],
                               constant Material& front [[buffer(2)]],
                               constant Material& back [[buffer(3)]],
                               texture2d<float,access::sample> Pos [[ texture(0) ]],
                               texture2d<float,access::sample> Grad [[ texture(1) ]],
                               texture2d<float,access::sample> HessianII [[ texture(2), function_constant(shaderType) ]],
                               texture2d<float,access::sample> HessianIJ [[ texture(3), function_constant(shaderType) ]],
                               texture2d<float,access::sample> ColorMap [[ texture(4), function_constant(shaderType) ]])
{
    float4 p = Pos.sample(linear_sampler, in.texCoordinate);
    float3 g = -Grad.sample(linear_sampler, in.texCoordinate).xyz;
    float3x3 MV3 = float3x3(MV[0].xyz, MV[1].xyz, MV[2].xyz);
    float4 color = float4(0,0,0,1);
    
    Material material;
    if(p.w != 0.0f) {
        if (p.w>0) {
            material = front;
        } else {
            material = back;
        }
        switch(shaderType) {
            case ST_BLINN_PHONG :
                color = BlinnPhong(normalize(MV3*p.w*normalize(g)),
                                   MV*p,
                                   light, material);
                break;
            case ST_CURVATURE :
                float3 dii = HessianII.sample(linear_sampler, in.texCoordinate).xyz;
                float3 dij = HessianIJ.sample(linear_sampler, in.texCoordinate).xyz;
                color = MinMaxCurvature(g, dii, dij, ColorMap);
                break;
        }
    }
    
    return color;
}
