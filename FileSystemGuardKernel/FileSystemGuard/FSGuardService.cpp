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

#include <sys/proc.h>

#define super IOService

OSDefineMetaClassAndStructors(FSGuardService, IOService)

constexpr pid_t kInvalidDaemonPid = -1;

static bool InitFSGuardRequest(kauth_action_t action, vnode_t vp, FSGuardRequest &request)
{
    request.rid = &request;

    if (KAUTH_VNODE_READ_DATA | action)
    {
        request.action = FSGuardAction::Read;
    }
    else if (KAUTH_VNODE_WRITE_DATA | action)
    {
        request.action = FSGuardAction::Write;
    }
    else if (KAUTH_VNODE_EXECUTE | action)
    {
        request.action = FSGuardAction::Execute;
    }
    else
    {
        return false;
    }

    int length = PATH_MAX;
    return 0 == vn_getpath(vp, request.filePath, &length);
}

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

    m_daemonPid = kInvalidDaemonPid;

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
        m_daemonPid = proc_selfpid();
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

        m_daemonPid = kInvalidDaemonPid;
    }

    super::handleClose(forClient, options);
}

void FSGuardService::free()
{
    if (m_kauthCallsLock)
    {
        IORWLockFree(m_kauthCallsLock);
        m_kauthCallsLock = nullptr;
    }

    super::free();
}

int FSGuardService::processVnodeScope(kauth_action_t action, vfs_context_t context, vnode_t vp)
{
    //
    // NOTE: pass through all daemon requests
    //
    if (m_daemonPid == proc_selfpid())
    {
        return KAUTH_RESULT_DEFER;
    }

    if (!vnode_isreg(vp) && !vnode_isdir(vp))
    {
        return KAUTH_RESULT_DEFER;
    }

    FSGuardRequestInternal request = {};
    if (!InitFSGuardRequest(action, vp, request.request))
    {
        return KAUTH_RESULT_DEFER;
    }

    RWLockGuard lock(m_userClientLock, RWLockGuardType::Read);
    if (!m_userClient)
    {
        return KAUTH_RESULT_DEFER;
    }

    m_userClient->sendFSGuardRequest(request);
    if (!request.allow)
    {
        return KAUTH_RESULT_DENY;
    }

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
