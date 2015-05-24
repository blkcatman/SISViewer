//
//  Node.h
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/17.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//
#ifndef SIVRViewer_Node_h
#define SIVRViewer_Node_h

#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#import <GLKIt/GLKMath.h>

#import "Vector5D.h"

#endif

@interface Node : NSObject

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) id <MTLDevice> device;
@property (nonatomic, readonly) int vertexCount;

@property (assign, readwrite) float posX, posY, posZ, rotX, rotY, rotZ, scale;

@property (nonatomic, readonly) CFTimeInterval time;

@property (assign) float* fov;

- (instancetype)init;

- (instancetype)initWithRenderObject:(NSString*)nodeName
                         vertexArray:(Vector5D*)vertexArray
                          indexArray:(UInt32*)indexArray
                         vertexCount:(int)vertexCount
                          indexCount:(int)indexCount
                              device:(id<MTLDevice>)mtlDevice
                          stereoMode:(BOOL)stereo;


- (void)renderWithMetal:(id<MTLCommandQueue>)queue
           mtlDrawable1:(id<CAMetalDrawable>)drawable
      parentModelMatrix:(GLKMatrix4)parentMatrix
       projectionMatrix:(GLKMatrix4)projMatrix
             clearColor:(MTLClearColor)color;

- (void)setTexture:(id<MTLTexture>)texture;

- (void)updateWithDelta:(CFTimeInterval)delta;

- (void)stereoMode:(BOOL)mode;

- (void)setRoll:(float)roll;


@end