//
//  FSGuardUserClient.cpp
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#include "FSGuardUserClient.h"
#include "Utils.h"

#define super IOUserClient

OSDefineMetaClassAndStructors(FSGuardUserClient, IOUserClient)

constexpr UInt32 kMaxQueuedTask = 1024;

static AbsoluteTime GetDefaultTimeout()
{
    AbsoluteTime deadline = 0;

    clock_interval_to_deadline(15, kSecondScale, &deadline);

    return deadline;
}

bool FSGuardUserClient::initWithTask(task_t owningTask, void *securityToken, UInt32 type, OSDictionary *properties)
{
    if (!super::initWithTask(owningTask, securityToken, type, properties))
    {
        return false;
    }

    if (kIOReturnSuccess != clientHasPrivilege(securityToken, kIOClientPrivilegeAdministrator))
    {
        return false;
    }

    m_dataQueue = IOSharedDataQueue::withEntries(kMaxQueuedTask, sizeof(FSGuardRequest));
    if (!m_dataQueue)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    m_dataQueueMemory = m_dataQueue->getMemoryDescriptor();
    if (!m_dataQueueMemory)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    m_waitListLock = IOLockAlloc();
    if (!m_waitListLock)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    m_requestWaitList = WaitList::waitList();
    if (!m_requestWaitList)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    return true;
}

bool FSGuardUserClient::start(IOService *provider)
{
    bool result = super::start(provider);
    if (!result)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    m_provider = OSDynamicCast(FSGuardService, provider);
    if (!m_provider)
    {
        return false;
    }

    if (m_provider->isOpen(this) || !m_provider->open(this))
    {
        return false;
    }

    return true;
}

void FSGuardUserClient::stop(IOService *provider)
{
    if (m_provider->isOpen(this))
    {
        m_provider->close(this);
    }

    super::stop(provider);
}

IOReturn FSGuardUserClient::externalMethod(uint32_t selector,
                                           IOExternalMethodArguments *arguments,
                                           IOExternalMethodDispatch *dispatch,
                                           OSObject *target,
                                           void *reference)
{
    IOExternalMethodDispatch methods[static_cast<int>(FSGuardMethod::Count)] =
    {
        // FSGuardMethod::PostFSGuardResponse
        {
            OSMemberFunctionCast(IOExternalMethodAction, this, &FSGuardUserClient::extPostFSGuardResponse),
            0,
            sizeof(FSGuardResponse),
            0,
            0
        }
    };

    IOReturn result = kIOReturnSuccess;

    if (selector < static_cast<int>(FSGuardMethod::Count))
    {
        dispatch = &methods[selector];

        if (!target)
        {
            target = this;
        }

        if (m_provider && !isInactive())
        {
            //
            // NOTE: user client should be open for all external methods
            //
            if (!m_provider->isOpen(this))
            {
                result = kIOReturnNotOpen;
            }
        }
        else
        {
            result = kIOReturnNotAttached;
        }

        if (kIOReturnSuccess == result)
        {
            result = super::externalMethod(selector, arguments, dispatch, target, reference);
        }
    }
    else
    {
        result = kIOReturnUnsupported;
    }

    return result;
}

IOReturn FSGuardUserClient::clientClose()
{
    //
    // NOTE: for case if client did not call IOServiceClose
    //       e.g. daemon crashed, killed or exit
    //

    bool result = terminate();

    return result ? kIOReturnSuccess : kIOReturnError;
}

bool FSGuardUserClient::didTerminate(IOService *provider, IOOptionBits options, bool *defer)
{
    //
    // NOTE: for case if kextunload requested asynchronously without IOServiceClose
    //

    if (m_provider->isOpen(this))
    {
        m_provider->close(this);
    }

    return super::didTerminate(provider, options, defer);
}

IOReturn FSGuardUserClient::registerNotificationPort(mach_port_t port, UInt32 type, UInt32 __unused refCon)
{
    if (MACH_PORT_NULL == port)
    {
        return kIOReturnBadArgument;
    }

    switch (type)
    {
        case kFGNotificationPortQueue:
            m_dataQueue->setNotificationPort(port);
            return kIOReturnSuccess;
    }

    return kIOReturnUnsupported;
}

IOReturn FSGuardUserClient::clientMemoryForType(UInt32 type, IOOptionBits *options, IOMemoryDescriptor **memory)
{
    switch (type)
    {
        case kFGMemoryMapQueue:
            *options = 0;
            if (!m_dataQueueMemory)
            {
                return kIOReturnNoMemory;
            }

            //
            // NOTE: this reference will be released upper on the stack
            //       in IOUserClient::mapClientMemory64
            //
            m_dataQueueMemory->retain();
            *memory = m_dataQueueMemory;

            return kIOReturnSuccess;
    }

    return kIOReturnUnsupported;
}

void FSGuardUserClient::sendFSGuardRequest(FSGuardRequestInternal &request)
{
    LockGuard lock(m_waitListLock);

    m_requestWaitList->add(request.request.rid);

    //
    // NOTE: infinite loop until queue have free slot for message
    //
    while (!m_dataQueue->enqueue(&request.request, sizeof(FSGuardRequest)))
    {
        IOSleep(1);
    }

    int waitResult = THREAD_RESTART;

    while (THREAD_RESTART == waitResult)
    {
        waitResult = m_requestWaitList->wait(request.request.rid, THREAD_ABORTSAFE, m_waitListLock, GetDefaultTimeout());
    }

    return;
}

IOReturn FSGuardUserClient::extPostFSGuardResponse(__unused void *reference, IOExternalMethodArguments *arguments)
{
    LockGuard lock(m_waitListLock);

    const FSGuardResponse *response = static_cast<const FSGuardResponse *>(arguments->structureInput);

    if (!m_requestWaitList->contains(response->rid))
    {
        return kIOReturnBadArgument;
    }

    FSGuardRequestInternal *request = reinterpret_cast<FSGuardRequestInternal *>(response->rid);
    request->allow = response->allow;

    m_requestWaitList->remove(response->rid);
    m_requestWaitList->signal(response->rid, m_waitListLock);

    return kIOReturnSuccess;
}

void FSGuardUserClient::free()
{
    if (m_requestWaitList)
    {
        m_requestWaitList->release();
        m_requestWaitList = nullptr;
    }

    if (m_waitListLock)
    {
        IOLockFree(m_waitListLock);
        m_waitListLock = nullptr;
    }

    if (m_dataQueueMemory)
    {
        m_dataQueueMemory->release();
        m_dataQueueMemory = nullptr;
    }

    if (m_dataQueue)
    {
        m_dataQueue->release();
        m_dataQueue = nullptr;
    }

    super::free();
}

