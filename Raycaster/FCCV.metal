//
//  FCCV.metal
//  Raycaster
//
//  Created by H.Kim on 2023/07/31.
//

#include <metal_stdlib>
using namespace metal;

#include "ShaderTypes.h"
#include "FCCV.h"

constexpr sampler sp_texel(coord::pixel,
                           filter::nearest,
                           address::clamp_to_edge);
/*
constexpr sampler linear_sampler(coord::pixel,
                                 filter::linear,
                                 address::clamp_to_zero);
*/

// FCC V2
#define SCALE_V2_F (0.041666667f)
#define SCALE_V2_G (0.0625f)
#define SCALE_V2_H (0.0625f)

#define SCALE_V3_F (0.000086806f)
#define SCALE_V3_G (0.000520833f)
#define SCALE_V3_H (0.002604167f)

#define c0 c[0]
#define c1 c[1]
#define c2 c[2]
#define c3 c[3]
#define c4 c[4]
#define c5 c[5]
#define c6 c[6]
#define c7 c[7]
#define c8 c[8]
#define c9 c[9]
#define c10 c[10]
#define c11 c[11]
#define c12 c[12]
#define c13 c[13]
#define c14 c[14]
#define c15 c[15]
#define c16 c[16]
#define c17 c[17]
#define c18 c[18]
#define c19 c[19]
#define c20 c[20]
#define c21 c[21]
#define c22 c[22]
#define c23 c[23]
#define c24 c[24]
#define c25 c[25]
#define c26 c[26]


float sgn(float x)
{
    return float(float(x>=0.0f)*2.0f-1.0);
}

float3 find_fcc_nearest(float3 p)
{
    float3 org = round(p);
    if( (int(org.x+org.y+org.z)&0x01) != 0 ) {
        float3 l = p-org;
        float3 ul = fabs(l);
        if(ul.x > ul.y) {
            if(ul.x > ul.z)   org.x += sgn(l.x);
            else              org.z += sgn(l.z);
        } else {
            if(ul.y > ul.z)   org.y += sgn(l.y);
            else              org.z += sgn(l.z);
        }
    }
    return org;
}

float3 find_R(float3 l)
{
    // computes the membership against the six knot planes intersecting the unit cube centered at the local origin
    thread float dR[6] = {
        float(l.z>=l.y),
        float(l.z>=l.x),
        float(l.y>=l.x),
        float(l.x>=-l.y),
        float(l.x>=-l.z),
        float(l.y>=-l.z)
    };

    // type_R: the `reflection transformation' which is one of four `even reflections'
    // The reflection matrix R for each type:
    // (0,0,0): [1, 0, 0] (0,1,1): [1, 0, 0] (1,0,1): [-1, 0, 0] (1,1,0): [-1, 0, 0]
    //          [0, 1, 0]          [0,-1, 0]          [ 0, 1, 0]          [ 0,-1, 0]
    //          [0, 0, 1]          [0, 0,-1]          [ 0, 0,-1]          [ 0, 0, 1]
    float3 R = float3(((1-dR[1])*(1-dR[2])*(1-dR[5])),
                      ((1-dR[0])*   dR[2] *(1-dR[4])),
                      (   dR[0] *   dR[1] *(1-dR[3])));
    R += dR[3]*dR[4]*dR[5] - R.yzx - R.zxy;
    
    return R;
}


float3x3 find_P(float3 l)
{
    int3 dP = int3(l.y>=l.x,
                   l.z>=l.x,
                   l.z>=l.y);

    int idx_P = 2*(dP.x+dP.y)+dP.z;
    
    float3 vecP1 = float3(idx_P==0, idx_P==4, idx_P==3);
    float3 vecP2 = float3(idx_P==1, idx_P==2, idx_P==5);
    
    float3 vecPx = vecP1+vecP2;
    float3 vecPy = vecP1.zxy+vecP2.yzx;
    float3 vecPz = vecP1.yzx+vecP2.zxy;
    
    return float3x3(vecPx, vecPy, vecPz);
}

float4 to_barycentric(float3 p)
{
    return float4(1.0f-p.x-p.y,
                       p.y+p.z,
                       p.x-p.y,
                       p.y-p.z);
}

void fetch_fccv2_coefficients(thread float* c, texture3d<float, access::sample> Vol, float3 org, float3 R, float3x3 P)
{
    float3 dirx = R*(P*float3(1,0,0));
    float3 diry = R*(P*float3(0,1,0));
    float3 dirz = R*(P*float3(0,0,1));
    
    int3 p = int3(org);
    int offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c0 = Vol.sample(sp_texel, float3(p>>1))[offset];
    p = int3(org+2*dirx);
    c1 = Vol.sample(sp_texel, float3(p>>1))[offset];
    
    p = int3(org+diry-dirz);
    offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c2 = Vol.sample(sp_texel, float3(p>>1))[offset];
    p = int3(org+diry+dirz);
    c3 = Vol.sample(sp_texel, float3(p>>1))[offset];
    
    p = int3(org+dirx-dirz);
    offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c4 = Vol.sample(sp_texel, float3(p>>1))[offset];
    p = int3(org+dirx+dirz);
    c5 = Vol.sample(sp_texel, float3(p>>1))[offset];
    
    p = int3(org+dirx-diry);
    offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c6 = Vol.sample(sp_texel, float3(p>>1))[offset];
    p = int3(org+dirx+diry);
    c7 = Vol.sample(sp_texel, float3(p>>1))[offset];
}

float eval_fccv2(texture3d<float, access::sample> Vol, float3 p_in)
{
    // Find nearest neighbor FCC lattice site
    float3 org = find_fcc_nearest(p_in);
    float3 p_local = p_in - org;    // local coordinates

    // Note that R^{-1} = R.
    float3 R = find_R(p_local);
    p_local = R*p_local;

    // Note that P^{-1} = P^T
    float3x3 P = find_P(p_local);
    p_local = transpose(P)*p_local;
    
    float4 u1 = to_barycentric(p_local);
    
    float c[8];
    fetch_fccv2_coefficients(c, Vol, org, R, P);
    
    // Evaluation
    float val = 0;
    float4 u2 = u1*u1;
    float4 u3 = u2*u1;
    
    val += u2.x*(u1.y*(9*c0+c3+c5+c7) +
                 u1.z*(8*c0+c4+c5+c6+c7) +
                 u1.w*(9*c0+c2+c4+c7));

    val += u1.x*(2*(u2.y*(3*c0+c3+c5+c7) +
                    u2.z*(2*c0+c4+c5+c6+c7) +
                    u2.w*(3*c0+c2+c4+c7)) +
                u1.z*(u1.w*(12*c0 + 5*(c4+c7) + c5+c6)+
                      u1.y*(12*c0 + 5*(c5+c7) + c4+c6))+
                u1.y*u1.w*(14*c0+6*c7+c2+c3+c4+c5));
    
    val += u3.y*(c0+c3+c5+c7) +
           u3.w*(c0+c2+c4+c7) +
           u1.y*u1.w*(u1.y*(5*(c0+c7)+c3+c5) +
                      u1.w*(5*(c0+c7)+c2+c4)) +
           u2.z*(u1.y*(3*(c0+c5+c7)+c1+c4+c6)+
                 u1.w*(3*(c0+c4+c7)+c1+c5+c6));

    val += 4*(u1.z*(u2.y*(c0+c5+c7)+u2.w*(c0+c4+c7)) + u3.x*c0);
    val += u1.y*u1.z*u1.w*(2*(c4+c5) + (9*(c0+c7)+c1+c6));
    val *= 6;
    val += 4*u3.z*(c0+c1+c4+c5+c6+c7);
    
    return val*SCALE_V2_F;
}


float3 eval_grad_fccv2(texture3d<float, access::sample> Vol, float3 p_in)
{
    // Find origin
    float3 org = find_fcc_nearest(p_in);
    // local coordinates
    float3 p_local = p_in - org;

    float3 R = find_R(p_local);
    p_local = R*p_local;

    float3x3 P = find_P(p_local);
    p_local = transpose(P)*p_local;

    float4 u1 = to_barycentric(p_local);
    
    thread float c[8];
    fetch_fccv2_coefficients(c, Vol, org, R, P);

    // Evaluation
    float3 d = (float3)(0);
    float4 u2 = u1*u1;

    d.x += u2.x*(     (          (2*(c5+c7+c6+c4) + 8*(-c0))));
    d.x += u1.x*(u1.y*(          (2*(c6+c4) + 4*(-c3) + 6*(c5+c7) + 12*(-c0)))+
                      (u1.z*     (4*(c5+c7+c6+c4) + 16*(-c0))+
                            u1.w*(2*(c5+c6) + 4*(-c2) + 6*(c7+c4) + 12*(-c0))));
    d.x +=      (u2.y*(          (4*(-c0-c3+c5+c7)))+
                 u1.y*(u1.z*     (2*(c6+c4+c5+c7) + 4*(c1) + 12*(-c0))+
                            u1.w*(2*(-c3-c2+c1+c6+c4+c5) + 6*(c7) + 10*(-c0)))+
                      (u2.z*     (4*(-c0+c1))+
                       u1.z*u1.w*(2*(c7+c4+c5+c6) + 4*(c1) + 12*(-c0))+
                            u2.w*(4*(-c0-c2+c7+c4))));

    d.y += u2.x*(     (          (2*(-c6+c3+c7+c2) + 4*(-c0))));
    d.y += u1.x*(u1.y*(          (2*(-c6+c2) + 4*(-c5) + 6*(c3+c7) + 8*(-c0)))+
                      (u1.z*     (8*(-c6+c7))+
                            u1.w*(2*(-c6+c3) + 4*(-c4) + 6*(c7+c2) + 8*(-c0))));
    d.y +=      (u2.y*(          (4*(-c5-c0+c3+c7)))+
                 u1.y*(u1.z*     (2*(-c5-c0-c4-c1) + 4*(-c6) + 12*(c7))+
                            u1.w*(2*(-c5-c4-c1-c6+c3+c2) + 6*(-c0) + 10*(c7)))+
                      (u2.z*     (4*(-c6+c7))+
                       u1.z*u1.w*(2*(-c0-c1-c4-c5) + 4*(-c6) + 12*(c7))+
                            u2.w*(4*(-c0-c4+c7+c2))));

    d.z += u2.x*(     (          (2*(-c2-c4+c5+c3))));
    d.z += u1.x*(u1.y*(          (2*(-c2-c4) + 4*(-c7-c0) + 6*(c5+c3)))+
                      (u1.z*     (8*(-c4+c5))+
                            u1.w*(2*(c5+c3) + 4*(c7+c0) + 6*(-c2-c4))));
    d.z +=      (u2.y*(          (4*(-c7-c0+c5+c3)))+
                 u1.y*(u1.z*     (2*(-c7-c0-c1-c6) + 4*(-c4) + 12*(c5))+
                            u1.w*(4*(-c2-c4+c5+c3)))+
                      (u2.z*     (4*(-c4+c5))+
                       u1.z*u1.w*(2*(c7+c0+c1+c6) + 4*(c5) + 12*(-c4))+
                            u2.w*(4*(-c2-c4+c7+c0))));
    
    // [dx dy dz]^T_{\pi_n} = R_n*P_n*[dx dy dz]^T_{\pi_0}
    d = R*(P*d);
    return d*SCALE_V2_G;
}


Hessian eval_Hessian_fccv2(texture3d<float, access::sample> vol, float3 p_in)
{
    // Find origin
    float3 org = find_fcc_nearest(p_in);
    // local coordinates
    float3 p_local = p_in - org;

    float3 R = find_R(p_local);
    p_local = R*p_local;

    float3x3 P = find_P(p_local);
    p_local = transpose(P)*p_local;

    float4 u1 = to_barycentric(p_local);
    
    thread float c[8];
    fetch_fccv2_coefficients(c, vol, org, R, P);

    Hessian H;
    H.dii = float4(0);
    H.dij = float4(0);

    
    // dxx
    H.dii.x +=      (u1.y*(          (2*(-c5-c7+c1+c3)))+
                      (u1.z*     (2*(-c5-c7-c6-c4) + 4*(c0+c1))+
                            u1.w*(2*(-c7-c4+c1+c2))));
    // dyy
    H.dii.y += u1.x*(     (          (2*(-c5-c4+c3+c2) + 4*(-c0+c6))));
    H.dii.y +=      (u1.y*(          (2*(-c5-c0+c3+c6)))+
                      (u1.z*     (2*(-c5-c0-c4-c1) + 4*(c7+c6))+
                            u1.w*(2*(-c0-c4+c2+c6))));
    // dzz
    H.dii.z += u1.x*(     (          (2*(c5+c3+c2+c4) + 4*(-c7-c0))));
    H.dii.z +=      (u1.y*(          (2*(c5+c3+c2+c4) + 4*(-c7-c0)))+
                      (u1.z*     (2*(-c7-c0-c1-c6) + 4*(c5+c4))+
                            u1.w*(2*(c5+c3+c2+c4) + 4*(-c7-c0))));

    // dyz
    H.dij.x += u1.x*(     (          (2*(-c6-c3-c2+c7) + 4*(c0))));
    H.dij.x +=      (u1.y*(          (1*(-c6-c4-c1-c2+c5) + 3*(-c3+c7+c0)))+
                      (     u1.w*(1*(-c1-c3-c6-c5+c4) + 3*(-c2+c0+c7))));

    // dzx
    H.dij.y += u1.x*(     (          (2*(-c4-c3+c5+c2))));
    H.dij.y +=      (u1.y*(          (1*(-c1-c6-c4+c7+c0+c2) + 3*(-c3+c5)))+
                      (     u1.w*(1*(-c7-c0-c3+c1+c6+c5) + 3*(-c4+c2))));

    // dxy
    H.dij.z += u1.x*(     (          (2*(-c5-c2+c3+c4))));
    H.dij.z +=      (u1.y*(          (1*(-c7-c0-c2+c4+c1+c6) + 3*(-c5+c3)))+
                      (     u1.w*(1*(-c5-c1-c6+c3+c7+c0) + 3*(-c2+c4))));

    H.dii.xyz = P*H.dii.xyz*SCALE_V2_H;
    H.dij.xyz = R*(P*H.dij.xyz)*SCALE_V2_H;

    return H;
}

// 3rd order voronoi spline

void fetch_fccv3_coefficients(thread float* c, texture3d<float, access::sample> Vol, float3 org, float3 R, float3x3 P)
{
    int3 dir2x = int3(R*(P*float3(2,0,0)));
    int3 dir2y = int3(R*(P*float3(0,2,0)));
    int3 dir2z = int3(R*(P*float3(0,0,2)));
    
    int3 p = int3(org);              int offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c0 = Vol.sample(sp_texel, float3(p>>1))[offset];  //( 0, 0, 0)
    p -= dir2z;                c15 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 0, 0,-2)
    p += 2*dir2z;              c16 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 0, 0, 2)
    p -= dir2y+dir2z;          c14 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 0,-2, 0)
    p += 2*dir2y;              c17 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 0, 2, 0)
    p -= dir2x+dir2y;          c13 = Vol.sample(sp_texel, float3(p>>1))[offset]; //(-2, 0, 0)
    p += 2*dir2x;              c18 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 2, 0, 0)

    p -= (dir2y-dir2z)>>1;     offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c24 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 2,-1, 1)
    p -= dir2z;                c23 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 2,-1,-1)
    p += dir2y;                c25 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 2, 1,-1)
    p += dir2z;                c26 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 2, 1, 1)
    p -= dir2x;                c8 = Vol.sample(sp_texel, float3(p>>1))[offset];  //( 0, 1, 1)
    p -= dir2z;                c7 = Vol.sample(sp_texel, float3(p>>1))[offset];  //( 0, 1,-1)
    p -= dir2y;                c5 = Vol.sample(sp_texel, float3(p>>1))[offset];  //( 0,-1,-1)
    p += dir2z;                c6 = Vol.sample(sp_texel, float3(p>>1))[offset];  //( 0,-1, 1)

    p += (dir2x+dir2y)>>1;     offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c11 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 0, 1)
    p -= dir2x;                c3 = Vol.sample(sp_texel, float3(p>>1))[offset];  //(-1, 0, 1)
    p -= dir2z;                c2 = Vol.sample(sp_texel, float3(p>>1))[offset];  //(-1, 0,-1)
    p += dir2x;                c10 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 0,-1)
    p += dir2y;                c21 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 2,-1)
    p += dir2z;                c22 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 2, 1)

    p += (dir2z-dir2y)>>1;     offset = ((p.x&0x01)<<1)+(p.y&0x01);
    c20 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 1, 2)
    p -= 2*dir2z;              c19 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 1,-2)
    p += dir2z;                c12 = Vol.sample(sp_texel, float3(p>>1))[offset]; //( 1, 1, 0)
    p -= dir2x;                c4 = Vol.sample(sp_texel, float3(p>>1))[offset];  //(-1, 1, 0)
    p -= dir2y;                c1 = Vol.sample(sp_texel, float3(p>>1))[offset];  //(-1,-1, 0)
    p += dir2x;                c9 = Vol.sample(sp_texel, float3(p>>1))[offset];  //( 1,-1, 0)
}


float eval_fccv3(texture3d<float, access::sample> Vol, float3 p_in)
{
    // Find nearest neighbor FCC lattice site
    float3 org = find_fcc_nearest(p_in);
    float3 p_local = p_in - org;    // local coordinates

    // Note that R^{-1} = R.
    float3 R = find_R(p_local);
    p_local = R*p_local;

    // Note that P^{-1} = P^T
    float3x3 P = find_P(p_local);
    p_local = transpose(P)*p_local;
    
    thread float c[27];
    fetch_fccv3_coefficients(c, Vol, org, R, P);


    // Evaluation
    float val = 0;
    float3 X = p_local;
    float3 X2 = X*X;
    float3 X3 = X2*X;
    float3 X4 = X3*X;
    float3 X5 = X4*X;
    float3 X6 = X5*X;
    
    val +=    9.f*(X6.y*(c19+c20+c25+c26-c2-c3-c15-c16+2.f*(c9-c1-c18-c21-c22)+4.f*(c4+c14)-5.f*(c10+c11)+7.f*(c7+c8)-8.f*(c0+c17)+10.f*c12)+
                 X6.z*((c2+c3+c5+c6+c21+c22+c25+c26)-2.f*(c4+c9+c15+c16+c17+c18+c19+c20)+6.f*(c7+c8+c10+c11)-8.f*(c0+c12)));
    
    val +=   18.f*(X6.x*((c9+c10+c11+c12-c1-c2-c3-c4)+2.f*(c13-c18))+
                 X.x*(X5.y*((-c25-c26)+2.f*(c13+c15+c16-c19-c20)+3.f*(-c5-c6+c21+c22)+4.f*(-c0-c4-c10-c11-c18)+5.f*(c2+c3)+6.f*(-c1-c17)+10.f*(c12)+12.f*(c9))+
                      X5.z*((-c2+c3-c7+c8+c10-c11+c25-c26)+2.f*(-c5+c6+c21-c22)+3.f*(c15-c16-c19+c20)))+
                 X5.y*(X.z*((c19-c20)+2.f*(c25-c26)+3.f*(c10-c11+c15-c16-c21+c22)+6.f*(c2-c3)+7.f*(-c7+c8)+9.f*(-c5+c6))+
                       ((-c15-c16)+2.f*(-c10-c11-c13)+3.f*(c7+c8)+6.f*(-c2-c3+c4+c9)+9.f*(c5+c6)+12.f*(c1-c14)+16.f*(-c0)))+
                 X.y*X5.z*((-c5+c6+c7-c8-c10+c11+c21-c22)+2.f*(-c2+c3+c25-c26)+3.f*(c15-c16-c19+c20)));
    
    val +=   36.f*(X5.x*(X.y*((c14-c17)+2.f*(c5+c6-c7-c8)+3.f*(-c1+c4-c9+c12))+
                       X.z*((c15-c16)+2.f*(c5-c6+c7-c8)+3.f*(-c2+c3-c10+c11))+
                       (-c14-c15-c16-c17)+4.f*(-c5-c6-c7-c8)+6.f*(c1+c2+c3+c4+c9+c10+c11+c12-c13-c18)+16.f*(-c0))+
                 X.x*(6.f*(-c13+c18)+37.f*(-c1-c2-c3-c4+c9+c10+c11+c12))+
                 X.y*(6.f*(-c14+c17)+37.f*(-c1+c4-c5-c6+c7+c8-c9+c12))+
                 X.z*(6.f*(-c15+c16)+37.f*(-c2+c3-c5+c6-c7+c8-c10+c11))+
                 (c13+c14+c15+c16+c17+c18)+14.f*(c1+c2+c3+c4+c5+c6+c7+c8+c9+c10+c11+c12)+146.f*c0);
    
    val +=   45.f*(X2.x*(X4.y*((c5+c6+c7+c8+c15+c16+c21+c22)+2.f*(c1+c2+c3+c13-c14+c18+c23+c24)+3.f*(-c19-c20)+4.f*(c17-c25-c26)+5.f*(c10+c11)+6.f*(c12)+8.f*(-c0-c9)+10.f*(-c4))+
                       X4.z*((-c10-c11+c15+c16+c19+c20)+2.f*(c13+c14+c18+c23+c24)+3.f*(-c5-c6-c21-c22)+4.f*(-c2-c3-c4-c25-c26)+5.f*(c7+c8)+6.f*(-c9)+8.f*(-c0+c1)+16.f*(c12)))+
                 X4.y*(X2.z*((c2+c3+c21+c22)+2.f*(-c7-c8+c13-c14+c15+c16+c23+c24)+3.f*(c5+c6-c25-c26)+4.f*(c17-c19-c20)+6.f*(-c4+c10+c11)+8.f*(-c0+c12)+10.f*(-c9))+
                       (2.f*(c13+c15+c16+c18+c21+c22)+9.f*(c2+c3+c10+c11)+12.f*(-c4-c9+c14+c17)+13.f*(-c5-c6)+14.f*(-c1)+15.f*(-c7-c8)+18.f*(-c12)+40.f*(c0)))+
                 X2.y*X4.z*((-c10-c11+c15+c16+c19+c20)+2.f*(c13+c14+c17+c23+c24)+3.f*(-c2-c3-c25-c26)+4.f*(-c5-c6-c9-c21-c22)+5.f*(c7+c8)+6.f*(-c4)+8.f*(-c0+c1)+16.f*(c12))+
                 X4.z*(2.f*(c13+c14+c17+c18+c19+c20)+8.f*(c1+c12)+10.f*(c4+c9)+12.f*(c15+c16)+13.f*(-c2-c3-c5-c6)+15.f*(-c7-c8-c10-c11)+40.f*(c0)));
    
    val +=   54.f*X5.z*((c2-c3+c5-c6+c7-c8+c10-c11)+2.f*(-c15+c16));
    
    val +=   90.f*(X4.x*(X2.y*((c1+c4+c5+c6+c7+c8-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2.f*(c10+c11-c19-c20-c21-c22)+3.f*(-c18)+5.f*(-c9)+7.f*(c12)+8.f*(-c0))+
                       X2.z*((c2+c3+c5+c6+c7+c8+c10+c11-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2.f*(-c19-c20-c21-c22)+3.f*(-c18)+4.f*(-c9)+8.f*(-c0+c12))+
                       (c14+c15+c16+c17+c23+c24+c25+c26)+5.f*(c5+c6+c7+c8)+6.f*(c13+c18)+7.f*(-c1-c2-c3-c4)+9.f*(-c9-c10-c11-c12)+24.f*(c0))+
                 X2.x*(X2.y*(X2.z*((c5+c6)+2.f*(-c2-c3)+4.f*(c13+c14)+7.f*(c15+c16)+8.f*(-c18-c25-c26)+10.f*(c17+c23+c24)+11.f*(-c19-c20-c21-c22)+13.f*(c7+c8+c10+c11)+16.f*(c1)+20.f*(-c4)+38.f*(-c9)+56.f*(-c0)+64.f*(c12))+
                            ((c19+c20+c21+c22+c23+c24+c25+c26)+4.f*(c15+c16)+5.f*(-c5-c6-c7-c8-c10-c11)+6.f*(c12-c13-c14-c17-c18)+8.f*(-c2-c3)+12.f*(c9)+18.f*(c1+c4)))+
                       X2.z*((c19+c20+c21+c22+c23+c24+c25+c26)+2.f*(-c9)+4.f*(c14+c17)+5.f*(-c5-c6-c7-c8)+6.f*(-c13-c15-c16-c18)+8.f*(-c1-c4-c12)+9.f*(c10+c11)+18.f*(c2+c3))+
                       (-c14-c15-c16-c17)+6.f*(c13+c18)+8.f*(-c5-c6-c7-c8)+10.f*(c1+c2+c3+c4+c9+c10+c11+c12)+56.f*(-c0))+
                 X.x*(X4.y*(X.z*((-c15+c16)+2.f*(c5-c6-c23+c24)+3.f*(-c10+c11+c19-c20+c25-c26)+5.f*(c2-c3)+9.f*(-c7+c8))+
                           ((-c15-c16)+2.f*(c5+c6+c7+c8-c13+c18+c21+c22)+3.f*(c10+c11)+4.f*(c1)+5.f*(-c2-c3)+6.f*(-c9-c17)+8.f*(-c12)+10.f*(c4)))+
                      X.y*X4.z*(2.f*(-c4-c9+c13+c14-c23-c24)+3.f*(-c2-c3-c5-c6-c21-c22-c25-c26)+4.f*(c7+c8+c12+c17+c18)+8.f*(c1)+10.f*(c10+c11)+20.f*(-c0))+
                      X4.z*(2.f*(-c4-c7-c8+c9-c13-c14+c18+c19+c20)+3.f*(-c15-c16)+4.f*(c12)+6.f*(c5+c6)+7.f*(c2+c3-c10-c11)+8.f*(-c1)))+
                 X4.y*X.z*(2.f*(-c15+c16-c21+c22)+3.f*(-c10+c11)+5.f*(-c2+c3+c5-c6)+9.f*(c7-c8))+
                 X2.y*(X2.z*((c19+c20+c21+c22+c23+c24+c25+c26)+2.f*(-c4)+4.f*(c13+c18)+5.f*(-c2-c3)+6.f*(-c14-c15-c16-c17)+8.f*(-c1-c9-c10-c11-c12)+12.f*(c7+c8)+18.f*(c5+c6))+
                      ((-c13-c15-c16-c18)+6.f*(c14+c17)+8.f*(-c2-c3-c10-c11)+10.f*(c1+c4+c5+c6+c7+c8+c9+c12)+56.f*(-c0)))+
                 X.y*X4.z*(2.f*(c4-c9-c10-c11-c13-c14+c17+c19+c20)+3.f*(-c15-c16)+4.f*(c12)+6.f*(c2+c3)+7.f*(c5+c6-c7-c8)+8.f*(-c1))+
                 X2.z*((-c13-c14-c17-c18)+6.f*(c15+c16)+8.f*(-c1-c4-c9-c12)+10.f*(c2+c3+c5+c6+c7+c8+c10+c11)+56.f*(-c0)));
    
    val +=  180.f*(X4.x*(X.y*(X.z*((c23-c24-c25+c26)+2.f*(c19-c20+c21-c22)+3.f*(c5-c6-c7+c8)+6.f*(-c10+c11))+
                                (-c14+c17-c23-c24+c25+c26)+2.f*(c1-c4-c5-c6+c7+c8)+6.f*(c9-c12))+
                       X.z*((-c15+c16-c23+c24-c25+c26)+2.f*(c2-c3-c5+c6-c7+c8)+6.f*(c10-c11)))+
                 X3.x*(X3.y*((c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+2.f*(c1-c4+c7+c8+c12+c17)+4.f*(c18)+8.f*(-c0))+
                       X2.y*(X.z*((-c15+c16)+3.f*(c19-c20+c21-c22-c23+c24+c25-c26)+4.f*(c2-c3)+5.f*(-c10+c11)+6.f*(c5-c6)+12.f*(-c7+c8))+
                                 (-c10-c11+c19+c20+c21+c22)+2.f*(-c9+c13-c15-c16+c23+c24+c25+c26)+4.f*(-c1-c4)+6.f*(-c18)+8.f*(-c12)+16.f*(c0))+
                       X.y*(X2.z*(2.f*(-c9+c14)+3.f*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4.f*(c1-c4+c17)+6.f*(c7+c8)+8.f*(c12)+12.f*(c18)+24.f*(-c0))+
                                 (-c5-c6+c7+c8-c23-c24+c25+c26)+4.f*(c9-c12))+
                       X3.z*((-c10+c11-c15+c16+c19-c20+c21-c22-c23+c24+c25-c26)+2.f*(c2-c3+c5-c6)+4.f*(-c7+c8))+
                       X2.z*((c19+c20+c21+c22)+2.f*(c9+c13-c14-c17+c23+c24+c25+c26)+4.f*(-c2-c3-c12)+5.f*(-c10-c11)+6.f*(-c18)+16.f*(c0))+
                       X.z*((-c5+c6-c7+c8-c23+c24-c25+c26)+4.f*(c10-c11)))+
                 X2.x*(X3.y*(X.z*(2.f*(c21-c22)+3.f*(c5-c6+c23-c24+c25-c26)+4.f*(c19-c20)+6.f*(c2-c3)+9.f*(-c7+c8)+16.f*(-c10+c11))+
                            ((-c5-c6-c7-c8-c15-c16+c19+c20-c23-c24+c25+c26)+2.f*(c9+c14+c21+c22)+4.f*(-c1+c4-c17)+8.f*(c0-c12)))+
                       X2.y*X.z*((-c15+c16)+4.f*(-c19+c20)+5.f*(-c5+c6-c21+c22-c23+c24-c25+c26)+8.f*(-c2+c3)+13.f*(c7-c8)+25.f*(c10-c11))+
                       X.y*(X3.z*(2.f*(-c15+c16+c19-c20)+3.f*(c23-c24+c25-c26)+4.f*(c21-c22)+5.f*(c5-c6)+6.f*(c2-c3)+7.f*(-c7+c8)+14.f*(-c10+c11))+
                            X2.z*((c5+c6)+2.f*(-c17)+3.f*(-c15-c16)+4.f*(-c14+c21+c22)+5.f*(c19+c20-c23-c24+c25+c26)+6.f*(-c10-c11)+7.f*(-c7-c8)+8.f*(-c1+c4)+22.f*(c9)+24.f*(c0)+28.f*(-c12))+
                            X.z*((-c19+c20-c21+c22)+2.f*(c23-c24-c25+c26)+3.f*(c10-c11)+4.f*(-c5+c6+c7-c8)))+
                       X3.z*((-c21+c22-c23+c24-c25+c26)+2.f*(-c19+c20)+3.f*(-c5+c6+c7-c8+c15-c16)+4.f*(-c2+c3)+5.f*(c10-c11)))+
                 X.x*(X3.y*(X2.z*((c2+c3-c5-c6)+2.f*(c13-c21-c22)+3.f*(c15+c16-c19-c20-c23-c24)+4.f*(c1+c7+c8+c9+c17-c25-c26)+5.f*(c10+c11)+6.f*(-c4)+8.f*(c18)+12.f*(c12)+28.f*(-c0))+
                            ((-c5-c6-c7-c8+c10+c11+c21+c22)+4.f*(c0-c12)))+
                      X2.y*(X3.z*(2.f*(-c15+c16+c19-c20)+3.f*(c21-c22-c23+c24)+4.f*(-c10+c11+c25-c26)+5.f*(c2-c3)+6.f*(c5-c6)+11.f*(-c7+c8))+
                            X2.z*((c2+c3)+3.f*(-c15-c16)+4.f*(-c9-c13+c23+c24+c25+c26)+5.f*(c19+c20+c21+c22)+6.f*(-c17)+8.f*(-c1-c18)+10.f*(c4-c10-c11)+12.f*(-c7-c8)+16.f*(-c12)+48.f*(c0))+
                            X.z*((-c19+c20-c23+c24-c25+c26)+2.f*(-c21+c22)+4.f*(-c2+c3+c10-c11)+6.f*(c7-c8)))+
                      X.y*X2.z*((c21+c22-c23-c24+c25+c26)+2.f*(c19+c20)+3.f*(-c10-c11)+4.f*(-c1+c4+c9-c12)+6.f*(-c7-c8)+12.f*(c0))+
                      X3.z*((-c5+c6+c7-c8-c19+c20)+2.f*(c10-c11)))+
                 X3.y*(X3.z*((-c15+c16+c19-c20+c21-c22+c23-c24+c25-c26)+2.f*(c2-c3+c5-c6-c7+c8)+5.f*(-c10+c11))+
                       X2.z*((c19+c20-c23-c24+c25+c26)+2.f*(-c7-c8-c13+c14+c21+c22)+4.f*(-c5-c6+c9-c17)+6.f*(c4)+8.f*(c0-c12))+
                       X.z*((-c2+c3-c21+c22)+2.f*(c7-c8)))+
                 X3.z*(X2.y*((-c21+c22-c23+c24-c25+c26)+2.f*(c7-c8-c19+c20)+3.f*(-c2+c3+c15-c16)+4.f*(-c5+c6)+6.f*(c10-c11))+
                        X.y*((-c2+c3+c10-c11-c19+c20)+2.f*(c7-c8))));

    val +=  360.f*(X3.x*(X.y*X.z*((-c19+c20-c21+c22)+2.f*(c23-c24-c25+c26)+3.f*(c10-c11)+4.f*(-c5+c6+c7-c8))+
                      (c1+c2+c3+c4-c9-c10-c11-c12)+2.f*(-c13+c18))+
                 X2.x*(X.y*((c14-c17)+4.f*(c5+c6-c7-c8)+5.f*(-c1+c4-c9+c12))+
                       X.z*((c15-c16)+4.f*(c5-c6+c7-c8)+5.f*(-c2+c3-c10+c11)))+
                 X.x*(X3.y*X.z*((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2.f*(-c21+c22)+3.f*(-c2+c3)+7.f*(c7-c8))+
                      X2.y*((c13-c18)+4.f*(c2+c3-c10-c11)+5.f*(-c1-c4+c9+c12))+
                      X.y*X3.z*((-c21+c22+c23-c24-c25+c26)+2.f*(c10-c11+c15-c16-c19+c20)+3.f*(-c2+c3-c5+c6)+5.f*(c7-c8))+
                      X2.z*((c13-c18)+4.f*(c1+c4-c9-c12)+5.f*(-c2-c3+c10+c11)))+
                 X3.y*((c1-c4+c5+c6-c7-c8+c9-c12)+2.f*(-c14+c17))+
                 X2.y*X.z*((c15-c16)+4.f*(c2-c3+c10-c11)+5.f*(-c5+c6-c7+c8))+
                 X.y*X2.z*((c14-c17)+4.f*(c1-c4+c9-c12)+5.f*(-c5-c6+c7+c8))+
                 X3.z*((c2-c3+c5-c6+c7-c8+c10-c11)+2.f*(-c15+c16)));
    
    val += 2880.f*(X.x*X.y*(c1-c4-c9+c12)+
                 X.x*X.z*(c2-c3-c10+c11)+
                 X.y*X.z*(c5-c6-c7+c8));
    
    return val*SCALE_V3_F;
}

float3 eval_grad_fccv3(texture3d<float, access::sample> Vol, float3 p_in)
{
    // Find nearest neighbor FCC lattice site
    float3 org = find_fcc_nearest(p_in);
    float3 p_local = p_in - org;    // local coordinates

    // Note that R^{-1} = R.
    float3 R = find_R(p_local);
    p_local = R*p_local;

    // Note that P^{-1} = P^T
    float3x3 P = find_P(p_local);
    p_local = transpose(P)*p_local;
    
    thread float c[27];
    fetch_fccv3_coefficients(c, Vol, org, R, P);

    // Evaluation
    float3 d = (float3)(0);
    float3 X = p_local;
    float3 X2 = X*X;
    float3 X3 = X2*X;
    float3 X4 = X3*X;
    float3 X5 = X4*X;

    d.x +=    3*(((-c25-c26)+2*(c13+c15+c16-c19-c20)+3*(-c5-c6+c21+c22)+4*(-c0-c4-c10-c11-c18)+5*(c2+c3)+6*(-c1-c17)+10*(c12)+12*(c9))*X5.y+
                 ((-c2+c3-c7+c8+c10-c11+c25-c26)+2*(-c5+c6+c21-c22)+3*(c15-c16-c19+c20))*X5.z);
    d.x +=    6*((6*(-c13+c18)+37*(-c1-c2-c3-c4+c9+c10+c11+c12)));
    d.x +=   15*(((c5+c6+c7+c8+c15+c16+c21+c22)+2*(c1+c2+c3+c13-c14+c18+c23+c24)+3*(-c19-c20)+4*(c17-c25-c26)+5*(c10+c11)+6*(c12)+8*(-c0-c9)+10*(-c4))*X.x*X4.y+
                 ((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c18+c23+c24)+3*(-c5-c6-c21-c22)+4*(-c2-c3-c4-c25-c26)+5*(c7+c8)+6*(-c9)+8*(-c0+c1)+16*(c12))*X.x*X4.z+
                 ((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X4.y*X.z+
                 ((-c15-c16)+2*(c5+c6+c7+c8-c13+c18+c21+c22)+3*(c10+c11)+4*(c1)+5*(-c2-c3)+6*(-c9-c17)+8*(-c12)+10*(c4))*X4.y+
                 (2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X.y*X4.z+
                 (2*(-c4-c7-c8+c9-c13-c14+c18+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c5+c6)+7*(c2+c3-c10-c11)+8*(-c1))*X4.z);
    d.x +=   18*(((-c1-c2-c3-c4+c9+c10+c11+c12)+2*(c13-c18))*X5.x);
    d.x +=   30*(((c14-c17)+2*(c5+c6-c7-c8)+3*(-c1+c4-c9+c12))*X4.x*X.y+
                 ((c15-c16)+2*(c5-c6+c7-c8)+3*(-c2+c3-c10+c11))*X4.x*X.z+
                 ((-c14-c15-c16-c17)+4*(-c5-c6-c7-c8)+6*(c1+c2+c3+c4+c9+c10+c11+c12-c13-c18)+16*(-c0))*X4.x+
                 ((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X.x*X2.y*X2.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+4*(c15+c16)+5*(-c5-c6-c7-c8-c10-c11)+6*(c12-c13-c14-c17-c18)+8*(-c2-c3)+12*(c9)+18*(c1+c4))*X.x*X2.y+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c9)+4*(c14+c17)+5*(-c5-c6-c7-c8)+6*(-c13-c15-c16-c18)+8*(-c1-c4-c12)+9*(c10+c11)+18*(c2+c3))*X.x*X2.z+
                 ((-c14-c15-c16-c17)+6*(c13+c18)+8*(-c5-c6-c7-c8)+10*(c1+c2+c3+c4+c9+c10+c11+c12)+56*(-c0))*X.x+
                 ((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X3.y*X2.z+
                 ((-c5-c6-c7-c8+c10+c11+c21+c22)+4*(c0-c12))*X3.y+
                 (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X2.y*X3.z+
                 ((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X2.y*X2.z+
                 ((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X2.y*X.z+
                 ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X.y*X2.z+
                 ((-c5+c6+c7-c8-c19+c20)+2*(c10-c11))*X3.z);
    d.x +=   60*(((c1+c4+c5+c6+c7+c8-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(c10+c11-c19-c20-c21-c22)+3*(-c18)+5*(-c9)+7*(c12)+8*(-c0))*X3.x*X2.y+
                 ((c2+c3+c5+c6+c7+c8+c10+c11-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(-c19-c20-c21-c22)+3*(-c18)+4*(-c9)+8*(-c0+c12))*X3.x*X2.z+
                 ((c14+c15+c16+c17+c23+c24+c25+c26)+5*(c5+c6+c7+c8)+6*(c13+c18)+7*(-c1-c2-c3-c4)+9*(-c9-c10-c11-c12)+24*(c0))*X3.x+
                 (2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X.x*X3.y*X.z+
                 ((-c5-c6-c7-c8-c15-c16+c19+c20-c23-c24+c25+c26)+2*(c9+c14+c21+c22)+4*(-c1+c4-c17)+8*(c0-c12))*X.x*X3.y+
                 ((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X.x*X2.y*X.z+
                 (2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X.x*X.y*X3.z+
                 ((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X.x*X.y*X2.z+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X.x*X.y*X.z+
                 ((-c21+c22-c23+c24-c25+c26)+2*(-c19+c20)+3*(-c5+c6+c7-c8+c15-c16)+4*(-c2+c3)+5*(c10-c11))*X.x*X3.z+
                 ((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X3.y*X.z+
                 ((c13-c18)+4*(c2+c3-c10-c11)+5*(-c1-c4+c9+c12))*X2.y+
                 ((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X.y*X3.z+
                 ((c13-c18)+4*(c1+c4-c9-c12)+5*(-c2-c3+c10+c11))*X2.z);
    d.x +=   90*(((c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+2*(c1-c4+c7+c8+c12+c17)+4*(c18)+8*(-c0))*X2.x*X3.y+
                 ((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X2.x*X2.y*X.z+
                 ((-c10-c11+c19+c20+c21+c22)+2*(-c9+c13-c15-c16+c23+c24+c25+c26)+4*(-c1-c4)+6*(-c18)+8*(-c12)+16*(c0))*X2.x*X2.y+
                 (2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X2.x*X.y*X2.z+
                 ((-c5-c6+c7+c8-c23-c24+c25+c26)+4*(c9-c12))*X2.x*X.y+
                 ((-c10+c11-c15+c16+c19-c20+c21-c22-c23+c24+c25-c26)+2*(c2-c3+c5-c6)+4*(-c7+c8))*X2.x*X3.z+
                 ((c19+c20+c21+c22)+2*(c9+c13-c14-c17+c23+c24+c25+c26)+4*(-c2-c3-c12)+5*(-c10-c11)+6*(-c18)+16*(c0))*X2.x*X2.z+
                 ((-c5+c6-c7+c8-c23+c24-c25+c26)+4*(c10-c11))*X2.x*X.z);
    d.x +=  120*(((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X3.x*X.y*X.z+
                 ((-c14+c17-c23-c24+c25+c26)+2*(c1-c4-c5-c6+c7+c8)+6*(c9-c12))*X3.x*X.y+
                 ((-c15+c16-c23+c24-c25+c26)+2*(c2-c3-c5+c6-c7+c8)+6*(c10-c11))*X3.x*X.z+
                 ((c14-c17)+4*(c5+c6-c7-c8)+5*(-c1+c4-c9+c12))*X.x*X.y+
                 ((c15-c16)+4*(c5-c6+c7-c8)+5*(-c2+c3-c10+c11))*X.x*X.z);
    d.x +=  180*(((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X2.x*X.y*X.z+
                 ((c1+c2+c3+c4-c9-c10-c11-c12)+2*(-c13+c18))*X2.x);
    d.x +=  480*(((c1-c4-c9+c12))*X.y+
                 ((c2-c3-c10+c11))*X.z);

    d.y +=    3*(((-c5+c6+c7-c8-c10+c11+c21-c22)+2*(-c2+c3+c25-c26)+3*(c15-c16-c19+c20))*X5.z);
    d.y +=    6*(((c14-c17)+2*(c5+c6-c7-c8)+3*(-c1+c4-c9+c12))*X5.x+
                 (6*(-c14+c17)+37*(-c1+c4-c5-c6+c7+c8-c9+c12)));
    d.y +=    9*(((-c2-c3-c15-c16+c19+c20+c25+c26)+2*(-c1+c9-c18-c21-c22)+4*(c4+c14)+5*(-c10-c11)+7*(c7+c8)+8*(-c0-c17)+10*(c12))*X5.y);
    d.y +=   15*(((-c25-c26)+2*(c13+c15+c16-c19-c20)+3*(-c5-c6+c21+c22)+4*(-c0-c4-c10-c11-c18)+5*(c2+c3)+6*(-c1-c17)+10*(c12)+12*(c9))*X.x*X4.y+
                 (2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X.x*X4.z+
                 ((c19-c20)+2*(c25-c26)+3*(c10-c11+c15-c16-c21+c22)+6*(c2-c3)+7*(-c7+c8)+9*(-c5+c6))*X4.y*X.z+
                 ((-c15-c16)+2*(-c10-c11-c13)+3*(c7+c8)+6*(-c2-c3+c4+c9)+9*(c5+c6)+12*(c1-c14)+16*(-c0))*X4.y+
                 ((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c17+c23+c24)+3*(-c2-c3-c25-c26)+4*(-c5-c6-c9-c21-c22)+5*(c7+c8)+6*(-c4)+8*(-c0+c1)+16*(c12))*X.y*X4.z+
                 (2*(c4-c9-c10-c11-c13-c14+c17+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c2+c3)+7*(c5+c6-c7-c8)+8*(-c1))*X4.z);
    d.y +=   30*(((c1+c4+c5+c6+c7+c8-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(c10+c11-c19-c20-c21-c22)+3*(-c18)+5*(-c9)+7*(c12)+8*(-c0))*X4.x*X.y+
                 ((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X4.x*X.z+
                 ((-c14+c17-c23-c24+c25+c26)+2*(c1-c4-c5-c6+c7+c8)+6*(c9-c12))*X4.x+
                 (2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X3.x*X2.z+
                 ((-c5-c6+c7+c8-c23-c24+c25+c26)+4*(c9-c12))*X3.x+
                 ((c5+c6+c7+c8+c15+c16+c21+c22)+2*(c1+c2+c3+c13-c14+c18+c23+c24)+3*(-c19-c20)+4*(c17-c25-c26)+5*(c10+c11)+6*(c12)+8*(-c0-c9)+10*(-c4))*X2.x*X3.y+
                 ((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X2.x*X.y*X2.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+4*(c15+c16)+5*(-c5-c6-c7-c8-c10-c11)+6*(c12-c13-c14-c17-c18)+8*(-c2-c3)+12*(c9)+18*(c1+c4))*X2.x*X.y+
                 (2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X2.x*X3.z+
                 ((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X2.x*X2.z+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X2.x*X.z+
                 ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X.x*X2.z+
                 ((c2+c3+c21+c22)+2*(-c7-c8+c13-c14+c15+c16+c23+c24)+3*(c5+c6-c25-c26)+4*(c17-c19-c20)+6*(-c4+c10+c11)+8*(-c0+c12)+10*(-c9))*X3.y*X2.z+
                 (2*(c13+c15+c16+c18+c21+c22)+9*(c2+c3+c10+c11)+12*(-c4-c9+c14+c17)+13*(-c5-c6)+14*(-c1)+15*(-c7-c8)+18*(-c12)+40*(c0))*X3.y+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c4)+4*(c13+c18)+5*(-c2-c3)+6*(-c14-c15-c16-c17)+8*(-c1-c9-c10-c11-c12)+12*(c7+c8)+18*(c5+c6))*X.y*X2.z+
                 ((-c13-c15-c16-c18)+6*(c14+c17)+8*(-c2-c3-c10-c11)+10*(c1+c4+c5+c6+c7+c8+c9+c12)+56*(-c0))*X.y+
                 ((-c2+c3+c10-c11-c19+c20)+2*(c7-c8))*X3.z);
    d.y +=   60*(((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X3.x*X.y*X.z+
                 ((-c10-c11+c19+c20+c21+c22)+2*(-c9+c13-c15-c16+c23+c24+c25+c26)+4*(-c1-c4)+6*(-c18)+8*(-c12)+16*(c0))*X3.x*X.y+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X3.x*X.z+
                 ((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X2.x*X.y*X.z+
                 ((c14-c17)+4*(c5+c6-c7-c8)+5*(-c1+c4-c9+c12))*X2.x+
                 ((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X.x*X3.y*X.z+
                 ((-c15-c16)+2*(c5+c6+c7+c8-c13+c18+c21+c22)+3*(c10+c11)+4*(c1)+5*(-c2-c3)+6*(-c9-c17)+8*(-c12)+10*(c4))*X.x*X3.y+
                 (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X.x*X.y*X3.z+
                 ((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X.x*X.y*X2.z+
                 ((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X.x*X.y*X.z+
                 ((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X.x*X3.z+
                 (2*(-c15+c16-c21+c22)+3*(-c10+c11)+5*(-c2+c3+c5-c6)+9*(c7-c8))*X3.y*X.z+
                 ((-c21+c22-c23+c24-c25+c26)+2*(c7-c8-c19+c20)+3*(-c2+c3+c15-c16)+4*(-c5+c6)+6*(c10-c11))*X.y*X3.z+
                 ((c14-c17)+4*(c1-c4+c9-c12)+5*(-c5-c6+c7+c8))*X2.z);
    d.y +=   90*(((c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+2*(c1-c4+c7+c8+c12+c17)+4*(c18)+8*(-c0))*X3.x*X2.y+
                 (2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X2.x*X2.y*X.z+
                 ((-c5-c6-c7-c8-c15-c16+c19+c20-c23-c24+c25+c26)+2*(c9+c14+c21+c22)+4*(-c1+c4-c17)+8*(c0-c12))*X2.x*X2.y+
                 ((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X.x*X2.y*X2.z+
                 ((-c5-c6-c7-c8+c10+c11+c21+c22)+4*(c0-c12))*X.x*X2.y+
                 ((-c15+c16+c19-c20+c21-c22+c23-c24+c25-c26)+2*(c2-c3+c5-c6-c7+c8)+5*(-c10+c11))*X2.y*X3.z+
                 ((c19+c20-c23-c24+c25+c26)+2*(-c7-c8-c13+c14+c21+c22)+4*(-c5-c6+c9-c17)+6*(c4)+8*(c0-c12))*X2.y*X2.z+
                 ((-c2+c3-c21+c22)+2*(c7-c8))*X2.y*X.z);
    d.y +=  120*(((c13-c18)+4*(c2+c3-c10-c11)+5*(-c1-c4+c9+c12))*X.x*X.y+
                 ((c15-c16)+4*(c2-c3+c10-c11)+5*(-c5+c6-c7+c8))*X.y*X.z);
    d.y +=  180*(((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X.x*X2.y*X.z+
                 ((c1-c4+c5+c6-c7-c8+c9-c12)+2*(-c14+c17))*X2.y);
    d.y +=  480*(((c1-c4-c9+c12))*X.x+
                 ((c5-c6-c7+c8))*X.z);

    d.z +=    3*(((c19-c20)+2*(c25-c26)+3*(c10-c11+c15-c16-c21+c22)+6*(c2-c3)+7*(-c7+c8)+9*(-c5+c6))*X5.y);
    d.z +=    6*(((c15-c16)+2*(c5-c6+c7-c8)+3*(-c2+c3-c10+c11))*X5.x+
                 (6*(-c15+c16)+37*(-c2+c3-c5+c6-c7+c8-c10+c11)));
    d.z +=    9*(((c2+c3+c5+c6+c21+c22+c25+c26)+2*(-c4-c9-c15-c16-c17-c18-c19-c20)+6*(c7+c8+c10+c11)+8*(-c0-c12))*X5.z);
    d.z +=   15*(((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X.x*X4.y+
                 ((-c2+c3-c7+c8+c10-c11+c25-c26)+2*(-c5+c6+c21-c22)+3*(c15-c16-c19+c20))*X.x*X4.z+
                 ((c2+c3+c21+c22)+2*(-c7-c8+c13-c14+c15+c16+c23+c24)+3*(c5+c6-c25-c26)+4*(c17-c19-c20)+6*(-c4+c10+c11)+8*(-c0+c12)+10*(-c9))*X4.y*X.z+
                 (2*(-c15+c16-c21+c22)+3*(-c10+c11)+5*(-c2+c3+c5-c6)+9*(c7-c8))*X4.y+
                 ((-c5+c6+c7-c8-c10+c11+c21-c22)+2*(-c2+c3+c25-c26)+3*(c15-c16-c19+c20))*X.y*X4.z);
    d.z +=   30*(((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X4.x*X.y+
                 ((c2+c3+c5+c6+c7+c8+c10+c11-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(-c19-c20-c21-c22)+3*(-c18)+4*(-c9)+8*(-c0+c12))*X4.x*X.z+
                 ((-c15+c16-c23+c24-c25+c26)+2*(c2-c3-c5+c6-c7+c8)+6*(c10-c11))*X4.x+
                 ((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X3.x*X2.y+
                 ((-c5+c6-c7+c8-c23+c24-c25+c26)+4*(c10-c11))*X3.x+
                 (2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X2.x*X3.y+
                 ((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X2.x*X2.y*X.z+
                 ((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X2.x*X2.y+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X2.x*X.y+
                 ((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c18+c23+c24)+3*(-c5-c6-c21-c22)+4*(-c2-c3-c4-c25-c26)+5*(c7+c8)+6*(-c9)+8*(-c0+c1)+16*(c12))*X2.x*X3.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c9)+4*(c14+c17)+5*(-c5-c6-c7-c8)+6*(-c13-c15-c16-c18)+8*(-c1-c4-c12)+9*(c10+c11)+18*(c2+c3))*X2.x*X.z+
                 ((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X.x*X2.y+
                 ((-c2+c3-c21+c22)+2*(c7-c8))*X3.y+
                 ((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c17+c23+c24)+3*(-c2-c3-c25-c26)+4*(-c5-c6-c9-c21-c22)+5*(c7+c8)+6*(-c4)+8*(-c0+c1)+16*(c12))*X2.y*X3.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c4)+4*(c13+c18)+5*(-c2-c3)+6*(-c14-c15-c16-c17)+8*(-c1-c9-c10-c11-c12)+12*(c7+c8)+18*(c5+c6))*X2.y*X.z+
                 (2*(c13+c14+c17+c18+c19+c20)+8*(c1+c12)+10*(c4+c9)+12*(c15+c16)+13*(-c2-c3-c5-c6)+15*(-c7-c8-c10-c11)+40*(c0))*X3.z+
                 ((-c13-c14-c17-c18)+6*(c15+c16)+8*(-c1-c4-c9-c12)+10*(c2+c3+c5+c6+c7+c8+c10+c11)+56*(-c0))*X.z);
    d.z +=   45*(((c2-c3+c5-c6+c7-c8+c10-c11)+2*(-c15+c16))*X4.z);
    d.z +=   60*((2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X3.x*X.y*X.z+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X3.x*X.y+
                 ((c19+c20+c21+c22)+2*(c9+c13-c14-c17+c23+c24+c25+c26)+4*(-c2-c3-c12)+5*(-c10-c11)+6*(-c18)+16*(c0))*X3.x*X.z+
                 ((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X2.x*X.y*X.z+
                 ((c15-c16)+4*(c5-c6+c7-c8)+5*(-c2+c3-c10+c11))*X2.x+
                 ((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X.x*X3.y*X.z+
                 ((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X.x*X3.y+
                 ((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X.x*X2.y*X.z+
                 (2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X.x*X.y*X3.z+
                 ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X.x*X.y*X.z+
                 (2*(-c4-c7-c8+c9-c13-c14+c18+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c5+c6)+7*(c2+c3-c10-c11)+8*(-c1))*X.x*X3.z+
                 ((c19+c20-c23-c24+c25+c26)+2*(-c7-c8-c13+c14+c21+c22)+4*(-c5-c6+c9-c17)+6*(c4)+8*(c0-c12))*X3.y*X.z+
                 ((c15-c16)+4*(c2-c3+c10-c11)+5*(-c5+c6-c7+c8))*X2.y+
                 (2*(c4-c9-c10-c11-c13-c14+c17+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c2+c3)+7*(c5+c6-c7-c8)+8*(-c1))*X.y*X3.z);
    d.z +=   90*(((-c10+c11-c15+c16+c19-c20+c21-c22-c23+c24+c25-c26)+2*(c2-c3+c5-c6)+4*(-c7+c8))*X3.x*X2.z+
                 (2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X2.x*X.y*X2.z+
                 ((-c21+c22-c23+c24-c25+c26)+2*(-c19+c20)+3*(-c5+c6+c7-c8+c15-c16)+4*(-c2+c3)+5*(c10-c11))*X2.x*X2.z+
                 (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X.x*X2.y*X2.z+
                 ((-c5+c6+c7-c8-c19+c20)+2*(c10-c11))*X.x*X2.z+
                 ((-c15+c16+c19-c20+c21-c22+c23-c24+c25-c26)+2*(c2-c3+c5-c6-c7+c8)+5*(-c10+c11))*X3.y*X2.z+
                 ((-c21+c22-c23+c24-c25+c26)+2*(c7-c8-c19+c20)+3*(-c2+c3+c15-c16)+4*(-c5+c6)+6*(c10-c11))*X2.y*X2.z+
                 ((-c2+c3+c10-c11-c19+c20)+2*(c7-c8))*X.y*X2.z);
    d.z +=  120*(((c13-c18)+4*(c1+c4-c9-c12)+5*(-c2-c3+c10+c11))*X.x*X.z+
                 ((c14-c17)+4*(c1-c4+c9-c12)+5*(-c5-c6+c7+c8))*X.y*X.z);
    d.z +=  180*(((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X.x*X.y*X2.z+
                 ((c2-c3+c5-c6+c7-c8+c10-c11)+2*(-c15+c16))*X2.z);
    d.z +=  480*(((c2-c3-c10+c11))*X.x+
                 ((c5-c6-c7+c8))*X.y);
    
    // [dx dy dz]^T_{\pi_n} = R_n*P_n*[dx dy dz]^T_{\pi_0}
    d = R*(P*d)*SCALE_V3_G;
    return d;
}

Hessian eval_Hessian_fccv3(texture3d<float, access::sample> Vol, float3 p_in)
{
    // Find nearest neighbor FCC lattice site
    float3 org = find_fcc_nearest(p_in);
    float3 p_local = p_in - org;    // local coordinates

    // Note that R^{-1} = R.
    float3 R = find_R(p_local);
    p_local = R*p_local;

    // Note that P^{-1} = P^T
    float3x3 P = find_P(p_local);
    p_local = transpose(P)*p_local;
    
    thread float c[27];
    fetch_fccv3_coefficients(c, Vol, org, R, P);

    // Evaluation
    float3 X = p_local;
    float3 X2 = X*X;
    float3 X3 = X2*X;
    float3 X4 = X3*X;

    Hessian H;
    H.dii = float4(0,0,0,1);
    H.dij = float4(0,0,0,1);
    H.dii.x += 3*(((c5+c6+c7+c8+c15+c16+c21+c22)+2*(c1+c2+c3+c13-c14+c18+c23+c24)+3*(-c19-c20)+4*(c17-c25-c26)+5*(c10+c11)+6*(c12)+8*(-c0-c9)+10*(-c4))*X4.y);
    H.dii.x += 3*(((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c18+c23+c24)+3*(-c5-c6-c21-c22)+4*(-c2-c3-c4-c25-c26)+5*(c7+c8)+6*(-c9)+8*(-c0+c1)+16*(c12))*X4.z);
    H.dii.x += 6*(((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X2.y*X2.z);
    H.dii.x += 6*(((c19+c20+c21+c22+c23+c24+c25+c26)+4*(c15+c16)+5*(-c5-c6-c7-c8-c10-c11)+6*(c12-c13-c14-c17-c18)+8*(-c2-c3)+12*(c9)+18*(c1+c4))*X2.y);
    H.dii.x += 6*(((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c9)+4*(c14+c17)+5*(-c5-c6-c7-c8)+6*(-c13-c15-c16-c18)+8*(-c1-c4-c12)+9*(c10+c11)+18*(c2+c3))*X2.z);
    H.dii.x += 6*(((-c14-c15-c16-c17)+6*(c13+c18)+8*(-c5-c6-c7-c8)+10*(c1+c2+c3+c4+c9+c10+c11+c12)+56*(-c0)));
    H.dii.x += 12*((2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X3.y*X.z);
    H.dii.x += 12*(((-c5-c6-c7-c8-c15-c16+c19+c20-c23-c24+c25+c26)+2*(c9+c14+c21+c22)+4*(-c1+c4-c17)+8*(c0-c12))*X3.y);
    H.dii.x += 12*(((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X2.y*X.z);
    H.dii.x += 12*((2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X.y*X3.z);
    H.dii.x += 12*(((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X.y*X2.z);
    H.dii.x += 12*(((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X.y*X.z);
    H.dii.x += 12*(((-c21+c22-c23+c24-c25+c26)+2*(-c19+c20)+3*(-c5+c6+c7-c8+c15-c16)+4*(-c2+c3)+5*(c10-c11))*X3.z);
    H.dii.x +=   18*(((-c1-c2-c3-c4+c9+c10+c11+c12)+2*(c13-c18))*X4.x);
    H.dii.x +=   24*(((c14-c17)+2*(c5+c6-c7-c8)+3*(-c1+c4-c9+c12))*X3.x*X.y);
    H.dii.x +=   24*(((c15-c16)+2*(c5-c6+c7-c8)+3*(-c2+c3-c10+c11))*X3.x*X.z);
    H.dii.x +=   24*(((-c14-c15-c16-c17)+4*(-c5-c6-c7-c8)+6*(c1+c2+c3+c4+c9+c10+c11+c12-c13-c18)+16*(-c0))*X3.x);
    H.dii.x +=   24*(((c14-c17)+4*(c5+c6-c7-c8)+5*(-c1+c4-c9+c12))*X.y);
    H.dii.x +=   24*(((c15-c16)+4*(c5-c6+c7-c8)+5*(-c2+c3-c10+c11))*X.z);
    H.dii.x +=   36*(((c1+c4+c5+c6+c7+c8-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(c10+c11-c19-c20-c21-c22)+3*(-c18)+5*(-c9)+7*(c12)+8*(-c0))*X2.x*X2.y);
    H.dii.x +=   36*(((c2+c3+c5+c6+c7+c8+c10+c11-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(-c19-c20-c21-c22)+3*(-c18)+4*(-c9)+8*(-c0+c12))*X2.x*X2.z);
    H.dii.x +=   36*(((c14+c15+c16+c17+c23+c24+c25+c26)+5*(c5+c6+c7+c8)+6*(c13+c18)+7*(-c1-c2-c3-c4)+9*(-c9-c10-c11-c12)+24*(c0))*X2.x);
    H.dii.x +=   36*(((c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+2*(c1-c4+c7+c8+c12+c17)+4*(c18)+8*(-c0))*X.x*X3.y);
    H.dii.x +=   36*(((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X.x*X2.y*X.z);
    H.dii.x +=   36*(((-c10-c11+c19+c20+c21+c22)+2*(-c9+c13-c15-c16+c23+c24+c25+c26)+4*(-c1-c4)+6*(-c18)+8*(-c12)+16*(c0))*X.x*X2.y);
    H.dii.x +=   36*((2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X.x*X.y*X2.z);
    H.dii.x +=   36*(((-c5-c6+c7+c8-c23-c24+c25+c26)+4*(c9-c12))*X.x*X.y);
    H.dii.x +=   36*(((-c10+c11-c15+c16+c19-c20+c21-c22-c23+c24+c25-c26)+2*(c2-c3+c5-c6)+4*(-c7+c8))*X.x*X3.z);
    H.dii.x +=   36*(((c19+c20+c21+c22)+2*(c9+c13-c14-c17+c23+c24+c25+c26)+4*(-c2-c3-c12)+5*(-c10-c11)+6*(-c18)+16*(c0))*X.x*X2.z);
    H.dii.x +=   36*(((-c5+c6-c7+c8-c23+c24-c25+c26)+4*(c10-c11))*X.x*X.z);
    H.dii.x +=   72*(((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X2.x*X.y*X.z);
    H.dii.x +=   72*(((-c14+c17-c23-c24+c25+c26)+2*(c1-c4-c5-c6+c7+c8)+6*(c9-c12))*X2.x*X.y);
    H.dii.x +=   72*(((-c15+c16-c23+c24-c25+c26)+2*(c2-c3-c5+c6-c7+c8)+6*(c10-c11))*X2.x*X.z);
    H.dii.x +=   72*(((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X.x*X.y*X.z);
    H.dii.x +=   72*(((c1+c2+c3+c4-c9-c10-c11-c12)+2*(-c13+c18))*X.x);
    H.dii.y +=    3*(((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c17+c23+c24)+3*(-c2-c3-c25-c26)+4*(-c5-c6-c9-c21-c22)+5*(c7+c8)+6*(-c4)+8*(-c0+c1)+16*(c12))*X4.z);
    H.dii.y +=    6*(((c1+c4+c5+c6+c7+c8-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(c10+c11-c19-c20-c21-c22)+3*(-c18)+5*(-c9)+7*(c12)+8*(-c0))*X4.x);
    H.dii.y +=    6*(((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X2.x*X2.z);
    H.dii.y +=    6*(((c19+c20+c21+c22+c23+c24+c25+c26)+4*(c15+c16)+5*(-c5-c6-c7-c8-c10-c11)+6*(c12-c13-c14-c17-c18)+8*(-c2-c3)+12*(c9)+18*(c1+c4))*X2.x);
    H.dii.y +=    6*(((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c4)+4*(c13+c18)+5*(-c2-c3)+6*(-c14-c15-c16-c17)+8*(-c1-c9-c10-c11-c12)+12*(c7+c8)+18*(c5+c6))*X2.z);
    H.dii.y +=    6*(((-c13-c15-c16-c18)+6*(c14+c17)+8*(-c2-c3-c10-c11)+10*(c1+c4+c5+c6+c7+c8+c9+c12)+56*(-c0)));
    H.dii.y +=    9*(((-c2-c3-c15-c16+c19+c20+c25+c26)+2*(-c1+c9-c18-c21-c22)+4*(c4+c14)+5*(-c10-c11)+7*(c7+c8)+8*(-c0-c17)+10*(c12))*X4.y);
    H.dii.y +=   12*(((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X3.x*X.z);
    H.dii.y +=   12*(((-c10-c11+c19+c20+c21+c22)+2*(-c9+c13-c15-c16+c23+c24+c25+c26)+4*(-c1-c4)+6*(-c18)+8*(-c12)+16*(c0))*X3.x);
    H.dii.y +=   12* (((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X2.x*X.z);
    H.dii.y +=   12*(((-c25-c26)+2*(c13+c15+c16-c19-c20)+3*(-c5-c6+c21+c22)+4*(-c0-c4-c10-c11-c18)+5*(c2+c3)+6*(-c1-c17)+10*(c12)+12*(c9))*X.x*X3.y);
    H.dii.y +=   12*( (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X.x*X3.z);
    H.dii.y +=   12*(((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X.x*X2.z);
    H.dii.y +=   12*(((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X.x*X.z);
    H.dii.y +=   12*(((c19-c20)+2*(c25-c26)+3*(c10-c11+c15-c16-c21+c22)+6*(c2-c3)+7*(-c7+c8)+9*(-c5+c6))*X3.y*X.z);
    H.dii.y +=   12*(((-c15-c16)+2*(-c10-c11-c13)+3*(c7+c8)+6*(-c2-c3+c4+c9)+9*(c5+c6)+12*(c1-c14)+16*(-c0))*X3.y);
    H.dii.y +=   12*(((-c21+c22-c23+c24-c25+c26)+2*(c7-c8-c19+c20)+3*(-c2+c3+c15-c16)+4*(-c5+c6)+6*(c10-c11))*X3.z);

    H.dii.y +=   18*(((c5+c6+c7+c8+c15+c16+c21+c22)+2*(c1+c2+c3+c13-c14+c18+c23+c24)+3*(-c19-c20)+4*(c17-c25-c26)+5*(c10+c11)+6*(c12)+8*(-c0-c9)+10*(-c4))*X2.x*X2.y);
    H.dii.y +=   18*(((c2+c3+c21+c22)+2*(-c7-c8+c13-c14+c15+c16+c23+c24)+3*(c5+c6-c25-c26)+4*(c17-c19-c20)+6*(-c4+c10+c11)+8*(-c0+c12)+10*(-c9))*X2.y*X2.z);
    H.dii.y +=   18*((2*(c13+c15+c16+c18+c21+c22)+9*(c2+c3+c10+c11)+12*(-c4-c9+c14+c17)+13*(-c5-c6)+14*(-c1)+15*(-c7-c8)+18*(-c12)+40*(c0))*X2.y);
    H.dii.y +=   24*(((c13-c18)+4*(c2+c3-c10-c11)+5*(-c1-c4+c9+c12))*X.x);
    H.dii.y +=   24*(((c15-c16)+4*(c2-c3+c10-c11)+5*(-c5+c6-c7+c8))*X.z);

    H.dii.y +=   36*(((c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+2*(c1-c4+c7+c8+c12+c17)+4*(c18)+8*(-c0))*X3.x*X.y);
    H.dii.y +=   36*((2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X2.x*X.y*X.z);
    H.dii.y +=   36*(((-c5-c6-c7-c8-c15-c16+c19+c20-c23-c24+c25+c26)+2*(c9+c14+c21+c22)+4*(-c1+c4-c17)+8*(c0-c12))*X2.x*X.y);
    H.dii.y +=   36*(((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X.x*X2.y*X.z);
    H.dii.y +=   36*(((-c15-c16)+2*(c5+c6+c7+c8-c13+c18+c21+c22)+3*(c10+c11)+4*(c1)+5*(-c2-c3)+6*(-c9-c17)+8*(-c12)+10*(c4))*X.x*X2.y);
    H.dii.y +=   36*(((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X.x*X.y*X2.z);
    H.dii.y +=   36*(((-c5-c6-c7-c8+c10+c11+c21+c22)+4*(c0-c12))*X.x*X.y);
    H.dii.y +=   36*( (2*(-c15+c16-c21+c22)+3*(-c10+c11)+5*(-c2+c3+c5-c6)+9*(c7-c8))*X2.y*X.z);
    H.dii.y +=   36*( ((-c15+c16+c19-c20+c21-c22+c23-c24+c25-c26)+2*(c2-c3+c5-c6-c7+c8)+5*(-c10+c11))*X.y*X3.z);
    H.dii.y +=   36*( ((c19+c20-c23-c24+c25+c26)+2*(-c7-c8-c13+c14+c21+c22)+4*(-c5-c6+c9-c17)+6*(c4)+8*(c0-c12))*X.y*X2.z);
    H.dii.y +=   36*( ((-c2+c3-c21+c22)+2*(c7-c8))*X.y*X.z);
    H.dii.y +=   72*(((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X.x*X.y*X.z);
    H.dii.y +=   72*(((c1-c4+c5+c6-c7-c8+c9-c12)+2*(-c14+c17))*X.y);

    H.dii.z +=    3*(((c2+c3+c21+c22)+2*(-c7-c8+c13-c14+c15+c16+c23+c24)+3*(c5+c6-c25-c26)+4*(c17-c19-c20)+6*(-c4+c10+c11)+8*(-c0+c12)+10*(-c9))*X4.y);
    H.dii.z +=    6*(((c2+c3+c5+c6+c7+c8+c10+c11-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(-c19-c20-c21-c22)+3*(-c18)+4*(-c9)+8*(-c0+c12))*X4.x);
    H.dii.z +=    6*(((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X2.x*X2.y);
    H.dii.z +=    6*(((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c9)+4*(c14+c17)+5*(-c5-c6-c7-c8)+6*(-c13-c15-c16-c18)+8*(-c1-c4-c12)+9*(c10+c11)+18*(c2+c3))*X2.x);
    H.dii.z +=    6*( ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c4)+4*(c13+c18)+5*(-c2-c3)+6*(-c14-c15-c16-c17)+8*(-c1-c9-c10-c11-c12)+12*(c7+c8)+18*(c5+c6))*X2.y);
    H.dii.z +=    6*(((-c13-c14-c17-c18)+6*(c15+c16)+8*(-c1-c4-c9-c12)+10*(c2+c3+c5+c6+c7+c8+c10+c11)+56*(-c0)));


    H.dii.z +=    9*(((c2+c3+c5+c6+c21+c22+c25+c26)+2*(-c4-c9-c15-c16-c17-c18-c19-c20)+6*(c7+c8+c10+c11)+8*(-c0-c12))*X4.z);
    H.dii.z +=   12*((2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X3.x*X.y);
    H.dii.z +=   12*(((c19+c20+c21+c22)+2*(c9+c13-c14-c17+c23+c24+c25+c26)+4*(-c2-c3-c12)+5*(-c10-c11)+6*(-c18)+16*(c0))*X3.x);
    H.dii.z +=   12*(((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X2.x*X.y);
    H.dii.z +=   12*( ((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X.x*X3.y);
    H.dii.z +=   12*(((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X.x*X2.y);
    H.dii.z +=   12*( ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X.x*X.y);
    H.dii.z +=   12*( ((-c2+c3-c7+c8+c10-c11+c25-c26)+2*(-c5+c6+c21-c22)+3*(c15-c16-c19+c20))*X.x*X3.z);
    H.dii.z +=   12*(((c19+c20-c23-c24+c25+c26)+2*(-c7-c8-c13+c14+c21+c22)+4*(-c5-c6+c9-c17)+6*(c4)+8*(c0-c12))*X3.y);
    H.dii.z +=   12*( ((-c5+c6+c7-c8-c10+c11+c21-c22)+2*(-c2+c3+c25-c26)+3*(c15-c16-c19+c20))*X.y*X3.z);
    H.dii.z +=   18*(((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c18+c23+c24)+3*(-c5-c6-c21-c22)+4*(-c2-c3-c4-c25-c26)+5*(c7+c8)+6*(-c9)+8*(-c0+c1)+16*(c12))*X2.x*X2.z);
    H.dii.z +=   18*(((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c17+c23+c24)+3*(-c2-c3-c25-c26)+4*(-c5-c6-c9-c21-c22)+5*(c7+c8)+6*(-c4)+8*(-c0+c1)+16*(c12))*X2.y*X2.z);
    H.dii.z +=   18*((2*(c13+c14+c17+c18+c19+c20)+8*(c1+c12)+10*(c4+c9)+12*(c15+c16)+13*(-c2-c3-c5-c6)+15*(-c7-c8-c10-c11)+40*(c0))*X2.z);


    H.dii.z +=   24*(((c13-c18)+4*(c1+c4-c9-c12)+5*(-c2-c3+c10+c11))*X.x);
    H.dii.z +=   24*(((c14-c17)+4*(c1-c4+c9-c12)+5*(-c5-c6+c7+c8))*X.y);
    H.dii.z +=   36*(((-c10+c11-c15+c16+c19-c20+c21-c22-c23+c24+c25-c26)+2*(c2-c3+c5-c6)+4*(-c7+c8))*X3.x*X.z);
    H.dii.z +=   36*((2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X2.x*X.y*X.z);
    H.dii.z +=   36*(((-c21+c22-c23+c24-c25+c26)+2*(-c19+c20)+3*(-c5+c6+c7-c8+c15-c16)+4*(-c2+c3)+5*(c10-c11))*X2.x*X.z);
    H.dii.z +=   36*((2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X.x*X2.y*X.z);
    H.dii.z +=   36*((2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X.x*X.y*X2.z);
    H.dii.z +=   36*((2*(-c4-c7-c8+c9-c13-c14+c18+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c5+c6)+7*(c2+c3-c10-c11)+8*(-c1))*X.x*X2.z);
    H.dii.z +=   36*(((-c5+c6+c7-c8-c19+c20)+2*(c10-c11))*X.x*X.z);
    H.dii.z +=   36*(((-c15+c16+c19-c20+c21-c22+c23-c24+c25-c26)+2*(c2-c3+c5-c6-c7+c8)+5*(-c10+c11))*X3.y*X.z);
    H.dii.z +=   36*(((-c21+c22-c23+c24-c25+c26)+2*(c7-c8-c19+c20)+3*(-c2+c3+c15-c16)+4*(-c5+c6)+6*(c10-c11))*X2.y*X.z);
    H.dii.z +=   36*((2*(c4-c9-c10-c11-c13-c14+c17+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c2+c3)+7*(c5+c6-c7-c8)+8*(-c1))*X.y*X2.z);
    H.dii.z +=   36*(((-c2+c3+c10-c11-c19+c20)+2*(c7-c8))*X.y*X.z);
    H.dii.z +=   36*(((c2-c3+c5-c6+c7-c8+c10-c11)+2*(-c15+c16))*X3.z);
    H.dii.z +=   72*(((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X.x*X.y*X.z);
    H.dii.z +=   72*(((c2-c3+c5-c6+c7-c8+c10-c11)+2*(-c15+c16))*X.z);

    H.dij.x +=    3*(((c19-c20)+2*(c25-c26)+3*(c10-c11+c15-c16-c21+c22)+6*(c2-c3)+7*(-c7+c8)+9*(-c5+c6))*X4.y+
                 ((-c5+c6+c7-c8-c10+c11+c21-c22)+2*(-c2+c3+c25-c26)+3*(c15-c16-c19+c20))*X4.z);
    H.dij.x +=    6*(((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X4.x+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X2.x);
    H.dij.x +=   12*(((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X3.x*X.y+
                 (2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X3.x*X.z+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X3.x+
                 ((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X2.x*X.y*X.z+
                 ((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X2.x*X.y+
                 ((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X2.x*X.z+
                 ((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X.x*X3.y+
                 ((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X.x*X.y+
                 (2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X.x*X3.z+
                 ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X.x*X.z+
                 ((c2+c3+c21+c22)+2*(-c7-c8+c13-c14+c15+c16+c23+c24)+3*(c5+c6-c25-c26)+4*(c17-c19-c20)+6*(-c4+c10+c11)+8*(-c0+c12)+10*(-c9))*X3.y*X.z+
                 (2*(-c15+c16-c21+c22)+3*(-c10+c11)+5*(-c2+c3+c5-c6)+9*(c7-c8))*X3.y+
                 ((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c17+c23+c24)+3*(-c2-c3-c25-c26)+4*(-c5-c6-c9-c21-c22)+5*(c7+c8)+6*(-c4)+8*(-c0+c1)+16*(c12))*X.y*X3.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c4)+4*(c13+c18)+5*(-c2-c3)+6*(-c14-c15-c16-c17)+8*(-c1-c9-c10-c11-c12)+12*(c7+c8)+18*(c5+c6))*X.y*X.z+
                 (2*(c4-c9-c10-c11-c13-c14+c17+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c2+c3)+7*(c5+c6-c7-c8)+8*(-c1))*X3.z);
    H.dij.x +=   18*((2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X2.x*X2.y+
                 (2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X2.x*X2.z+
                 ((-c2+c3-c21+c22)+2*(c7-c8))*X2.y+
                 ((-c2+c3+c10-c11-c19+c20)+2*(c7-c8))*X2.z);
    H.dij.x +=   24*(((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X.x*X.y*X.z+
                 ((c15-c16)+4*(c2-c3+c10-c11)+5*(-c5+c6-c7+c8))*X.y+
                 ((c14-c17)+4*(c1-c4+c9-c12)+5*(-c5-c6+c7+c8))*X.z);
    H.dij.x +=   36*(((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X.x*X2.y*X.z+
                 ((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X.x*X2.y+
                 (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X.x*X.y*X2.z+
                 ((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X.x*X2.z+
                 ((c19+c20-c23-c24+c25+c26)+2*(-c7-c8-c13+c14+c21+c22)+4*(-c5-c6+c9-c17)+6*(c4)+8*(c0-c12))*X2.y*X.z+
                 ((-c21+c22-c23+c24-c25+c26)+2*(c7-c8-c19+c20)+3*(-c2+c3+c15-c16)+4*(-c5+c6)+6*(c10-c11))*X.y*X2.z);
    H.dij.x +=   54*(((-c15+c16+c19-c20+c21-c22+c23-c24+c25-c26)+2*(c2-c3+c5-c6-c7+c8)+5*(-c10+c11))*X2.y*X2.z);
    H.dij.x +=   96*(((c5-c6-c7+c8)));

    H.dij.y +=    3*(((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X4.y+
                 ((-c2+c3-c7+c8+c10-c11+c25-c26)+2*(-c5+c6+c21-c22)+3*(c15-c16-c19+c20))*X4.z);
    H.dij.y +=    6*(((c15-c16)+2*(c5-c6+c7-c8)+3*(-c2+c3-c10+c11))*X4.x+
                 ((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X2.y);
    H.dij.y +=   12*((2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X.x*X3.y+
                 ((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X.x*X2.y*X.z+
                 ((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X.x*X2.y+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X.x*X.y+
                 ((-c10-c11+c15+c16+c19+c20)+2*(c13+c14+c18+c23+c24)+3*(-c5-c6-c21-c22)+4*(-c2-c3-c4-c25-c26)+5*(c7+c8)+6*(-c9)+8*(-c0+c1)+16*(c12))*X.x*X3.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+2*(-c9)+4*(c14+c17)+5*(-c5-c6-c7-c8)+6*(-c13-c15-c16-c18)+8*(-c1-c4-c12)+9*(c10+c11)+18*(c2+c3))*X.x*X.z+
                 ((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X3.y*X.z+
                 ((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X3.y+
                 ((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X2.y*X.z+
                 (2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X.y*X3.z+
                 ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X.y*X.z+
                 (2*(-c4-c7-c8+c9-c13-c14+c18+c19+c20)+3*(-c15-c16)+4*(c12)+6*(c5+c6)+7*(c2+c3-c10-c11)+8*(-c1))*X3.z);
    H.dij.y +=   18*(((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X2.x*X2.y+
                 ((-c5+c6-c7+c8-c23+c24-c25+c26)+4*(c10-c11))*X2.x+
                 (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X2.y*X2.z+
                 ((-c5+c6+c7-c8-c19+c20)+2*(c10-c11))*X2.z);
    H.dij.y +=   24*(((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X3.x*X.y+
                 ((c2+c3+c5+c6+c7+c8+c10+c11-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(-c19-c20-c21-c22)+3*(-c18)+4*(-c9)+8*(-c0+c12))*X3.x*X.z+
                 ((-c15+c16-c23+c24-c25+c26)+2*(c2-c3-c5+c6-c7+c8)+6*(c10-c11))*X3.x+
                 ((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X.x*X.y*X.z+
                 ((c15-c16)+4*(c5-c6+c7-c8)+5*(-c2+c3-c10+c11))*X.x+
                 ((c13-c18)+4*(c1+c4-c9-c12)+5*(-c2-c3+c10+c11))*X.z);
    H.dij.y +=   36*((2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X2.x*X.y*X.z+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X2.x*X.y+
                 ((c19+c20+c21+c22)+2*(c9+c13-c14-c17+c23+c24+c25+c26)+4*(-c2-c3-c12)+5*(-c10-c11)+6*(-c18)+16*(c0))*X2.x*X.z+
                 (2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X.x*X.y*X2.z+
                 ((-c21+c22-c23+c24-c25+c26)+2*(-c19+c20)+3*(-c5+c6+c7-c8+c15-c16)+4*(-c2+c3)+5*(c10-c11))*X.x*X2.z+
                 ((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X.y*X2.z);
    H.dij.y +=   54*(((-c10+c11-c15+c16+c19-c20+c21-c22-c23+c24+c25-c26)+2*(c2-c3+c5-c6)+4*(-c7+c8))*X2.x*X2.z);
    H.dij.y +=   96*(((c2-c3-c10+c11)));

    H.dij.z +=    3*(((-c25-c26)+2*(c13+c15+c16-c19-c20)+3*(-c5-c6+c21+c22)+4*(-c0-c4-c10-c11-c18)+5*(c2+c3)+6*(-c1-c17)+10*(c12)+12*(c9))*X4.y+
                 (2*(-c4-c9+c13+c14-c23-c24)+3*(-c2-c3-c5-c6-c21-c22-c25-c26)+4*(c7+c8+c12+c17+c18)+8*(c1)+10*(c10+c11)+20*(-c0))*X4.z);
    H.dij.z +=    6*(((c14-c17)+2*(c5+c6-c7-c8)+3*(-c1+c4-c9+c12))*X4.x+
                 ((c21+c22-c23-c24+c25+c26)+2*(c19+c20)+3*(-c10-c11)+4*(-c1+c4+c9-c12)+6*(-c7-c8)+12*(c0))*X2.z);
    H.dij.z +=   12*(((c5+c6+c7+c8+c15+c16+c21+c22)+2*(c1+c2+c3+c13-c14+c18+c23+c24)+3*(-c19-c20)+4*(c17-c25-c26)+5*(c10+c11)+6*(c12)+8*(-c0-c9)+10*(-c4))*X.x*X3.y+
                 ((c5+c6)+2*(-c2-c3)+4*(c13+c14)+7*(c15+c16)+8*(-c18-c25-c26)+10*(c17+c23+c24)+11*(-c19-c20-c21-c22)+13*(c7+c8+c10+c11)+16*(c1)+20*(-c4)+38*(-c9)+56*(-c0)+64*(c12))*X.x*X.y*X2.z+
                 ((c19+c20+c21+c22+c23+c24+c25+c26)+4*(c15+c16)+5*(-c5-c6-c7-c8-c10-c11)+6*(c12-c13-c14-c17-c18)+8*(-c2-c3)+12*(c9)+18*(c1+c4))*X.x*X.y+
                 (2*(-c15+c16+c19-c20)+3*(c23-c24+c25-c26)+4*(c21-c22)+5*(c5-c6)+6*(c2-c3)+7*(-c7+c8)+14*(-c10+c11))*X.x*X3.z+
                 ((c5+c6)+2*(-c17)+3*(-c15-c16)+4*(-c14+c21+c22)+5*(c19+c20-c23-c24+c25+c26)+6*(-c10-c11)+7*(-c7-c8)+8*(-c1+c4)+22*(c9)+24*(c0)+28*(-c12))*X.x*X2.z+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X.x*X.z+
                 ((-c15+c16)+2*(c5-c6-c23+c24)+3*(-c10+c11+c19-c20+c25-c26)+5*(c2-c3)+9*(-c7+c8))*X3.y*X.z+
                 ((-c15-c16)+2*(c5+c6+c7+c8-c13+c18+c21+c22)+3*(c10+c11)+4*(c1)+5*(-c2-c3)+6*(-c9-c17)+8*(-c12)+10*(c4))*X3.y+
                 (2*(-c15+c16+c19-c20)+3*(c21-c22-c23+c24)+4*(-c10+c11+c25-c26)+5*(c2-c3)+6*(c5-c6)+11*(-c7+c8))*X.y*X3.z+
                 ((c2+c3)+3*(-c15-c16)+4*(-c9-c13+c23+c24+c25+c26)+5*(c19+c20+c21+c22)+6*(-c17)+8*(-c1-c18)+10*(c4-c10-c11)+12*(-c7-c8)+16*(-c12)+48*(c0))*X.y*X2.z+
                 ((-c19+c20-c23+c24-c25+c26)+2*(-c21+c22)+4*(-c2+c3+c10-c11)+6*(c7-c8))*X.y*X.z+
                 ((-c21+c22+c23-c24-c25+c26)+2*(c10-c11+c15-c16-c19+c20)+3*(-c2+c3-c5+c6)+5*(c7-c8))*X3.z);
    H.dij.z +=   18*((2*(-c9+c14)+3*(c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+4*(c1-c4+c17)+6*(c7+c8)+8*(c12)+12*(c18)+24*(-c0))*X2.x*X2.z+
                 ((-c5-c6+c7+c8-c23-c24+c25+c26)+4*(c9-c12))*X2.x+
                 ((c2+c3-c5-c6)+2*(c13-c21-c22)+3*(c15+c16-c19-c20-c23-c24)+4*(c1+c7+c8+c9+c17-c25-c26)+5*(c10+c11)+6*(-c4)+8*(c18)+12*(c12)+28*(-c0))*X2.y*X2.z+
                 ((-c5-c6-c7-c8+c10+c11+c21+c22)+4*(c0-c12))*X2.y);
    H.dij.z +=   24*(((c1+c4+c5+c6+c7+c8-c13+c14+c15+c16+c17+c23+c24+c25+c26)+2*(c10+c11-c19-c20-c21-c22)+3*(-c18)+5*(-c9)+7*(c12)+8*(-c0))*X3.x*X.y+
                 ((c23-c24-c25+c26)+2*(c19-c20+c21-c22)+3*(c5-c6-c7+c8)+6*(-c10+c11))*X3.x*X.z+
                 ((-c14+c17-c23-c24+c25+c26)+2*(c1-c4-c5-c6+c7+c8)+6*(c9-c12))*X3.x+
                 ((-c15+c16)+4*(-c19+c20)+5*(-c5+c6-c21+c22-c23+c24-c25+c26)+8*(-c2+c3)+13*(c7-c8)+25*(c10-c11))*X.x*X.y*X.z+
                 ((c14-c17)+4*(c5+c6-c7-c8)+5*(-c1+c4-c9+c12))*X.x+
                 ((c13-c18)+4*(c2+c3-c10-c11)+5*(-c1-c4+c9+c12))*X.y);
    H.dij.z +=   36*(((-c15+c16)+3*(c19-c20+c21-c22-c23+c24+c25-c26)+4*(c2-c3)+5*(-c10+c11)+6*(c5-c6)+12*(-c7+c8))*X2.x*X.y*X.z+
                 ((-c10-c11+c19+c20+c21+c22)+2*(-c9+c13-c15-c16+c23+c24+c25+c26)+4*(-c1-c4)+6*(-c18)+8*(-c12)+16*(c0))*X2.x*X.y+
                 ((-c19+c20-c21+c22)+2*(c23-c24-c25+c26)+3*(c10-c11)+4*(-c5+c6+c7-c8))*X2.x*X.z+
                 (2*(c21-c22)+3*(c5-c6+c23-c24+c25-c26)+4*(c19-c20)+6*(c2-c3)+9*(-c7+c8)+16*(-c10+c11))*X.x*X2.y*X.z+
                 ((-c5-c6-c7-c8-c15-c16+c19+c20-c23-c24+c25+c26)+2*(c9+c14+c21+c22)+4*(-c1+c4-c17)+8*(c0-c12))*X.x*X2.y+
                 ((-c5+c6+c10-c11-c19+c20+c23-c24-c25+c26)+2*(-c21+c22)+3*(-c2+c3)+7*(c7-c8))*X2.y*X.z);
    H.dij.z +=   54*(((c10+c11+c15+c16-c19-c20-c21-c22-c23-c24-c25-c26)+2*(c1-c4+c7+c8+c12+c17)+4*(c18)+8*(-c0))*X2.x*X2.y);
    H.dij.z +=   96*(((c1-c4-c9+c12)));
    
    H.dii.xyz = P*H.dii.xyz*SCALE_V3_H;
    H.dij.xyz = R*(P*H.dij.xyz)*SCALE_V3_H;
    
    return H;
}
