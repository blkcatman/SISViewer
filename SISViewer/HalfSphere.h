//
//  HalfSphere.h
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/18.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#ifndef SIVRViewer_HalfSphere_h
#define SIVRViewer_HalfSphere_h

#import "Node.h"
#import "Vector5D.h"

#endif

@interface HalfSphere : Node

- (instancetype)initWithDevice:(id <MTLDevice>)mtlDevice;
- (Vector5D*)makeHalfSphere:(int)hDivision vDivision:(int)vDivision;
- (UInt32*)makeHalfSphereIndex:(int)hDivision vDivision:(int)vDivision;

@end