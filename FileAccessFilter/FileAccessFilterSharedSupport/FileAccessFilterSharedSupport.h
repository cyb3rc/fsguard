//
//  FileAccessFilterSharedSupport.h
//  FileAccessFilterSharedSupport
//
//  Created by Volodymyr Vashurkin on 9/13/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const FAFFileAccessServiceMachName;

typedef NS_ENUM(NSUInteger, FAFAccessType) {
    FAFAccessTypeRead,
    FAFAccessTypeWrite,
    FAFAccessTypeExecute
};

@interface FAFRequest : NSObject<NSSecureCoding>
@property (nonatomic) pid_t pid;
@property (nonatomic) NSURL *file;
@property (nonatomic) FAFAccessType accessType;
@end


@protocol FAFResolutionDelegate
- (void)resolveFileAccessRequest:(FAFRequest *const)request withHandler:(void(^)(const BOOL allow))handler;
@end


@protocol FAFFileAccessFilter
- (void)registerResolutionDelegate:(id<FAFResolutionDelegate> const _Nullable)delegate completion:(void(^)(const BOOL success))handler;
@end


@protocol FAFKEXTLoader
- (void)loadKEXT:(NSURL *const)kext identifier:(NSString *const)bundleIdentifier completion:(void (^)(const NSInteger))handler;
@end

@protocol FAFPrivilegedHelper <FAFFileAccessFilter, FAFKEXTLoader>
@end


NSXPCInterface * FAFCreateXPCFileAccessFilterInterface(void);

NS_ASSUME_NONNULL_END
