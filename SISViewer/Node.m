//
//  Node.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/17.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GLKit/GLKMath.h>

#import "Node.h"

@implementation Node
{
    NSString* _name;
    id <MTLDevice> _device;
    int _vertexCount;
    
    float _posX, _posY, _posZ, _rotX, _rotY, _rotZ, _scale;
    float _roll;
    
    CFTimeInterval _time;
    
    id <MTLBuffer> _vertexBuffer;
    id <MTLBuffer> _indexBuffer;
    id <MTLBuffer> _uniformBuffer1, _uniformBuffer2;
    id <MTLBuffer> _viewRectBuffer1, _viewRectBuffer2;
    
    id <MTLTexture> _texture;
    
    id<MTLRenderPipelineState> _pipelineState;
    
    BOOL _stereoMode;
    
    int _numIndex;
    float* _fov;
}

- (instancetype)initWithRenderObject:(NSString*)nodeName
                         vertexArray:(Vector5D*)vertexArray
                          indexArray:(UInt32*)indexArray
                         vertexCount:(int)vertexCount
                          indexCount:(int)indexCount
                              device:(id<MTLDevice>)mtlDevice
                          stereoMode:(BOOL)stereo
{
    NSLog(@"Node Initialize:");
    NSLog(stereo ? @"Node Stereo Mode Enabled" : @"Node Stereo Mode Disabled");
    self = [super init];
    if(self != nil) {
        _time = 0.0;
        _scale = 1.0;
    }
    _numIndex = indexCount;
    
    int length = sizeof(float)*5*vertexCount;
    float* vertexData = malloc(length);
    for (int i = 0; i<vertexCount; i++) {
        vertexData[i*5 + 0] = vertexArray[i].x;
        vertexData[i*5 + 1] = vertexArray[i].y;
        vertexData[i*5 + 2] = vertexArray[i].z;
        vertexData[i*5 + 3] = vertexArray[i].u;
        vertexData[i*5 + 4] = vertexArray[i].v;
    }
    NSLog(@"Node Create Vertex Buffer");
    _vertexBuffer = [mtlDevice newBufferWithBytes:vertexData length:length options:MTLResourceOptionCPUCacheModeDefault];
    free(vertexData);
    
    NSLog(@"Node Create Index Buffer");
    int indexLength = sizeof(UInt32)*indexCount;
    _indexBuffer = [mtlDevice newBufferWithBytes:indexArray length:indexLength options:MTLResourceOptionCPUCacheModeDefault];
    
    _name = nodeName;
    _device = mtlDevice;
    _vertexCount = vertexCount;
    _stereoMode = stereo;
    
    NSLog(@"Node Create PipelineState");
    [self createPipelineState];
    
    return self;
}

- (void)renderWithMetal:(id<MTLCommandQueue>)queue
           mtlDrawable1:(id<CAMetalDrawable>)drawable
      parentModelMatrix:(GLKMatrix4)parentMatrix
       projectionMatrix:(GLKMatrix4)projMatrix
             clearColor:(MTLClearColor)color
{
    
    if(_uniformBuffer1 == nil || _uniformBuffer2 == nil) {
        NSLog(@"Node Create Uniform Buffers");
        _uniformBuffer1 = [_device newBufferWithLength:sizeof(float) * 16 * 2
                                          options:MTLResourceOptionCPUCacheModeDefault];
        _uniformBuffer2 = [_device newBufferWithLength:sizeof(float) * 16 * 2
                                              options:MTLResourceOptionCPUCacheModeDefault];
    }
    if(_viewRectBuffer1 == nil || _viewRectBuffer2 == nil) {
         NSLog(@"Node Create ViewRect Buffers");
        _viewRectBuffer1 = [_device newBufferWithLength:sizeof(float) * 4
                                              options:MTLResourceOptionCPUCacheModeDefault];
        _viewRectBuffer2 = [_device newBufferWithLength:sizeof(float) * 4
                                                options:MTLResourceOptionCPUCacheModeDefault];
    }
    
    id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
    if(_stereoMode == YES) {
        MTLRenderPassDescriptor* renderPassDesc = [[MTLRenderPassDescriptor alloc] init];
        renderPassDesc.colorAttachments[0].texture = drawable.texture;
        renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDesc.colorAttachments[0].clearColor = color;
        renderPassDesc.colorAttachments[0].texture = drawable.texture;
        
        id<MTLRenderCommandEncoder> renderEncoder =
            [commandBuffer renderCommandEncoderWithDescriptor:renderPassDesc];
        
        float rFov = 60.0 / 180.0;
        if(_fov) {
            rFov = *_fov / 180.0;
        }

        float viewRect1[] = {-0.5, rFov, _roll, 1.0};
        float viewRect2[] = { 0.5, rFov, _roll, 1.0};
        
        [self setRenderCommandEncoder:renderEncoder
                        pipelineState:_pipelineState
                    parentModelMatrix:parentMatrix
                     projectionMatrix:projMatrix
                         viewRectSize:viewRect1];
        [self setRenderCommandEncoder:renderEncoder
                        pipelineState:_pipelineState
                    parentModelMatrix:parentMatrix
                     projectionMatrix:projMatrix
                         viewRectSize:viewRect2];
        
        [renderEncoder endEncoding];
    } else {
        MTLRenderPassDescriptor* renderPassDesc = [[MTLRenderPassDescriptor alloc] init];
        renderPassDesc.colorAttachments[0].texture = drawable.texture;
        renderPassDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDesc.colorAttachments[0].clearColor = color;
        renderPassDesc.colorAttachments[0].texture = drawable.texture;
        
        float viewRect[] = {0.0, 0.0, 1.0, -1.0};
    
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDesc];
        [self setRenderCommandEncoder:renderEncoder
                        pipelineState:_pipelineState
                    parentModelMatrix:parentMatrix
                     projectionMatrix:projMatrix
                         viewRectSize:viewRect];
        [renderEncoder endEncoding];
    }
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

- (void) setRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderEncoder
            pipelineState:(id<MTLRenderPipelineState>)pipeLine
        parentModelMatrix:(GLKMatrix4)parentMatrix
         projectionMatrix:(GLKMatrix4)projMatrix
             viewRectSize:(float*)viewRect
{
    
    if(renderEncoder != nil) {
        //Matrix4* pMatrix = [parentMatrix copy];
        
        [renderEncoder setCullMode:MTLCullModeBack];
        [renderEncoder setRenderPipelineState:pipeLine];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        
        id <MTLBuffer> _uniform;
        if(viewRect[0] < 0.0) {
            _uniform = _uniformBuffer1;
            //[pMatrix translate: 0.032 y:0.0 z:0.0];
        } else {
            _uniform = _uniformBuffer2;
            //[pMatrix translate:-0.032 y:0.0 z:0.0];
        }
        
        //Matrix4* nodeModelMatrix = [self modelMatrix];
        //[nodeModelMatrix multiplyLeft:pMatrix];
        void* bufferPtr = [_uniform contents];
        unsigned long matrixSize = sizeof(float) * 16;
        memcpy(bufferPtr, &parentMatrix, matrixSize);
        memcpy(bufferPtr + matrixSize, &projMatrix, matrixSize);
        [renderEncoder setVertexBuffer:_uniform offset:0 atIndex:1];
        
        void* rectPtr;
        if(viewRect[0] < 0.0) {
            rectPtr = [_viewRectBuffer1 contents];
            memcpy(rectPtr, (void*)viewRect, sizeof(float) * 4);
            [renderEncoder setVertexBuffer:_viewRectBuffer1 offset:0 atIndex:2];
        } else {
            rectPtr = [_viewRectBuffer2 contents];
            memcpy(rectPtr, (void*)viewRect, sizeof(float) * 4);
            [renderEncoder setVertexBuffer:_viewRectBuffer2 offset:0 atIndex:2];
        }
        
        if(_texture != nil) {
            if(_stereoMode == YES) {
                [renderEncoder setVertexTexture:_texture atIndex:0];
            }
            [renderEncoder setFragmentTexture:_texture atIndex:0];
        }
        
        [renderEncoder pushDebugGroup:_name];
        
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangleStrip indexCount:_numIndex indexType:MTLIndexTypeUInt32 indexBuffer:_indexBuffer indexBufferOffset:0];
        /*
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:_vertexCount];
        */
        [renderEncoder popDebugGroup];
    }
}

- (void)createPipelineState {
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    id<MTLFunction> fragmentProgram, vertexProgram;
    if(_stereoMode == NO) {
        fragmentProgram = [defaultLibrary newFunctionWithName:@"fragment_shader"];
        vertexProgram = [defaultLibrary newFunctionWithName:@"vertex_shader"];
    } else {
        fragmentProgram = [defaultLibrary newFunctionWithName:@"fragment_depth_shader"];
        vertexProgram = [defaultLibrary newFunctionWithName:@"vertex_depth_shader"];
    }
    
    MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineStateDescriptor.fragmentFunction = fragmentProgram;
    pipelineStateDescriptor.vertexFunction = vertexProgram;
    pipelineStateDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    NSError* err = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&err];    
    if(err != nil) {
    }
}

- (instancetype)init{
    self = [super init];
    if(self != nil){
        _time = 0.0;
        _scale = 1.0;
    }
    return self;
}

- (void)setTexture:(id<MTLTexture>)texture {
    _texture = texture;
}

- (void)updateWithDelta:(CFTimeInterval)delta {
    _time += delta;
}

- (void)stereoMode:(BOOL)mode {
    _stereoMode = mode;
}

- (void)setRoll:(float)roll {
    _roll = roll;
}

@end