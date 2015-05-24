//
//  MotionManager.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/21.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import "MotionManager.h"



@implementation MotionManager
{
    CMMotionManager* _motionManager;
    //float _pitch, _yaw, _roll;
}

- (instancetype)init{
    NSLog(@"MotionManager Initialized:");
    self = [super init];
    
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.deviceMotionUpdateInterval = 1.0 / 60.0;
    
    [_motionManager startDeviceMotionUpdates];

    /*
    [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion* motion, NSError* error){
        CMAttitude* att = motion.attitude;
        _pitch = att.pitch;
        _yaw = att.yaw;
        _roll = att.roll;
     }];
    */
    return self;
}

- (float)getPitch {
    CMDeviceMotion* motion = [_motionManager deviceMotion];
    return (motion.attitude.pitch);
}

- (float)getYaw {
    CMDeviceMotion* motion = [_motionManager deviceMotion];
    return (motion.attitude.yaw);
}

- (float)getRoll {
    CMDeviceMotion* motion = [_motionManager deviceMotion];
    return (motion.attitude.roll);
}



@end

