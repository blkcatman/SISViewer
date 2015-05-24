//
//  Vector5D.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/18.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Vector5D.h"

Vector5D scaledVector5D(Vector5D* srcVector, float xScale, float yScale, float zScale) {
    Vector5D destVector;
    destVector.x = srcVector->x * xScale;
    destVector.y = srcVector->y * xScale;
    destVector.z = srcVector->z * xScale;
    destVector.u = srcVector->u;
    destVector.v = srcVector->v;
    return destVector;
}

float* toArrayVector5D(Vector5D* srcVector, float* destArray) {
    destArray[0] = srcVector->x;
    destArray[1] = srcVector->y;
    destArray[2] = srcVector->z;
    destArray[3] = srcVector->u;
    destArray[4] = srcVector->v;
    return destArray;
}