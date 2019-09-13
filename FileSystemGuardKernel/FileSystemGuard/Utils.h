//
//  Utils.h
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 c0de1n. All rights reserved.
//

#ifndef Utils_h
#define Utils_h

#include <IOKit/IOLib.h>
#include <IOKit/IOLocks.h>

//
// NOTE: in DEBUG build raise a breakpoint for failed assert condition
//       system will wait for debugger to attach
//
#ifdef DEBUG
#define DEBUG_BREAK(cond) do { if ((cond)) { __asm__ volatile("int $0x3"); } } while (0)
#define DEBUG_NANOMITE(uniq) static bool s_ ## uniq = true; DEBUG_BREAK(s_ ## uniq)
#else
#define DEBUG_BREAK(cond) (void)0
#define DEBUG_NANOMITE(v) (void)0
#endif

#define DEBUG_ASSERT(cond) DEBUG_BREAK(!(cond))

//
// NOTE: continuously try to allocate memory with sleep between failures
//
void * MallocNoFail(vm_size_t size);

template <typename Type>
static Type * MallocTypeNoFail(vm_size_t size = sizeof(Type))
{
    return static_cast<Type *>(MallocNoFail(size));
}

class LockGuard
{
public:
    LockGuard(IOLock *lock)
    : m_lock(lock)
    {
        DEBUG_ASSERT(nullptr != m_lock);

        IOLockLock(m_lock);
    }

    ~LockGuard()
    {
        IOLockUnlock(m_lock);
    }

private:
    IOLock *m_lock;
};

enum class RWLockGuardType
{
    Read  = 1,
    Write = 2
};

class RWLockGuard
{
public:
    RWLockGuard(IORWLock *lock, RWLockGuardType lockType)
    : m_lock(lock)
    {
        DEBUG_ASSERT(nullptr != m_lock);

        if (RWLockGuardType::Read == lockType)
        {
            IORWLockRead(m_lock);
        }
        else if (RWLockGuardType::Write == lockType)
        {
            IORWLockWrite(m_lock);
        }
        else
        {
            DEBUG_ASSERT(false);
        }
    }

    ~RWLockGuard()
    {
        IORWLockUnlock(m_lock);
    }

private:
    IORWLock *m_lock;

};

#endif /* Utils_h */
