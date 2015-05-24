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
    float4 position [[position]];  //1
    float2 texcoord;
    float2 pos_n;
    float2 xAxis;
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

float getDepth(float xCoord, float yCoord, texture2d<float, access::sample> textureRGB);
float float2Cross(float2 v1, float2 v2);
//float2 checkCollision(float2 p1, float2 p2, float2 v1, float2 v2);
float checkCollision(float2 p1, float2 p2, float2 v1, float2 v2);

float2 RTC(float src, float2 xAxis);

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
    tc[1] = 1.0 - tc[1];
    tc[0] = (tc[0] * 0.5);
    
    //float dd0 = getDepth(tc[0], tc[1], textureRGB);
    //float dd1 = getDepth(tc[0]+0.004, tc[1], textureRGB);
    //float dd2 = getDepth(tc[0]-0.004, tc[1], textureRGB);
    
    //float dd = (dd0 + dd1 + dd2) / 2.0;
    
    //float3 pp = VertexIn.position * dd0;
    //float4 pos = proj_Matrix * mv_Matrix * float4(pp,1);
    //float pi = 3.14159265;
    float4 pos = proj_Matrix * mv_Matrix * float4(vIn.position,1.0);
    float2 xAxis = float2(cos(viewRect[2]), sin(viewRect[2])); // viewRect[2] is roll;
    
    //view flags 0=no stereo, 1=left eye, 2=right eye
    vOut.flag = 0;
    
    if(viewRect[3] > 0.0) {
        if(viewRect[0] < 0.0) {
            vOut.flag = 1;
        } else {
            vOut.flag = 2;
        }
        
        pos[0] = (pos[0] / pos[3]) + viewRect[0]; //left = pos[0]-0.5, right pos[0]+0.5
        vOut.pos_n[0] = pos[0]; //pos_n[0] = display position
        pos[0] = pos[0] * pos[3];
        
        vOut.xAxis = xAxis;
    }
    //vOut.pos_n[1] = vIn.position[0]; //pos_n[1] = horizontal cosine value of spherial position;
    vOut.pos_n[1] = 1.0 - vIn.texcoord[0]; //0-1 normalized horizontal radians of spherical coordination
    
    vOut.position = pos;
    vOut.texcoord = tc;
    
    return vOut;
}

float getDepth(float xCoord, float yCoord, texture2d<float, access::sample> textureRGB) {
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    float xc = xCoord + 0.5;
    
    float4 rd0 = textureRGB.sample(s, float2(xc, yCoord));
    float4 rd1 = textureRGB.sample(s, float2(xc+0.001, yCoord));
    float4 rd2 = textureRGB.sample(s, float2(xc+0.002, yCoord));
    float4 rd3 = textureRGB.sample(s, float2(xc-0.001, yCoord));
    float4 rd4 = textureRGB.sample(s, float2(xc-0.002, yCoord));
    float4 rd5 = textureRGB.sample(s, float2(xc, yCoord+0.001));
    float4 rd6 = textureRGB.sample(s, float2(xc, yCoord+0.002));
    float4 rd7 = textureRGB.sample(s, float2(xc, yCoord-0.001));
    float4 rd8 = textureRGB.sample(s, float2(xc, yCoord-0.002));
    float4 rd9 = textureRGB.sample(s, float2(xc-0.001, yCoord+0.001));
    float4 rd10 = textureRGB.sample(s, float2(xc+0.001, yCoord+0.001));
    float4 rd11 = textureRGB.sample(s, float2(xc+0.001, yCoord-0.001));
    float4 rd12 = textureRGB.sample(s, float2(xc-0.001, yCoord-0.001));
    //float4 rd13 = textureRGB.sample(s, float2(xc-0.002, yCoord+0.002));
    //float4 rd14 = textureRGB.sample(s, float2(xc+0.002, yCoord+0.002));
    //float4 rd15 = textureRGB.sample(s, float2(xc+0.002, yCoord-0.002));
    //float4 rd16 = textureRGB.sample(s, float2(xc-0.002, yCoord-0.002));
    
    //float4 rawDepth = (rd0 + rd1 + rd2 + rd3 + rd4 + rd5 + rd6 + rd7 + rd8 + rd9 + rd10 + rd11 + rd12 + rd13 + rd14 + rd15 +rd16) / 17.0;
    float4 rawDepth = (rd0 + rd1 + rd2 + rd3 + rd4 + rd5 + rd6 + rd7 + rd8 + rd9 + rd10 + rd11 + rd12) / 13.0;
    const float l = log(64.0);
    const float twopi = 6.28318531;
    
    if(rawDepth[0] > 0.999) {
        return 63.0;
    }
    
    float d0 = round(exp(rawDepth[0]*l)-1.0);
    float da;
    //float d1 = round(rawDepth[1]*100.0)/50.0;
    //float d2 = round(rawDepth[2]*100.0)/100.0;
    
    //if(d1 <= d2 + 0.02 && d1 >= d2 - 0.02) {
    //    da = (d1 + d2)/4.0;
    //} else {
    //    da = ((d1 + (1.0-d2))/2.0 + 0.5)/2.0;
    //}
    float d1 = rawDepth[1]*2.0 - 1.0;//y
    float d2 = rawDepth[2]*2.0 - 1.0;//x
    da = fract(atan2(d1,d2)/twopi);
    if(da < 0) {
        da = da + 1.0;
    }
    return (d0 + da);
}

float float2Cross(float2 v1, float2 v2) {
    float cros = v1[0]*v2[1] - v1[1]*v2[0];
    return cros;
}

float checkCollision(float2 p1, float2 p2, float2 v1, float2 v2) {
    float2 v0 = p2 - p1;
    float c_v1v2 = float2Cross(v1, v2);
    if(c_v1v2 == 0.0) {
        return -1.0;
        //return float2(-1.0, 1000.0);
    }
    
    float c_v0v1 = float2Cross(v0, v1);
    float c_v0v2 = float2Cross(v0, v2);
    
    float t1 = c_v0v1 / c_v1v2;
    float t2 = c_v0v2 / c_v1v2;
    
    if(t1 < 0.0 || t1 > 1.0 || t2 < 0.0 || t2 > 1.0) {
        return -1.0;
        //return float2(-1.0, 1000.0);
    }
    
    return t1;
    //return float2(t1, t2);
}

float2 RTC(float src, float2 xAxis) {
    return (src * xAxis);
}

fragment half4 fragment_depth_shader(
                               VertexOut in [[stage_in]],
                               texture2d<float, access::sample> textureRGB [[texture(0)]]
                               ) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    
    if(in.flag == 0) {
        float4 col = textureRGB.sample(s, in.texcoord);
        return half4(col[2], col[1], col[0], col[3]);
    }
    float2 eyepos = float2(0.0, 0.0);
    float disparity = 0.032;
    int scanDir = 1.0;
    if(in.flag == 1) {
        if(in.pos_n[0] > 0.0 || in.pos_n[0] < -1) {
            discard_fragment();
        }
        eyepos[0] = -disparity;
        scanDir = 1.0;
    }
    if(in.flag == 2) {
        if(in.pos_n[0] < 0.0 || in.pos_n[0] > 1) {
            discard_fragment();
        }
        eyepos[0] = disparity;
        scanDir = -1.0;
    }
    
    float pi = 3.14159265;
    float theta_s = in.pos_n[1] * pi;
    float2 v2 = float2(cos(theta_s), sin(theta_s)) * 100.0;
    float scan_max = (pi/2)-atan(5.0);
    int division = 64;
    float scan_size = scan_max / division * scanDir;
    
    float before_val = -1.0;
    int result_index = 0;
    
    for(int i = 0; i<division; i++) {
        float angleSample = clamp(theta_s + float(i)*scan_size, 0.0, pi);
        float normalizedSample = (1.0 - angleSample/pi) * 0.5;
        //float2 dCoord = RTC(angleSample/pi, in.xAxis);
        //dCoord = float2((1.0 - dCoord[0])*0.5, -dCoord[1]) + float2(-0.5, in.texcoord[1]);
        //float2 refTex = dCoord;
        float2 refTex = float2(normalizedSample, in.texcoord[1]);
        float2 refPos = float2(cos(angleSample), sin(angleSample));
        
        float2 v1 = refPos * getDepth(refTex[0],refTex[1], textureRGB);
        float val = checkCollision(float2(0.0, 0.0), eyepos, v1, v2);
        if(val >= before_val) {
            result_index = i;
            before_val = val;
        } else {
            break;
        }
        if(val > 0.99)
            break;
    }
    //float result_theta = theta_s + float(result_index)*scan_size;
    //result_theta = (1.0 - result_theta/pi) * 0.5;
    float result_theta2 = float(result_index)*scan_size;
    float2 rCoord = RTC(result_theta2/pi, in.xAxis);
    rCoord = float2((1.0 - rCoord[0]) * 0.5, -rCoord[1]) + in.texcoord;

    //rCoord = float2(result_theta2, 0.0);
    //float2 sCoord = float2(in.texcoord[0], in.texcoord[1]) + rCoord;
    
    float4 color = textureRGB.sample(s, float2(rCoord[0] - 0.5, rCoord[1]));
    //float4 color = textureRGB.sample(s, float2(result_theta, in.texcoord[1]));
    return half4(color[2], color[1], color[0], color[3]);
}
