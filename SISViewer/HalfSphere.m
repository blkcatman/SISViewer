//
//  HalfSphere.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/18.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "HalfSphere.h"
#import "MotionManager.h"

@implementation HalfSphere
{
    int _vertCount;
    int _indexCount;
}

- (instancetype)initWithDevice:(id<MTLDevice>)mtlDevice {
    NSLog(@"Node Initialize:");
    Vector5D* vertices = [self makeHalfSphere:128 vDivision:64];
    UInt32* indecies = [self makeHalfSphereIndex:128 vDivision:64];
    
    NSLog(@"HalfSphere Create Sphere %dx%d",64, 64);
    NSLog(@"HalfSphere vertCount:%d, indices:%d",_vertCount, _indexCount);
    
    self = [super initWithRenderObject:@"HalfSphere"
                           vertexArray:vertices
                            indexArray:indecies
                           vertexCount:_vertCount
                            indexCount:_indexCount
                                device:mtlDevice
                            stereoMode:YES];
    free(vertices);
    free(indecies);

    return self;
}

- (void)updateWithDelta:(CFTimeInterval)delta {
    [super updateWithDelta:delta];
}

- (Vector5D*)makeHalfSphere:(int)hDivision vDivision:(int)vDivision {
    Vector5D* vertices;
    Vector5D* polygons;
    
    float hpi = M_PI_2;
    float pi = M_PI;
    float tpi = M_PI*2.0;
    int h = hDivision >= 8 ? hDivision:8;
    int v = vDivision >= 4 ? vDivision:4;
    
    vertices = malloc(sizeof(Vector5D) * (h+1)*(v+1));
    polygons = malloc(sizeof(Vector5D) * h*v*6);
    
    int vertCount = 0;
    for(int y=0; y<=v; y++) {
        float yD = (float)y/(float)(v/2) - 1.0;
        float yDT = (float)y/(float)v;
        
        for(int x=0; x<=h; x++) {
            float xD = (float)x/(float)h;
            float xDT = xD;
            
            Vector5D p;
            p.x = cos(yD*hpi)*cos(xD*tpi)*(-1.0);
            p.y = sin(yD*hpi);
            p.z = -cos(yD*hpi)*sin(xD*tpi);
            p.u = xDT;
            p.v = yDT;
            p = scaledVector5D(&p, 1.0, 1.0, 1.0);
            
            vertices[vertCount] = p;
            vertCount++;
        }
    }
    _vertCount = vertCount;
    return vertices;
    
    //int polyCount = 0;
    /*for(int y=0; y<v; y++) {
        for(int x=0; x<h; x++) {
            Vector5D v00 = vertices[y*(h+1)+x  ];
            Vector5D v01 = vertices[y*(h+1)+x+1];
            Vector5D v10 = vertices[(y+1)*(h+1)+x  ];
            Vector5D v11 = vertices[(y+1)*(h+1)+x+1];
            
            polygons[polyCount] = v00;
            polyCount++;
            polygons[polyCount] = v01;
            polyCount++;
            polygons[polyCount] = v11;
            polyCount++;
            
            polygons[polyCount] = v10;
            polyCount++;
            polygons[polyCount] = v00;
            polyCount++;
            polygons[polyCount] = v11;
            polyCount++;
        }
    }*/
    /*
    for(int x=0; x<h; x++) {
        for(int y=0; y<=v; y++) {
            Vector5D v00 = vertices[y*(h+1)+x  ];
            Vector5D v01 = vertices[y*(h+1)+x+1];
            
            if(y==0) {
                polygons[polyCount] = v00;
                polyCount++;
            }
            polygons[polyCount] = v00;
            polyCount++;
            polygons[polyCount] = v01;
            polyCount++;
            if(y==v) {
                polygons[polyCount] = v01;
                polyCount++;
            }
        }
    }
    polygons = realloc(polygons, sizeof(Vector5D)*polyCount);
    _vertCount = polyCount;
    
    _vertCount = vertCount;
    free(vertices);
    
    return polygons;
     */
}

- (UInt32*)makeHalfSphereIndex:(int)hDivision vDivision:(int)vDivision {
    int h = hDivision;
    int v = vDivision;
    UInt32* idx = (UInt32*)malloc(sizeof(UInt32)*h*v*6);
    
    int idxCount = 0;
    for(int x=0; x<h; x++) {
        for(int y=0; y<=v; y++) {
            //Vector5D v00 = vertices[y*(h+1)+x  ];
            //Vector5D v01 = vertices[y*(h+1)+x+1];
            UInt32 v00 = y*(h+1)+x  ;
            UInt32 v01 = y*(h+1)+x+1;
            
            if(y==0) {
                idx[idxCount] = v00;
                idxCount++;
            }
            idx[idxCount] = v00;
            idxCount++;
            idx[idxCount] = v01;
            idxCount++;
            if(y==v) {
                idx[idxCount] = v01;
                idxCount++;
            }
        }
    }
    idx = realloc(idx, sizeof(UInt32)*idxCount);
    _indexCount = idxCount;
    return idx;
}


@end