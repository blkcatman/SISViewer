//
//  UIViewController+VideoLoaderViewController.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/30.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import "VideoLoaderViewController.h"

#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

@implementation VideoLoaderViewController {
    UIViewController* _parent;
    SEL _selector;
    bool isDownload;
    
    bool isDownloadComplete;
    
    UIBackgroundTaskIdentifier bgTask;
    NSMutableData* receiveData;
    long totalBytes, loadedBytes;
    NSString *movieRawDir, *movieName, *uniqueName, *dlDate, *filePath;
    NSString *uniqueThumbnail, *thumbnailPath;
    NSString *cachePath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    movieRawDir = @"movies";
    _addVideoButton.enabled = false;
    isDownloadComplete = false;
    
    _downloadButton.layer.borderColor = [UIColor grayColor].CGColor;
    _downloadButton.layer.borderWidth = 1.0f;
    _downloadButton.layer.cornerRadius = 7.5f;
    [_downloadButton addTarget:self action:@selector(startDownload:) forControlEvents:UIControlEventTouchUpInside];
    
    _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onSingleTap:)];
    _singleTap.delegate = self;
    _singleTap.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:_singleTap];
    [_textField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)startDownload:(id)sender {
    [_textField resignFirstResponder];
    
    if (!isDownload && _textField.text.length != 0) {
        [_downloadButton setTitle:@"Abort" forState:UIControlStateNormal];
        [_downloadButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
        _progressLabel.text = @"Downloading";
        _progressLabel.textColor = [UIColor blackColor];
        
        [_downloadButton removeTarget:self action:@selector(startDownload:) forControlEvents:UIControlEventTouchUpInside];
        isDownload = YES;
        
        if([self checkURL:_textField.text] != false) {
            [_downloadButton addTarget:self action:@selector(abortDownload:) forControlEvents:UIControlEventTouchUpInside];
        };
    }

}

- (BOOL)checkURL:(NSString*)filename {
    NSString* src = [filename stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    /*
    BOOL isHTTP = src.length>7 ? [@"http://" compare:[src substringFromIndex:7]]:false;

    if(!isHTTP) {
        NSString* dest;
        dest = [@"http://" stringByAppendingString:src];
        src = dest;
        _textField.text = [NSString stringWithString:src];
    }*/
    movieName = [src lastPathComponent];
    
    //check parameter
    int paramLen = [movieName rangeOfString:@"?"].location;
    if(paramLen > 0) {
        movieName = [movieName substringToIndex:paramLen];
    }
    //check extension
    int extentionLen = [movieName rangeOfString:@"."].location;
    if(extentionLen <= 0) {
        _progressLabel.text = @"This is not Movie file!";
        _progressLabel.textColor = [UIColor redColor];
        [self abortDownload:nil];
        return false;
    } else {
        NSString* extension = [movieName substringFromIndex:extentionLen+1];
        if(![@"m4v" isEqualToString:extension] && ![@"mp4" isEqualToString:extension]) {
            _progressLabel.text = @"This is not Movie file!";
            _progressLabel.textColor = [UIColor redColor];
            [self abortDownload:nil];
            return false;
        }
    }
    
    NSURL* url = [NSURL URLWithString:src];
    UIApplication* app = [UIApplication sharedApplication];
    
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        if(bgTask != UIBackgroundTaskInvalid) {
            [app endBackgroundTask:bgTask];
            bgTask = UIBackgroundTaskInvalid;
            //TODO:end processing
        }
    }];
    [_progressView setProgress:0];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url];
    [NSURLConnection connectionWithRequest:request delegate:self];
    
    return true;
}

- (IBAction)abortDownload:(id)sender {
    if (isDownload) {
        if(sender != nil) {
            _progressLabel.text = @"Download Aborted";
            _progressLabel.textColor = [UIColor lightGrayColor];
        }
        
        [_downloadButton setTitle:@"Start Download" forState:UIControlStateNormal];
        [_downloadButton setTitleColor:[UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
        
        [_downloadButton removeTarget:self action:@selector(abortDownload:) forControlEvents:UIControlEventTouchUpInside];
        isDownload = NO;
        
        [_downloadButton addTarget:self action:@selector(startDownload:) forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void) addParentObject:(UIViewController*)parent withSelector:(SEL)selector {
    _parent = parent;
    _selector = selector;
}

- (IBAction)cancelVideoLoading:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)addVideoLoading:(id)sender {
    if(_parent != nil && _selector != nil) {
        if(receiveData != nil) { //Donload data is not nil
            if(![self saveVideoToDocuments]){
                return;
            }
        }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              movieName, @"name",
                              dlDate, @"date",
                              filePath, @"file",
                              thumbnailPath, @"thumbnail",
                              nil];
        [_parent performSelector:_selector withObject:dict];
#pragma clang diagnostic pop
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (BOOL)saveVideoToDocuments {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0];
    NSString *movieDir = [documents stringByAppendingPathComponent:movieRawDir];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSDate* now = [NSDate date];
    NSDateFormatter* uniqueForm =[[NSDateFormatter alloc] init];
    NSDateFormatter* dateForm =[[NSDateFormatter alloc] init];
    [uniqueForm setDateFormat:@"_YYMMdd_hhmmss."];
    [dateForm setDateFormat:@"YYYY-MM-dd"];
    NSString* uniqueString = [uniqueForm stringFromDate:now];
    dlDate = [dateForm stringFromDate:now];
    
    uniqueName = [[movieName stringByDeletingPathExtension] stringByAppendingString: uniqueString];
    
    uniqueThumbnail = [uniqueName stringByAppendingString:@"png"];
    
    uniqueName = [uniqueName stringByAppendingString:[movieName pathExtension]];
    NSString* file = [@"/" stringByAppendingString:uniqueName];
    NSString* thumbnailFile = [@"/" stringByAppendingString:uniqueThumbnail];
    
    BOOL created = [fileManager createDirectoryAtPath:movieDir
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:&error];
    if (!created) {
        NSLog(@"failed to create directory. reason is %@ - %@", error, error.userInfo);
        return false;
    }
    if (movieName == nil) {
        NSLog(@"failed to save movie. The movie name is null");
        return false;
    }

    thumbnailPath = [movieDir stringByAppendingString:thumbnailFile];
    NSData *data = UIImagePNGRepresentation(_thumbnail.image);
    if(data != nil) {
        bool result = [data writeToFile:thumbnailPath atomically:NO];
        if(!result) {
            NSLog(@"failed to save thumbnail image.");
            return false;
        }
    }
    
    filePath = [movieDir stringByAppendingString:file];
    BOOL success = [fileManager createFileAtPath:filePath contents:receiveData attributes:nil];
    if (!success) {
        NSLog(@"failed to save movie. reason is %@ - %@", error, error.userInfo);
        return false;
    }
    
    BOOL deleted = [fileManager removeItemAtPath:cachePath error:&error];
    if(!deleted) {
        NSLog(@"failed to delete movie file. reason is %@ - %@", error, error.userInfo);
    } else {
        NSLog(@"Deleted temporary file. - %@", cachePath);
    }
    
    //save success
    return true;
}

- (IBAction)actionDidEndOnExit:(id)sender {
    UITextField* textField = (UITextField*)sender;
    [textField resignFirstResponder];
}

-(void)onSingleTap:(UITapGestureRecognizer *)recognizer {
    [self.textField resignFirstResponder];
}

-(BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == _singleTap) {
        if (_textField.isFirstResponder) {
            return YES;
        } else {
            return NO;
        }
    }
    return YES;
}

#pragma mark - NSURLConnectionDelegate
// receive response
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    int statusCode = [((NSHTTPURLResponse *)response) statusCode];
    NSLog(@"statusCode = %d", statusCode);
    
    if(statusCode >= 400) {
        _progressLabel.text = [@"HTTP Status: " stringByAppendingString:[NSString stringWithFormat:@"%d", statusCode]];
        _progressLabel.textColor = [UIColor redColor];
        [connection cancel];
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        return;
    }
    
    receiveData = [NSMutableData data];
    totalBytes = [response expectedContentLength];
    loadedBytes = 0;
    
    [self showProgress];
}

-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSHTTPURLResponse *)redirectResponse
{
    if(redirectResponse) {
        NSLog(@"HTTP Redirect to: %@", [[request URL] absoluteString]);
    }
    return request;
}

// reseive data
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [receiveData appendData:data];
    loadedBytes += [data length];
    
    if(!isDownload) {
        [connection cancel];
        [[UIApplication sharedApplication] endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        return;
    }
    
    [self showProgress];
}

// receive complete
- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self showProgressDone];
    
    [[UIApplication sharedApplication] endBackgroundTask:bgTask];
    bgTask = UIBackgroundTaskInvalid;
}

// connection error
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
        NSLog(@"Download Error!");
        _progressLabel.text = @"Download Error";
        _progressLabel.textColor = [UIColor redColor];
        [self abortDownload:nil];
}

//progress

- (void)showProgress {
    float rate = ((float)loadedBytes)/((float)totalBytes);
    int per = rate*100;
    
    [_progressView setProgress:rate];
    
    //UIApplication *app = [UIApplication sharedApplication];
    //app.applicationIconBadgeNumber = per;
    
    //NSLog(@"Now Loading... [%ld/%ld]", loadedBytes, totalBytes);
}

- (void)showProgressDone {
    [self.progressView setProgress:1];
    _progressLabel.text = @"Download Complete!";
    _progressLabel.textColor = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
    [self abortDownload:nil];
    _addVideoButton.enabled = true;
    _downloadButton.enabled = false;
    
    UIApplication *app = [UIApplication sharedApplication];
    app.applicationIconBadgeNumber = 0;
    NSLog(@"Loading Done!");
    isDownloadComplete = true;
    [self generateThumbNail];
    
    [self notificateDone];
}

- (void)notificateDone {
    UILocalNotification *localNotif = [[UILocalNotification alloc] init];
    
    localNotif.fireDate = [[NSDate date] dateByAddingTimeInterval:5];
    localNotif.timeZone = [NSTimeZone defaultTimeZone];
    
    localNotif.alertBody = [NSString stringWithFormat:@"Download Complete!"];
    [localNotif setSoundName:UILocalNotificationDefaultSoundName];
    localNotif.alertAction = @"Open";
    
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotif];
}

- (IBAction)regenerateThumbnail:(id)sender {
    [self generateThumbNail];
}

- (void) generateThumbNail {
    if(!isDownloadComplete) {
        return;
    }
    if(cachePath == nil) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *path = [paths objectAtIndex:0];
        NSString *file = [path stringByAppendingPathComponent:movieName];
        [receiveData writeToFile:file atomically:NO];
        cachePath = [NSString stringWithString:file];
    }
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:cachePath] options:nil];
    
    if([asset tracksWithMediaCharacteristic:AVMediaTypeVideo]) {
        AVAssetImageGenerator *imageGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        [imageGen setAppliesPreferredTrackTransform:YES];
        Float64 durationSeconds = CMTimeGetSeconds([asset duration]);
        
        float num = (float)(arc4random() % 100) / 100.0;
        CMTime point = CMTimeMakeWithSeconds(durationSeconds*num, 600);
        NSError* error = nil;
        CMTime actualTime;
        
        CGImageRef imageRef = [imageGen copyCGImageAtTime:point actualTime:&actualTime error:&error];
        
        if (imageRef != NULL) {
            UIImage* srcImage = [[UIImage alloc]initWithCGImage:imageRef];
            
            UIImage* cropImage = [self imageByCropping:srcImage
                           toRect:CGRectMake(0, 0, srcImage.size.width/2, srcImage.size.height)];
            UIImage* scaledImage = [self resizedImage:cropImage width:160 height:160];
            
            CGImageRelease(imageRef);
            _thumbnail.image = scaledImage;
            return;
        }
        
    }
}

- (UIImage*)imageByCropping:(UIImage *)imageToCrop toRect:(CGRect)rect
{
    CGImageRef imageRef = CGImageCreateWithImageInRect([imageToCrop CGImage], rect);
    UIImage *cropped =[UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return cropped;
}

- (UIImage *)resizedImage:(UIImage *)image width:(CGFloat)width height:(CGFloat)height
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, [[UIScreen mainScreen] scale]);
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    
    [image drawInRect:CGRectMake(0.0, 0.0, width, height)];
    
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return resizedImage;
}

@end

