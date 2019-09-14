//
//  FSGuardClient.m
//  FileSystemGuardLib
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#import "FSGuardLib.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/IODataQueueShared.h>
#include <IOKit/IODataQueueClient.h>

#include <mach/mach.h>

#include "FSGuardUserClientInterface.h"

@interface FSGuardClient ()

@property (nonatomic) io_connect_t       connection;
@property (nonatomic) mach_port_t        dataQueuePort;
@property (nonatomic) IODataQueueMemory *queueMappedMemory;
@property (nonatomic) vm_size_t          queueMappedMemorySize;
@property (nonatomic) BOOL               dataQueueLoopStop;
@property (nonatomic) NSThread          *dataQueueLoopThread;

@end

@implementation FSGuardClient

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        _delegate = nil;
        _connection = IO_OBJECT_NULL;
        _dataQueuePort = MACH_PORT_NULL;
        _queueMappedMemory = NULL;
        _queueMappedMemorySize = 0;
        _dataQueueLoopStop = NO;
    }

    return self;
}

- (BOOL)start
{
    if (![self openDriverConnection])
    {
        NSLog(@"Failed to open driver connection");
        return NO;
    }

    if (![self createDataQueuePort])
    {
        NSLog(@"Failed to create data queue");
        return NO;
    }

    [self startDataQueueLoop];

    return YES;
}

- (void)stop
{
    self.dataQueueLoopStop = YES;
}

- (BOOL)openDriverConnection
{
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(kFSGuardServiceClass));
    if (!service)
    {
        NSLog(@"IOServiceGetMatchingService failed - service %s", kFSGuardServiceClass);

        return false;
    }

    io_connect_t connection = IO_OBJECT_NULL;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &connection);

    IOObjectRelease(service);

    if (kIOReturnSuccess != kr)
    {
        NSLog(@"IOServiceOpen - %s", mach_error_string(kr));

        return false;
    }

    self.connection = connection;

    return true;
}

- (BOOL)createDataQueuePort
{
    self.dataQueuePort = IODataQueueAllocateNotificationPort();

    if (!self.dataQueuePort)
    {
        NSLog(@"IODataQueueAllocateNotificationPort failed");

        return false;
    }

    kern_return_t kr = IOConnectSetNotificationPort(self.connection, kFGNotificationPortQueue, self.dataQueuePort, 0);

    if (kIOReturnSuccess != kr)
    {
        NSLog(@"IOConnectSetNotificationPort failed - %s", mach_error_string(kr));

        mach_port_destroy(mach_task_self(), self.dataQueuePort);
        return false;
    }

    mach_vm_address_t address = 0;
    mach_vm_size_t size = 0;

    kr = IOConnectMapMemory(self.connection, kFGMemoryMapQueue, mach_task_self(), &address, &size, kIOMapAnywhere);
    if (kIOReturnSuccess != kr)
    {
        NSLog(@"IOConnectMapMemory failed - %s", mach_error_string(kr));

        mach_port_destroy(mach_task_self(), self.dataQueuePort);
        return NO;
    }

    self.queueMappedMemory = (IODataQueueMemory *)address;
    self.queueMappedMemorySize = size;

    return YES;
}

- (void)startDataQueueLoop
{
    do
    {
        while (!self.dataQueueLoopStop && IODataQueueDataAvailable(self.queueMappedMemory))
        {
            FSGuardRequest request = {};
            uint32_t size = sizeof(FSGuardRequest);

            IOReturn ioret = IODataQueueDequeue(self.queueMappedMemory, &request, &size);
            if (kIOReturnSuccess != ioret)
            {
                NSLog(@"Invalid dequeue");
                continue;
            }
            
            void* rid = request.rid;
            if (sizeof(FSGuardRequest) != size)
            {
                NSLog(@"Invalid request size");
                [self sendFSGuardResponse:YES forRequset:rid];
                continue;
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                id<FSGuardClientDelegate> const delegate = self.delegate;
                if (delegate)
                {
                    [delegate resolveRequest:&request withCompletion:^(BOOL allow) {
                        [self sendFSGuardResponse:allow forRequset:rid];
                    }];
                }
                else
                {
                    [self sendFSGuardResponse:YES forRequset:rid];
                }
            });
        }
    } while (!self.dataQueueLoopStop && (kIOReturnSuccess == IODataQueueWaitForAvailableData(self.queueMappedMemory, self.dataQueuePort)));

    if (NULL != self.queueMappedMemory)
    {
        IOConnectUnmapMemory(self.connection, kFGMemoryMapQueue, mach_task_self(), reinterpret_cast<mach_vm_address_t>(self.queueMappedMemory));
        self.queueMappedMemory = NULL;
        self.queueMappedMemorySize = 0;
    }

    if (MACH_PORT_NULL != self.dataQueuePort)
    {
        kern_return_t kr = mach_port_destroy(mach_task_self(), self.dataQueuePort);
        if (KERN_SUCCESS != kr)
        {
            NSLog(@"mach_port_destroy failed - %s", mach_error_string(kr));
        }

        self.dataQueuePort = MACH_PORT_NULL;
    }
}

- (void)sendFSGuardResponse:(BOOL)allow forRequset:(void *)rid
{
    FSGuardResponse response;
    response.rid = rid;
    response.allow = allow;

    kern_return_t kr = IOConnectCallStructMethod(self.connection,
                                                 static_cast<uint32_t>(FSGuardMethod::PostFSGuardResponse),
                                                 &response, sizeof(FSGuardResponse), nullptr, nullptr);

    if (KERN_SUCCESS != kr)
    {
        NSLog(@"IOConnectCallStructMethod failed -- %016x -- %s", kr, mach_error_string(kr));
    }
}

@end
