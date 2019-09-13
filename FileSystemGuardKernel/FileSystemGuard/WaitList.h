//
//  WaitList.h
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/7/18.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#ifndef WaitList_h
#define WaitList_h

#include <libkern/c++/OSObject.h>
#include <IOKit/IOLocks.h>
#include <sys/queue.h>

struct WaitListEntry
{
    LIST_ENTRY(WaitListEntry) entry;
    void *event;
};

const AbsoluteTime kNoTimeout = -1;

class WaitList : public OSObject
{
    OSDeclareDefaultStructors(WaitList);

public:
    static WaitList * waitList();

    void add(void *event);
    void remove(void *event);
    bool contains(void *event) const;
    wait_result_t wait(void *event, wait_interrupt_t interruptType, IOLock *lock, AbsoluteTime timeout = kNoTimeout);
    void signal(void *event, IOLock *lock);
    void removeEntries(IOLock *lock);

protected:
    virtual bool init() override;

private:
    LIST_HEAD(WaitListData, WaitListEntry) m_list = LIST_HEAD_INITIALIZER(m_list);

};

#endif /* WaitList_h */
