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
@property (nonatomic) NSUUID *identifier;
@property (nonatomic) pid_t pid;
@property (nonatomic) NSURL *file;
@property (nonatomic) FAFAccessType accessType;
@end


typedef NS_ENUM(NSUInteger, FAFResolutionType) {
    FAFResolutionTypeReadwrite,
    FAFResolutionTypeReadonly,
    FAFResolutionTypeNoaccess
};
typedef void(^FAFResolutionHandler)(const FAFResolutionType resolution);

@protocol FAFResolutionDelegate
- (void)resolveFileAccessRequest:(FAFRequest *const)request withResolutionHandler:(FAFResolutionHandler)handler;
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
