//
//  MotionManater.h
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/21.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#ifndef SIVRViewer_MotionManager_h
#define SIVRViewer_MotionManager_h

#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

#endif

@interface MotionManager : NSObject

//@property (assign, readonly) float pitch, yaw, roll;

@property (nonatomic, getter=getPitch) float pitch;
@property (nonatomic, getter=getYaw) float yaw;
@property (nonatomic, getter=getRoll) float roll;

@end