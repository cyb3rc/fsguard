//
//  FSGuardService.h
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/7/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#ifndef FSGuardService_h
#define FSGuardService_h

#include <IOKit/IOService.h>

#include <sys/kauth.h>
#include <sys/vnode.h>

class FSGuardUserClient;

class FSGuardService : public IOService
{
    OSDeclareDefaultStructors(FSGuardService);

public:
    virtual bool init(OSDictionary *propertyDictionary = nullptr) override;

    virtual bool start(IOService *provider) override;
    virtual void stop(IOService *provider) override;

    virtual IOReturn newUserClient(task_t owningTask,
                                   void *securityID,
                                   UInt32 type,
                                   OSDictionary *properties,
                                   IOUserClient **handler) override;

    virtual void handleClose(IOService *forClient, IOOptionBits options) override;

protected:
    virtual void free() override;

private:
    bool registerKauthListeners();
    void unregisterKauthListeners();

    int processVnodeScope(kauth_action_t action, vfs_context_t context, vnode_t vp);
    int processFileopScope(kauth_action_t action, uintptr_t arg0, uintptr_t arg1, uintptr_t arg2);

private:
    static int vnodeScopeListener(kauth_cred_t credential,
                                  void *idata,
                                  kauth_action_t action,
                                  uintptr_t arg0,
                                  uintptr_t arg1,
                                  uintptr_t arg2,
                                  uintptr_t arg3);

private:
    IORWLock          *m_kauthCallsLock;
    kauth_listener_t   m_vnodeListener;

    IORWLock          *m_userClientLock;
    FSGuardUserClient *m_userClient;
    pid_t              m_daemonPid;

};

#endif /* FSGuardService_h */
