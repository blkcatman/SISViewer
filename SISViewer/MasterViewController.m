//
//  MasterViewController.m
//  SISViewer
//
//  Created by Tatsuro Matsubara on 2014/11/30.
//  Copyright (c) 2014年 blkcatman. All rights reserved.
//

#import "MasterViewController.h"
#import "VideoLoaderViewController.h"
#import "ViewController.h"

@interface MasterViewController ()

@property NSMutableArray *objects;
@property NSMutableArray *movieDictArray;

@end

@implementation MasterViewController {
    NSString *movieRawDir, *jsonName, *jsonPath, *tableMovieFilePath;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    movieRawDir = @"movies";
    jsonName = @"movielist.json";
    self.objects = [[NSMutableArray alloc] init];
    self.movieDictArray = [[NSMutableArray alloc] init];
    
    [self checkJsonFile];
#ifdef DEBUG
    /*
    NSURL* assetURL = [[NSBundle mainBundle] URLForResource:@"testmovie.mp4"withExtension:nil];
    NSString* path = [[assetURL path] substringFromIndex:8];
    NSURL* thumbnailURL = [[NSBundle mainBundle] URLForResource:@"testmovie.png"withExtension:nil];
    NSString* pathThumbnail = [[thumbnailURL path] substringFromIndex:8];
    
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"testmovie.mp4", @"name", @"0000-00-00", @"date", path, @"file", pathThumbnail, @"thumbnail", nil];
    [self.objects addObject:@"0000-00-00\ntestmovie.mp4"];
    [self.movieDictArray addObject:dict];
    */
#endif
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = self.editButtonItem;

    UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
    self.navigationItem.rightBarButtonItem = addButton;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)insertNewObject:(id)sender {
    UINavigationController* videoLoaderNavi = [self.storyboard instantiateViewControllerWithIdentifier:@"VideoLoaderViewNavi"];
    
    VideoLoaderViewController* root = (VideoLoaderViewController*)videoLoaderNavi.viewControllers[0];
    
    [root addParentObject:self withSelector:@selector(getVideoData:)];
    
    videoLoaderNavi.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:videoLoaderNavi animated:YES completion:nil];
}

- (void)getVideoData:(NSDictionary*)dictData {
    NSString* name = [dictData objectForKey:@"name"];
    NSString* date = [dictData objectForKey:@"date"];
    date = [date stringByAppendingString:@"\n"];
    [self.objects insertObject:[date stringByAppendingString:name] atIndex:0];
    [self.movieDictArray insertObject:dictData atIndex:0];
    [self saveCurrentToJsonFile];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    NSLog(@"Add to a video list. %@", name);
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if([segue.identifier isEqualToString:@"toViewer"]) {
        ViewController* view = [segue destinationViewController];
        view.movieFilePath = tableMovieFilePath;
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.objects.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary* dict = [_movieDictArray objectAtIndex:indexPath.row];
    tableMovieFilePath = [dict objectForKey:@"file"];
    [self performSegueWithIdentifier:@"toViewer" sender:nil];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    NSDate *object = self.objects[indexPath.row];
    cell.textLabel.text = [object description];
    
    NSDictionary* dict = self.movieDictArray[indexPath.row];
    NSString* thumbnailPath = [dict objectForKey:@"thumbnail"];
    
    cell.imageView.image = [UIImage imageWithContentsOfFile:thumbnailPath];
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSDictionary *dict = [self.movieDictArray objectAtIndex:indexPath.row];
        NSString *filePath = [dict objectForKey:@"file"];
        NSString *thumbnailPath = [dict objectForKey:@"thumbnail"];
        if(![fileManager fileExistsAtPath:filePath]) {
            NSLog(@"failed to delete movie file. File does not exist. path: %@", filePath);
            return;
        }
        BOOL deleted = [fileManager removeItemAtPath:filePath error:&error];
        if(!deleted) {
            NSLog(@"failed to delete movie file. reason is %@ - %@", error, error.userInfo);
        } else {
            NSString *name = [dict objectForKey:@"name"];
            NSLog(@"Deleted movie - %@", name);
        }
        deleted = [fileManager removeItemAtPath:thumbnailPath error:&error];
        if(!deleted) {
            NSLog(@"failed to delete movie thumbnail. reason is %@ - %@", error, error.userInfo);
        } else {
            NSString *name = [dict objectForKey:@"name"];
            NSLog(@"Deleted thumbnail - %@", name);
        }
        [self.objects removeObjectAtIndex:indexPath.row];
        [self.movieDictArray removeObjectAtIndex:indexPath.row];
        [self saveCurrentToJsonFile]; // resave json file
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }
}


- (BOOL)checkJsonFile {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0];
    NSString *movieDir = [documents stringByAppendingPathComponent:movieRawDir];
    
    NSString* jsonFile = [@"/" stringByAppendingString:jsonName];
    jsonPath = [movieDir stringByAppendingString:jsonFile];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:jsonPath]) {
        NSLog(@"Need new json file.");
        [self createJsonFile];
    } else {
        NSError *error = nil;
        NSInputStream *is = [[NSInputStream alloc] initWithFileAtPath:jsonPath];
        [is open];
        NSMutableArray *dictArray = [NSJSONSerialization JSONObjectWithStream:is options:0 error:&error];
        [is close];
        if(error) {
            NSLog(@"failed to load json file. reason is %@ - %@", error, error.userInfo);
            return false;
        }
        NSArray *list = [fileManager contentsOfDirectoryAtPath:movieDir error:&error];
        if(error) {
            NSLog(@"failed to search movie files. reason is %@ - %@", error, error.userInfo);
            return false;
        }
        for(int i = 0; i < dictArray.count; i++) {
            NSDictionary *dict = [dictArray objectAtIndex:i];
            NSString* name = [dict objectForKey:@"name"];
            NSString* date = [dict objectForKey:@"date"];
            NSString* file = [dict objectForKey:@"file"];
            //NSString* thumbnail = [dict objectForKey:@"thumbnail"];
            
            if(name.length > 0) {
                //BOOL isExist = [fileManager fileExistsAtPath:file];
                BOOL isExist = false;
                for(NSString *movieName in list) {
                    if([movieName isEqualToString:[file lastPathComponent]]) {
                        isExist = true;
                        break;
                    }
                }
                if(!isExist) {
                    NSLog(@"Movie file is not found:%@", file);
                    continue;
                }
                date = [date stringByAppendingString:@"\n"];
                [self.objects addObject:[date stringByAppendingString:name]];
                [self.movieDictArray addObject:dict];
                NSLog(@"Listed movie name: %@", name);
            }
        }
        [self saveCurrentToJsonFile];
        for(NSString *fileName in list) {
            if([fileName isEqualToString:jsonName]) {
                continue;
            }
            BOOL isFound = false;
            for(int i = 0; i < self.movieDictArray.count; i++) {
                NSDictionary *dict = [self.movieDictArray objectAtIndex:i];
                NSString* file = [dict objectForKey:@"file"];
                NSString* thumbnail = [dict objectForKey:@"thumbnail"];
                if([fileName isEqualToString:[file lastPathComponent]]) {
                    isFound = true;
                    break;
                } else if([fileName isEqualToString:[thumbnail lastPathComponent]]) {
                    isFound = true;
                    break;
                }
            }
            if(!isFound) {
                NSString* file = [@"/" stringByAppendingString:fileName];
                NSString* deletePath = [movieDir stringByAppendingString:file];
                [fileManager removeItemAtPath:deletePath error:&error];
                if(error) {
                    NSLog(@"failed to delete movie files. reason is %@ - %@", error, error.userInfo);
                    return false;
                }
                NSLog(@"The movie \"%@\" is deleted.", fileName);
            }
        }
        
    }
    return true;
}

- (BOOL)createJsonFile {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)objectAtIndex:0];
    NSString *movieDir = [documents stringByAppendingPathComponent:movieRawDir];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSString* file = [@"/" stringByAppendingString:jsonName];
    
    BOOL created = [fileManager createDirectoryAtPath:movieDir
                          withIntermediateDirectories:YES
                                           attributes:nil
                                                error:&error];
    if (!created) {
        NSLog(@"failed to create directory. reason is %@ - %@", error, error.userInfo);
        return false;
    }
    
    jsonPath = [movieDir stringByAppendingString:file];
    NSMutableArray *dictArray = [[NSMutableArray alloc] init];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"", @"name",
                          @"", @"date",
                          @"", @"file",
                          @"", @"thumbnail",
                          nil];
    [dictArray addObject:dict];

    NSOutputStream *os = [[NSOutputStream alloc] initToFileAtPath:jsonPath append:NO];
    [os open];
    [NSJSONSerialization writeJSONObject:dictArray toStream:os options:0 error:&error];
    [os close];
    if(error) {
        NSLog(@"failed to save json file in first. reason is %@ - %@", error, error.userInfo);
        return false;
    }
    
    NSInputStream *is = [[NSInputStream alloc] initWithFileAtPath:jsonPath];
    [is open];
    NSMutableArray *dictArray2 = [NSJSONSerialization JSONObjectWithStream:is options:0 error:&error];
    [is close];
    if(error) {
        NSLog(@"failed to load json file. reason is %@ - %@", error, error.userInfo);
        return false;
    }
    for(int i = 0; i < dictArray2.count; i++) {
        NSDictionary *d = [dictArray2 objectAtIndex:i];
        NSString* name = [d objectForKey:@"name"];
        NSString* date = [d objectForKey:@"date"];
        NSString* path = [d objectForKey:@"file"];
        NSString* thumbnail = [d objectForKey:@"thumbnail"];
        
        NSLog(@"%@, %@, %@, %@", date, name, path, thumbnail);
    }
    return true;
}

- (BOOL) saveCurrentToJsonFile {
    if(jsonPath != nil) {
        NSError* error;
        NSOutputStream *os = [[NSOutputStream alloc] initToFileAtPath:jsonPath append:NO];
        NSMutableArray* dictArray = [self.movieDictArray mutableCopy];
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"", @"name",
                              @"", @"date",
                              @"", @"file",
                              @"", @"thumbnail",
                              nil];
        [dictArray addObject:dict];
        
        [os open];
        [NSJSONSerialization writeJSONObject:dictArray toStream:os options:0 error:&error];
        [os close];
        if(error) {
            NSLog(@"failed to save json file. reason is %@ - %@", error, error.userInfo);
            return false;
        }
        
    } else {
        NSLog(@"failed to save json file. Json FilePath is nil.");
        return false;
    }
    
    return true;
}



@end
