//
//  main.m
//  fileaccessfilterd
//
//  Created by Volodymyr Vashurkin on 8/26/19.
//  Copyright © 2019 Volodymyr Vashurkin. All rights reserved.
//

#import "FileAccessFilter.h"

@interface XPCDelegate : NSObject <NSXPCListenerDelegate>
@property (nonatomic) FileAccessFilter *filter;
@end

@implementation XPCDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    newConnection.exportedInterface = FAFCreateXPCFileAccessFilterInterface();
    newConnection.exportedObject = [[FileAccessFilter alloc] init];
    
    [newConnection resume];
    
    return true;
}

@end


int main(int argc, const char * argv[])
{
    XPCDelegate *const delegate = [[XPCDelegate alloc] init];
    NSXPCListener *const listener = [[NSXPCListener alloc] initWithMachServiceName:FAFFileAccessServiceMachName];
    listener.delegate = delegate;
    
    [listener resume];
    
    [NSRunLoop.mainRunLoop run];
    
    return 0;
}
