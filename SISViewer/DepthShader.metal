//
//  DepthShader.metal
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/23.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


struct VertexIn{
    packed_float3 position;
    packed_float2 texcoord;
};

struct VertexOut{
    float4 position [[position]];
    float2 texcoord;
    float3 pos_n;
    float2 xAxis;
    float2 v2;
    int flag;
};

struct Uniforms{
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
};

typedef struct {
    float3x3 matrix;
    float3 offset;
} ColorConversion;

constant float halfpi = 1.5707963267;
constant float pi = 3.14159265;
constant float twopi = 6.28318531;
//float l = log(64);
//constant float l = 4.15888308;

float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    float4 p = mix(float4(c[2],c[1], K[3],K[2]),
                   float4(c[1],c[2], K[0],K[1]),
                   step(c[2],c[1]));
    float4 q = mix(float4(p[0],p[1],p[3], c[0]),
                   float4(c[0], p[1],p[2],p[0]),
                   step(p[0],c[0]));
    float d = q[0] - min(q[3], q[1]);
    float e = 0.0000000001;
    return float3(abs(q[2] + (q[3]-q[1]) / (6.0 * d + e)), d / (q[0] + e), q[0]);
}

float getDepth(float2 tCoord, texture2d<float, access::sample> textureRGB) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float xc = tCoord[0];
    float yc = tCoord[1] + 0.5;
    
    //float4 rd0 = textureRGB.read(float2(xc+0.001, yc));
    
    float4 rd0 = textureRGB.sample(s, float2(xc, yc));
    float4 rd1 = textureRGB.sample(s, float2(xc+0.001, yc));
    float4 rd2 = textureRGB.sample(s, float2(xc-0.001, yc));
    
    float3 h0 = rgb2hsv(float3(rd0[2], rd0[1], rd0[0]));
    float3 h1 = rgb2hsv(float3(rd1[2], rd1[1], rd1[0]));
    float3 h2 = rgb2hsv(float3(rd2[2], rd2[1], rd2[0]));
    
    float h =  (h0[0] + h1[0] + h2[0]) / 3.0;
    
    float half_pi = 1.5707963267;
    
    float t1 = asin(pow(h, 2.0)) / halfpi * 64.0;
    t1 = t1 + 0.128;
    return t1;
}

/*
float float2Cross(float2 v1, float2 v2) {
    float cros = v1[0]*v2[1] - v1[1]*v2[0];
    return cros;
}*/

float checkCollision(float2 p2, float2 v1, float2 v2) {
    //float2 p1 = float2(0.0, 0.0);
    //float2 v0 = p2 - p1;
    //float c_v1v2 = float2Cross(v1, v2);
    float c_v1v2 = v1[0]*v2[1] - v1[1]*v2[0];
    if(c_v1v2 == 0.0) {
        return -1.0;
    }
    
    //float c_v0v1 = float2Cross(v0, v1);
    //float c_v0v2 = float2Cross(v0, v2);
    float c_v0v1 = p2[0]*v1[1] - p2[1]*v1[0];
    float c_v0v2 = p2[0]*v2[1] - p2[1]*v2[0];
    
    float t1 = c_v0v2 / c_v1v2;
    float t2 = c_v0v1 / c_v1v2;
    
    if(t1 < 0.0 || t1 > 1.0 || t2 < 0.0 || t2 > 1.0) {
        return -1.0;
    }
    
    return t2;
}

vertex VertexOut vertex_depth_shader(
                               const device VertexIn* vertex_array [[ buffer(0) ]],
                               const device Uniforms&  uniforms    [[ buffer(1) ]],
                               const device float4&  view          [[ buffer(2) ]],
                               unsigned int vid [[ vertex_id ]],
                               texture2d<float, access::sample> textureRGB [[texture(0)]]
                               ){
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    float4x4 mv_Matrix = uniforms.modelMatrix;
    float4x4 proj_Matrix = uniforms.projectionMatrix;
    VertexIn vIn = vertex_array[vid];
    
    float4 viewRect = view;
    VertexOut vOut;
    
    float2 tc = vIn.texcoord;
    //tc[1] = 1.0 - tc[1];
    ///tc[0] = (tc[0] * 0.5);
    tc[1] = (1.0 - tc[1])*0.5;
    
    float4 pos = proj_Matrix * mv_Matrix * float4(vIn.position,1.0);
    float2 xAxis = float2(cos(viewRect[2]), sin(viewRect[2])); // viewRect[2] is roll;
    
    //view flags 0=no stereo, 1=left eye, 2=right eye
    vOut.flag = 0;
    
    if(viewRect[3] > 0.0) {
        vOut.flag = viewRect[0] < 0.0 ? 1:2;
        
        pos[0] = (pos[0] / pos[3]) + viewRect[0]; //left = pos[0]-0.5, right pos[0]+0.5
        vOut.pos_n[0] = pos[0]; //pos_n[0] = display position
        pos[0] = pos[0] * pos[3];
        
        vOut.xAxis = xAxis;
    }
    vOut.pos_n[1] = 1.0 - vIn.texcoord[0]; //0-1 normalized horizontal radians of spherical
    float weight = pow(cos(abs(vOut.pos_n[0])*pi*0.4), 4.0);
    vOut.pos_n[2] = weight;
    
    float theta_s = (1.0 - vIn.texcoord[0]) * pi;
    vOut.v2 = float2(cos(theta_s), sin(theta_s)) * 100.0;
    
    vOut.position = pos;
    vOut.texcoord = tc;
    
    return vOut;
}

//constant int division = 64;
//float scan_max = (pi/2)-atan(5.0);
//constant float scan_max = 0.197395560;

fragment half4 fragment_depth_shader(
                               VertexOut in [[stage_in]],
                               texture2d<float, access::sample> textureRGB [[texture(0)]]
                               ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 eyepos = float2(0.0, 0.0);
    float disparity = 0.032;
    float scan_size = 1.0;

    if(in.flag == 1) {
        if(in.pos_n[0] > 0.0 || in.pos_n[0] < -1) {
            discard_fragment();
        }
        eyepos[0] = -disparity;
    } else {
        if(in.pos_n[0] < 0.0 || in.pos_n[0] > 1) {
            discard_fragment();
        }
        eyepos[0] = disparity;
        scan_size = -scan_size;
    }
    
    float dispMax = asin(disparity/(disparity*4.0))/twopi;//check max dispairty angle
    float dispMin = asin(disparity/64.0)/twopi;//check min dispairty angle
    
    //float scan_width = float(textureRGB.get_width())*dispMax;
    float weight = in.pos_n[2];
    //int division = max(int(scan_width*weight/25.0),1);
    int division = max(int(weight*32.0),2);
    //int division = 32.0;
    float scan_max = weight*(dispMax - dispMin);
    scan_size = scan_max / float(division) * scan_size;
    
    float before_val = -1.0;
    int result1 = 0;
    float scan = in.pos_n[1] + dispMin;
    
    float check = 1.0;
    /*
    int dir = 1;
    int itr = 0;//iterator

    {

        float normalizedSample = (1.0 - scan) * 0.5;
        float2 refTex = float2(normalizedSample, in.texcoord[1]);
        if(getDepth(refTex, textureRGB) < 4.0) {
            dir = -1;
            itr = division - 1;
            scan = in.pos_n[1] + scan_size*itr;
            check = 0.0;
        }
    }*/
    
    for(int i = 0; i<division; i++) {
        //int ref = itr + i*dir;
        float normalizedSample = (1.0 - scan)*in.xAxis[0];

        float2 refTex = float2(normalizedSample, in.texcoord[1]);
        float2 refPos = float2(cos(scan*pi), sin(scan*pi));
        
        float2 v1 = refPos * getDepth(refTex, textureRGB);
        float val = checkCollision(eyepos, v1, in.v2);
        if(val >= before_val && val < 1.0) {
            //result1 = ref;
            result1 = i;
            before_val = val;
        } else {
            //if(before_val>0.99) {
                check = before_val;
                break;
            //}
        }
        //scan = saturate(scan + scan_size*dir);
        scan = saturate(scan + scan_size);
    }

    float2 rCoord = scan_size*result1*in.xAxis;
    rCoord = float2((1.0 - rCoord[0]), -rCoord[1]) + in.texcoord;
    if(rCoord[0] < 0.0) {
        rCoord[0] += 1.0;
    } else if(rCoord[0] > 1.0) {
        rCoord[0] -= 1.0;
    }
    
    float4 color = textureRGB.sample(s, float2(rCoord[0], rCoord[1]));
    
    //float depth = getDepth(in.texcoord, textureRGB) / 32.0;
    //return half4(depth, depth, depth, depth);
    //return half4(result1, result1, result1, result1);
    return half4(color[2], color[1], color[0], color[3]);
}
