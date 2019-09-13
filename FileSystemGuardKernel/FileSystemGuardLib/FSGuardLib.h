//
//  FSGuardClient.h
//  FileSystemGuardLib
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "FSGuardUserClientInterface.h"

NS_ASSUME_NONNULL_BEGIN

@protocol FSGuardClientDelegate

- (void) resolveRequest:(FSGuardRequest *)request
         withCompletion:(void (^)(BOOL))completion;

@end

@interface FSGuardClient : NSObject

@property (atomic, weak) NSObject<FSGuardClientDelegate> *delegate;

- (instancetype)init;
- (BOOL)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
