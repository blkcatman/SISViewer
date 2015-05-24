//
//  ViewController.h
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/17.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKMath.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIView *metalView;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UIButton *resetButton;

@property (readonly, nonatomic, getter=isAnimating) BOOL animating;
@property (nonatomic) NSInteger animationFrameInterval;

@property (nonatomic, copy) NSString *movieFilePath;

- (void)startAnimation;
- (void)stopAnimation;

@end

