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
    
    const OSReturn result = KextManagerLoadKextWithURL((__bridge CFURLRef)kext, (__bridge CFArrayRef)(@[]));
    handler(result);
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

- (void)resolveRequest:(FSGuardRequest *)request withCompletion:(void (^)(BOOL))completion
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
    
    [delegate resolveFileAccessRequest:faRequest withResolutionHandler:^(const FAFResolutionType resolution) {
        completion(YES);
    }];
}

@end
