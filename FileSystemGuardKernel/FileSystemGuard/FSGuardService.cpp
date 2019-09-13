//
//  FSGuardService.cpp
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/7/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#include "FSGuardService.h"
#include "FSGuardUserClient.h"
#include "Utils.h"

#define super IOService

OSDefineMetaClassAndStructors(FSGuardService, IOService)

bool FSGuardService::init(OSDictionary *propertyDictionary)
{
    if (!super::init(propertyDictionary))
    {
        return false;
    }

    m_vnodeListener = nullptr;

    m_kauthCallsLock = IORWLockAlloc();
    if (!m_kauthCallsLock)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    m_userClientLock = IORWLockAlloc();
    if (!m_userClientLock)
    {
        DEBUG_ASSERT(false);
        return false;
    }

    return true;
}

bool FSGuardService::start(IOService *provider)
{
    if (!super::start(provider))
    {
        return false;
    }

    registerService();

    if (!m_vnodeListener)
    {
        m_vnodeListener = kauth_listen_scope(KAUTH_SCOPE_VNODE, vnodeScopeListener, this);
        if (!m_vnodeListener)
        {
            DEBUG_ASSERT(false);
            return false;
        }
    }

    return true;
}

void FSGuardService::stop(IOService *provider)
{
    if (m_vnodeListener)
    {
        kauth_unlisten_scope(m_vnodeListener);
        m_vnodeListener = nullptr;
    }

    //
    // NOTE: Wait for pending listener callbacks
    //
    RWLockGuard lock(m_kauthCallsLock, RWLockGuardType::Write);
}

IOReturn FSGuardService::newUserClient(task_t owningTask,
                                       void *securityID,
                                       UInt32 type,
                                       OSDictionary *properties,
                                       IOUserClient **handler)
{
    RWLockGuard lockGuard(m_userClientLock, RWLockGuardType::Write);

    if (m_userClient)
    {
        return kIOReturnExclusiveAccess;
    }

    IOReturn result = super::newUserClient(owningTask, securityID, type, properties, handler);

    if (kIOReturnSuccess == result)
    {
        m_userClient = OSDynamicCast(FSGuardUserClient, *handler);
    }

    return result;
}

void FSGuardService::handleClose(IOService *forClient, IOOptionBits options)
{
    RWLockGuard lockGuard(m_userClientLock, RWLockGuardType::Write);

    if (forClient == m_userClient)
    {
        if (m_userClient)
        {
            m_userClient = nullptr;
        }
    }

    super::handleClose(forClient, options);
}

int FSGuardService::processVnodeScope(kauth_action_t action, vfs_context_t context, vnode_t vp)
{
    return KAUTH_RESULT_DEFER;
}

int FSGuardService::vnodeScopeListener(kauth_cred_t credential,
                                           void *idata,
                                           kauth_action_t action,
                                           uintptr_t arg0,
                                           uintptr_t arg1,
                                           uintptr_t __unused arg2,
                                           uintptr_t __unused arg3)
{
    FSGuardService *fileSystemGuard = static_cast<FSGuardService *>(idata);

    //
    // NOTE: Take read lock to monitor KAuth listener lifetime
    //
    RWLockGuard lock(fileSystemGuard->m_kauthCallsLock, RWLockGuardType::Read);

    return fileSystemGuard->processVnodeScope(action,
                                              reinterpret_cast<vfs_context_t>(arg0),
                                              reinterpret_cast<vnode_t>(arg1));
}
