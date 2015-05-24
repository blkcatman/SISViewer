//
//  Vector5D.h
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/18.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#ifndef SIVRViewer_Vector5D_h
#define SIVRViewer_Vector5D_h

#import <QuartzCore/QuartzCore.h>

#endif

typedef struct{
    float x,y,z,u,v;
}Vector5D;

Vector5D scaledVector5D(Vector5D* srcVector, float xScale, float yScale, float zScale);

float* toArrayVector5D(Vector5D* srcVector, float* destArray);