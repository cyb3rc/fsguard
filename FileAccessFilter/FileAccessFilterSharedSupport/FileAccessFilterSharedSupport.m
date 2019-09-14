//
//  FileAccessFilterSharedSupport.m
//  FileAccessFilterSharedSupport
//
//  Created by Volodymyr Vashurkin on 9/13/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

#import "FileAccessFilterSharedSupport.h"

NSString *const FAFFileAccessServiceMachName = @"com.alkenso.fileaccessfilter.fileaccess";

@interface NSXPCInterface (MSV)
- (void)addClasses:(NSArray *const)classes forSelector:(SEL)selector argumentIndex:(const NSUInteger)argumentIndex ofReply:(const BOOL)ofReply;
@end


NSXPCInterface * FAFCreateXPCFileAccessFilterInterface(void)
{
    NSXPCInterface *const delegateInterface = [NSXPCInterface interfaceWithProtocol:@protocol(FAFResolutionDelegate)];
    [delegateInterface addClasses:@[FAFRequest.class]
              forSelector:@selector(resolveFileAccessRequest:withHandler:)
            argumentIndex:0
                  ofReply:NO];
    
    NSXPCInterface *const interface = [NSXPCInterface interfaceWithProtocol:@protocol(FAFPrivilegedHelper)];
    [interface setInterface:delegateInterface
                forSelector:@selector(registerResolutionDelegate:completion:)
              argumentIndex:0
                    ofReply:NO];
    
    return interface;
}


@implementation FAFRequest

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self)
    {
        _pid = [aDecoder decodeIntForKey:NSStringFromSelector(@selector(pid))];
        _file = [aDecoder decodeObjectOfClass:NSURL.class forKey:NSStringFromSelector(@selector(file))];
        _accessType = [aDecoder decodeIntegerForKey:NSStringFromSelector(@selector(accessType))];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeInt:self.pid forKey:NSStringFromSelector(@selector(pid))];
    [aCoder encodeObject:self.file forKey:NSStringFromSelector(@selector(file))];
    [aCoder encodeInteger:self.accessType forKey:NSStringFromSelector(@selector(accessType))];
}

@end


@implementation NSXPCInterface (MSV)

- (void)addClasses:(NSArray *const)classes forSelector:(SEL)selector argumentIndex:(const NSUInteger)argumentIndex ofReply:(const BOOL)ofReply
{
    NSSet *const existingClasses = [self classesForSelector:selector argumentIndex:argumentIndex ofReply:ofReply];
    NSSet *const allClasses = [existingClasses setByAddingObjectsFromArray:classes];
    [self setClasses:allClasses forSelector:selector argumentIndex:argumentIndex ofReply:ofReply];
}

@end
