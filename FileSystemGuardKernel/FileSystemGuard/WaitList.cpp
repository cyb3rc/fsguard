//
//  WaitList.cpp
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/7/18.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#include "WaitList.h"
#include "Utils.h"

#define super OSObject

OSDefineMetaClassAndStructors(WaitList, OSObject);

WaitList * WaitList::waitList()
{
    WaitList *waitList = OSTypeAlloc(WaitList);

    if (waitList && !waitList->init())
    {
        waitList->release();
        return nullptr;
    }

    return waitList;
}

void WaitList::add(void *event)
{
    WaitListEntry *waitListEntry = MallocTypeNoFail<struct WaitListEntry>();

    if (waitListEntry)
    {
        waitListEntry->event = event;

        LIST_INSERT_HEAD(&m_list, waitListEntry, entry);
    }
}

void WaitList::remove(void *event)
{
    WaitListEntry *waitListEntry = nullptr;
    WaitListEntry *tmp = nullptr;

    LIST_FOREACH_SAFE(waitListEntry, &m_list, entry, tmp)
    {
        if (waitListEntry->event == event)
        {
            LIST_REMOVE(waitListEntry, entry);
            IOFree(waitListEntry, sizeof(struct WaitListEntry));

            return;
        }
    }
}

bool WaitList::contains(void *event) const
{
    WaitListEntry *waitListEntry = nullptr;
    WaitListEntry *tmp = nullptr;

    LIST_FOREACH_SAFE(waitListEntry, &m_list, entry, tmp)
    {
        if (waitListEntry->event == event)
        {
            return true;
        }
    }

    return false;
}

wait_result_t WaitList::wait(void *event, wait_interrupt_t interruptType, IOLock *lock, AbsoluteTime timeout)
{
    if (kNoTimeout == timeout)
    {
        return IOLockSleep(lock, event, interruptType);
    }
    else
    {
        return IOLockSleepDeadline(lock, event, timeout, interruptType);
    }
}

void WaitList::signal(void *event, IOLock *lock)
{
    IOLockWakeup(lock, event, false);
}

void WaitList::removeEntries(IOLock *lock)
{
    LockGuard lockGuard(lock);

    WaitListEntry *waitListEntry = nullptr;
    WaitListEntry *tmp = nullptr;

    LIST_FOREACH_SAFE(waitListEntry, &m_list, entry, tmp)
    {
        LIST_REMOVE(waitListEntry, entry);
        IOLockWakeup(lock, waitListEntry->event, false);
        IOFree(waitListEntry, sizeof(struct WaitListEntry));
    }
}

bool WaitList::init()
{
    if (!super::init())
    {
        return false;
    }

    LIST_INIT(&m_list);

    return true;
}

