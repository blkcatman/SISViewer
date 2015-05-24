//
//  UIViewController+VideoLoaderViewController.h
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/30.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoLoaderViewController : UIViewController
<UITextFieldDelegate, UIGestureRecognizerDelegate, NSURLConnectionDelegate>


@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *downloadButton;
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addVideoButton;

@property (weak, nonatomic) IBOutlet UIImageView *thumbnail;


@property(nonatomic, strong) UITapGestureRecognizer *singleTap;


- (IBAction)startDownload:(id)sender;
- (IBAction)abortDownload:(id)sender;

- (void) addParentObject:(UIViewController*)parent withSelector:(SEL)selector;

@end
