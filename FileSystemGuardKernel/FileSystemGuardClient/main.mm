//
//  main.m
//  FileSystemGuardClient
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FSGuardLib.h"

@interface FSGuardHandler : NSObject <FSGuardClientDelegate>
@end

@implementation FSGuardHandler

- (void) resolveRequest:(FSGuardRequest *)request
         withCompletion:(void (^)(BOOL))completion
{
    NSLog(@"%s", request->filePath);
    completion(YES);
}

@end

int main(int argc, const char * argv[])
{
    @autoreleasepool
    {
        FSGuardHandler *handler = [[FSGuardHandler alloc] init];
        FSGuardClient *client = [[FSGuardClient alloc] init];
        client.delegate = handler;

        [NSThread detachNewThreadWithBlock:^ {
            [client start];
        }];

        [[NSRunLoop mainRunLoop] run];
    }

    return 0;
}
