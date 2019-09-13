//
//  FileAccessFilter.m
//  fileaccessfilterd
//
//  Created by Alkenso on 9/13/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

#import "FileAccessFilter.h"

#import <IOKit/kext/KextManager.h>

@interface FileAccessFilter ()
@property (nullable, atomic, strong) id<FAFResolutionDelegate> delegate;
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
    handler(YES);
    
    [self dummyTask];
}

- (void)dummyTask
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        FAFRequest *const request = [[FAFRequest alloc] init];
        request.identifier = NSUUID.UUID;
        request.file = [NSURL fileURLWithPath:[NSString stringWithFormat:@"/qwe/%d", arc4random()]];
        request.pid = arc4random();
        request.accessType = FAFAccessTypeWrite;
        
        [self.delegate resolveFileAccessRequest:request withResolutionHandler:^(const FAFResolutionType resolution) {
            NSLog(@"FAF helper. File resolved: %@", request.file);
        }];
        
        [self dummyTask];
    });
}

@end
