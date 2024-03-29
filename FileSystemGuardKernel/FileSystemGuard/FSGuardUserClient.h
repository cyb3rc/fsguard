//
//  FSGuardUserClient.h
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#ifndef FSGuardUserClient_h
#define FSGuardUserClient_h

#include <IOKit/IOUserClient.h>
#include <IOKit/IOSharedDataQueue.h>

#include "FSGuardUserClientInterface.h"
#include "FSGuardService.h"
#include "WaitList.h"

class FSGuardUserClient : public IOUserClient
{
    OSDeclareDefaultStructors(FSGuardUserClient);

public:
    virtual bool initWithTask(task_t owningTask, void *securityToken, UInt32 type, OSDictionary *properties) override;

    virtual bool start(IOService *provider) override;
    virtual void stop(IOService *provider) override;

    virtual IOReturn externalMethod(uint32_t selector,
                                    IOExternalMethodArguments *arguments,
                                    IOExternalMethodDispatch *dispatch,
                                    OSObject *target,
                                    void *reference) override;

    virtual IOReturn clientClose() override;
    virtual bool didTerminate(IOService *provider, IOOptionBits options, bool *defer) override;

    //
    // NOTE: called when client calls IOConnectSetNotificationPort
    //
    virtual IOReturn registerNotificationPort(mach_port_t port, UInt32 type, UInt32 refCon) override;

    //
    // NOTE: called when client calls IOConnectMapMemory
    //
    virtual IOReturn clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor **memory) override;

    void sendFSGuardRequest(FSGuardRequestInternal &request);

protected:
    //
    // NOTE: external method
    //
    IOReturn extPostFSGuardResponse(void *reference, IOExternalMethodArguments *arguments);

    virtual void free() override;

private:
    FSGuardService     *m_provider;
    IOSharedDataQueue  *m_dataQueue;
    IOMemoryDescriptor *m_dataQueueMemory;
    IOLock             *m_waitListLock;
    WaitList           *m_requestWaitList;

};

#endif /* FSGuardUserClient_h */
