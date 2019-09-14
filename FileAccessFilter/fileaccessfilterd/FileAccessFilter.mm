//
//  FileAccessFilter.m
//  fileaccessfilterd
//
//  Created by Alkenso on 9/13/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

#import "FileAccessFilter.h"

#import <FSGuardLib.h>
#import <IOKit/kext/KextManager.h>

@interface FileAccessFilter () <FSGuardClientDelegate>
@property (nullable, atomic, strong) id<FAFResolutionDelegate> delegate;
@property (nullable, atomic, strong) FSGuardClient *fsGuard;
@end

@implementation FileAccessFilter

- (void)loadKEXT:(NSURL *const)kext identifier:(NSString *const)bundleIdentifier completion:(void (^)(const NSInteger))handler
{
    NSArray<NSString *> *const infoKeys = @[(__bridge NSString *)kCFBundleVersionKey];
    NSDictionary *const loadedKEXTInfo = (NSDictionary *)CFBridgingRelease(KextManagerCopyLoadedKextInfo((__bridge CFArrayRef)(@[bundleIdentifier]), (__bridge CFArrayRef)(infoKeys)));
    if (loadedKEXTInfo[loadedKEXTInfo])
    {
        handler(0);
        return;
    }
    
    NSURL *const copiedKEXT = [self copyKEXT:kext];
    if (!copiedKEXT)
    {
        handler(kIOReturnError);
        return;
    }
    
    const OSReturn result = KextManagerLoadKextWithURL((__bridge CFURLRef)copiedKEXT, (__bridge CFArrayRef)(@[]));
    handler(result);
}

- (nullable NSURL *)copyKEXT:(NSURL *const)kext
{
    NSFileManager *const fileManager = NSFileManager.defaultManager;
    
    NSURL *const tmpDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    NSURL *const tmpKEXTLocation = [[tmpDirectory URLByAppendingPathComponent:NSBundle.mainBundle.bundleIdentifier] URLByAppendingPathComponent:kext.lastPathComponent];
    
    if (![fileManager createDirectoryAtURL:tmpKEXTLocation.URLByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL])
    {
        return nil;
    }
    
    if ([fileManager fileExistsAtPath:tmpKEXTLocation.path] &&
        ![fileManager removeItemAtURL:tmpKEXTLocation error:NULL])
    {
        return nil;
    }
    
    if (![fileManager copyItemAtURL:kext toURL:tmpKEXTLocation error:NULL])
    {
        return nil;
    }
    
    [self setupPermissionsRecursive:tmpKEXTLocation];
    
    return tmpKEXTLocation;
}

- (void)setupPermissionsRecursive:(NSURL *const)location
{
    NSFileManager *const fileManager = NSFileManager.defaultManager;
    NSDirectoryEnumerator<NSString *> *const enumerator = [fileManager enumeratorAtPath:location.path];
    while (NSString *const file = [enumerator nextObject])
    {
        chown([location URLByAppendingPathComponent:file].fileSystemRepresentation, 0, 0);
    }
    
    chown(location.fileSystemRepresentation, 0, 0);
}

- (void)registerResolutionDelegate:(id<FAFResolutionDelegate> const _Nullable)delegate completion:(void (^)(const BOOL))handler
{
    self.delegate = delegate;
    if (delegate)
    {
        self.fsGuard = [[FSGuardClient alloc] init];
        self.fsGuard.delegate = self;

        __weak typeof(self) weakSelf = self;
        [NSThread detachNewThreadWithBlock:^{
            [weakSelf.fsGuard start];
        }];
    }
    else
    {
        [self.fsGuard stop];
        self.fsGuard = nil;
    }
    
    handler(YES);
}

- (void)resolveRequest:(const FSGuardRequest *)request withCompletion:(void (^)(BOOL))completion
{
    id<FAFResolutionDelegate> const delegate = self.delegate;
    if (!delegate)
    {
        completion(YES);
        return;
    }
    
    FAFRequest *const faRequest = [[FAFRequest alloc] init];
    faRequest.file = [NSURL fileURLWithPath:@(request->filePath)];
    faRequest.pid = request->pid;
    faRequest.accessType = (FAFAccessType)request->action;
    
    [delegate resolveFileAccessRequest:faRequest withHandler:^(const BOOL allow) {
        completion(allow);
    }];
}

@end
