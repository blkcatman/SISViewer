//
//  ViewController.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/17.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "ViewController.h"
#import "MotionManager.h"
#import "Matrix4.h"
#import "HalfSphere.h"


@implementation ViewController {
    NSString *_videoFilePath;
    
    id<MTLDevice> _device;
    CAMetalLayer* _metalLayer;
    id<MTLCommandQueue> _commandQueue;
    
    MotionManager* _motionManager;
    
    HalfSphere* _objectToDraw;
    
    CADisplayLink* _timer;
    GLKMatrix4 _projectionMatrix;
    CFTimeInterval _lastFrameTimestamp;
    
    AVURLAsset* asset;
    AVPlayerItem* playerItem;
    AVPlayer* player;
    AVMutableComposition* comp;
    AVMutableCompositionTrack* track;
    AVAssetReader* reader;
    AVAssetReaderTrackOutput* output;
    bool avassetReading;
    
    float frameRate;
    int currentFrame;
    bool isFrameUpdate;
    
    float fov;
    float aspect;
    int loopCount;
    
    float default_yaw;
    
    //void* buffer;
    CGContextRef cgContext;
    //CGColorSpaceRef colorSpace;
    id<MTLTexture> texture;
    
    BOOL _animating;
    NSInteger _animationFrameInterval;
    
    const NSString* _ItemStatusContext;
    
    CMSampleBufferRef _backBuf;
    dispatch_semaphore_t _sem;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSNotificationCenter*   nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive) name:@"applicationWillResignActive" object:nil];
    [nc addObserver:self selector:@selector(applicationWillEnterForeground) name:@"applicationWillEnterForeground" object:nil];
    
    fov = 60.0;
    loopCount = 0;
    default_yaw = 0;
    
    _backButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _backButton.layer.borderWidth = 1.0f;
    _backButton.layer.cornerRadius = 7.5f;
    [_backButton setHidden:true];
    _resetButton.layer.borderColor = [UIColor whiteColor].CGColor;
    _resetButton.layer.borderWidth = 1.0f;
    _resetButton.layer.cornerRadius = 7.5f;
    [_resetButton setHidden:true];
    
    _motionManager = [[MotionManager alloc] init];
    _device = MTLCreateSystemDefaultDevice();
    
    _metalLayer = [[CAMetalLayer alloc] init];
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES;
    
    CGRect frameRect = self.view.layer.frame;
    CGFloat width = frameRect.size.width;
    CGFloat height = frameRect.size.height;
    if(width > height) {
        CGFloat b = width;
        width = height;
        height = b;
    }
    frameRect.origin.x = 0.0;
    frameRect.origin.y = 0.0;
    
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    CGFloat statusBarHeight = statusBarSize.height;
    if( statusBarHeight > 0.0) {
        height += statusBarHeight;
    }
    
    frameRect.size.width = height;
    frameRect.size.height = width;
    _metalLayer.frame = frameRect;
    [_metalView.layer addSublayer:_metalLayer];
    aspect = height/width;
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(fov),aspect, 0.001, 100.0);
    //_projectionMatrix = [Matrix4 makePerspectiveViewAngle:GLKMathDegreesToRadians(fov) aspectRatio:aspect nearZ:0.001 farZ:100.0];
    
    _commandQueue = [_device newCommandQueue];
    _objectToDraw = [[HalfSphere alloc] initWithDevice:_device];
    _objectToDraw.fov = &fov;
    
    _animating = FALSE;
    _animationFrameInterval = 1;

    NSDictionary* assetOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                             forKey:AVURLAssetPreferPreciseDurationAndTimingKey];

    asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:_movieFilePath] options:assetOptions];    
    [asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler:^{
        NSError* error = nil;
        AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&error];
        if (status == AVKeyValueStatusLoaded) {
            playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
            [playerItem addObserver:self forKeyPath:@"status" options:0 context:&_ItemStatusContext];
            player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
            player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerItemDidReachEnd:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:[player currentItem]];
            
        } else {
            NSLog(@"%@", [error localizedDescription]);
        }
    }];
    
    AVAssetTrack* srcTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    comp = [AVMutableComposition composition];
    track = [comp addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    NSError* error = nil;
    BOOL ok = [track insertTimeRange:srcTrack.timeRange ofTrack:srcTrack atTime:kCMTimeZero error:&error];
    if (!ok) {
        NSLog(@"%@", [error localizedDescription]);
    }
    
    frameRate = track.nominalFrameRate;
    
    NSDictionary* outputSettings =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey, nil];
    
    reader = [[AVAssetReader alloc] initWithAsset:comp error:&error];
    output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
    if(output == nil) {
        NSLog(@"%s AVAssetReaderTrackOutput initWithTrack failed for the video track.", __func__);
        return;
    }
    [reader addOutput:output];
    //[reader startReading];
    [self getSampleBufferInBackground];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object
                        change:(NSDictionary*)change context:(void*)ctx
{
    if (ctx == &_ItemStatusContext) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay && player.rate == 0) {
            for (AVPlayerItemTrack* itemTrack in playerItem.tracks) {
                if (![itemTrack.assetTrack hasMediaCharacteristic:AVMediaCharacteristicAudible]) {
                    itemTrack.enabled = NO;
                }
            }
            [player play];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:ctx];
    }
}

- (void)render {
    id<CAMetalDrawable> drawable = _metalLayer.nextDrawable;
    if(drawable == nil) return;

    GLKMatrix4 worldMatrix = GLKMatrix4Identity;
    float rotZ = _motionManager.pitch;
    float rotY = _motionManager.yaw - default_yaw;
    float rotX = _motionManager.roll + (M_PI/2.0);
    
    [_objectToDraw setRoll:_motionManager.pitch];
    
    worldMatrix = GLKMatrix4RotateX(worldMatrix, rotX);
    worldMatrix = GLKMatrix4RotateZ(worldMatrix, rotZ);
    worldMatrix = GLKMatrix4RotateY(worldMatrix, -rotY);
    
    CMSampleBufferRef buf = nil;
    
    if(reader.status == AVAssetReaderStatusReading && isFrameUpdate) {
        [self waitSampleBufferLoad];
        buf = _backBuf;
    }
    
    if(buf != nil) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(buf);
        CVPixelBufferLockBaseAddress(imageBuffer,  0);
        
        void *baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t width       = CVPixelBufferGetWidth(imageBuffer);
        size_t height      = CVPixelBufferGetHeight(imageBuffer);
        
        if(width == 0 || height == 0) {
            //CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            //CFRelease(buf);
            return;
        }

        if(texture == nil) {
            MTLTextureDescriptor *texDesc = [MTLTextureDescriptor
                                             texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                             width:width
                                             height:height
                                             mipmapped:NO];
            texture = [_device newTextureWithDescriptor:texDesc];
        }
        
        [texture replaceRegion:MTLRegionMake2D(0, 0, width, height)
                   mipmapLevel:0
                     withBytes:baseAddress
                   bytesPerRow:4 * width];
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        CFRelease(buf);
        [self getSampleBufferInBackground];
    }
    
    if(texture != nil) {
        [_objectToDraw setTexture:texture];
        [_objectToDraw renderWithMetal:_commandQueue
                          mtlDrawable1:drawable
                     parentModelMatrix:worldMatrix
                      projectionMatrix:_projectionMatrix
                            clearColor:MTLClearColorMake(1.0, 0.0, 0.0, 1.0)];
    }
    
}

- (void)newFrame:(CADisplayLink *)displayLink {
    if(!_animating) return;
    if (_lastFrameTimestamp == 0) {
        _lastFrameTimestamp = displayLink.timestamp;
    }
    CFTimeInterval elapsed = displayLink.timestamp - _lastFrameTimestamp;
    _lastFrameTimestamp = displayLink.timestamp;
    
    [self gameLoop:elapsed];
}

- (void)gameLoop:(CFTimeInterval)timeSinceLastUpdate {
    [_objectToDraw updateWithDelta:timeSinceLastUpdate];
    @autoreleasepool {
        [self render];
    }
}

- (void)waitSampleBufferLoad {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
}

- (void)getSampleBufferInBackground {
    if(reader == nil) return;
    
    isFrameUpdate = false;
    _sem = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND,0), ^ {
        while (reader.status != AVAssetReaderStatusReading) {
            if(!_animating && currentFrame != 0) {
                dispatch_semaphore_signal(_sem);
                return;
            }
        }
        _backBuf = [output copyNextSampleBuffer];
        Float64 playerTime = CMTimeGetSeconds([player currentTime]);
        Float64 videoTime = (Float64)(currentFrame-1)*(1.0/frameRate);
        while(playerTime < videoTime) {
            playerTime = CMTimeGetSeconds([player currentTime]);
            videoTime = (Float64)(currentFrame-1)*(1.0/frameRate);
        }
        currentFrame++;
        isFrameUpdate = true;
        dispatch_semaphore_signal(_sem);
    });
}


- (IBAction)tapGestureToShowHideButton:(id)sender {
    bool flag = !_backButton.isHidden;
    [_backButton setHidden:flag];
    flag = !_resetButton.isHidden;
    [_resetButton setHidden:flag];
}

- (IBAction)pinchGestureToChangeFov:(UIPinchGestureRecognizer *)pinchGestureRecognizer {
    fov = fov * sqrt(sqrt(1.0/pinchGestureRecognizer.scale));
    if(fov > 100.0) {
        fov = 100.0;
    }
    if(fov < 50.0) {
        fov = 50.0;
    }
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(fov),aspect, 0.001, 100.0);
    
    //_projectionMatrix = [Matrix4 makePerspectiveViewAngle:GLKMathDegreesToRadians(fov) aspectRatio:aspect nearZ:0.001 farZ:100.0];
}

- (IBAction)resetOrientation:(id)sender {
    default_yaw = _motionManager.yaw;
}


////////////

- (void)viewWillAppear:(BOOL)animated
{
    [self startAnimation];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopAnimation];
    [super viewWillDisappear:animated];
}

////////////

- (void)startAnimation
{
    if (!_animating)
    {
        CADisplayLink *aDisplayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(newFrame:)];
        [aDisplayLink setFrameInterval:_animationFrameInterval];
        [aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        _timer = aDisplayLink;
        if(!avassetReading) {
            [reader startReading];
            avassetReading = TRUE;
        }
        _animating = TRUE;
    }
}

- (void)stopAnimation
{
    if (_animating)
    {
        [_timer invalidate];
        _timer = nil;
        _animating = FALSE;
    }
}

- (void)dealloc {
    CGContextRelease(cgContext);
    //CGColorSpaceRelease(colorSpace);
}

//////////

- (BOOL)shouldAutorotate
{
    return YES; // YES:自動回転する NO:自動回転しない
}

- (NSUInteger) supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)closeViewer
{
    [self stopAnimation];
    [playerItem removeObserver:self forKeyPath:@"status" context:&_ItemStatusContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:playerItem];
    [_metalLayer removeFromSuperlayer];
    [self dismissViewControllerAnimated:YES completion:nil];
}

//////////

- (void)applicationWillResignActive

{
    NSLog(@"applicationDidEnterBackground");
    [self closeViewer];
}

- (void)applicationWillEnterForeground

{
    NSLog(@"applicationWillEnterForeground");
    //[self startAnimation];
}

- (IBAction)backToMasterVIew:(id)sender {
    [self closeViewer];
}

- (void)playerItemDidReachEnd:(NSNotification*)notification
{
    NSLog(@"Reach to Movie End");
    NSError* error = nil;
    NSDictionary* outputSettings =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey, nil];
    
    AVPlayerItem* p = [notification object];
    [p seekToTime:kCMTimeZero];
    currentFrame = 0;
    
    reader = [[AVAssetReader alloc] initWithAsset:comp error:&error];
    output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:outputSettings];
    if(output == nil) {
        NSLog(@"%s AVAssetReaderTrackOutput initWithTrack failed for the video track.", __func__);
        return;
    }
    [reader addOutput:output];
    [self getSampleBufferInBackground];
    BOOL isStart = [reader startReading];
    if(!isStart) {
        NSLog(@"%@", [reader error]);
    }
    
    //[self closeViewer];
    loopCount++;
}

@end
