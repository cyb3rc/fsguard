//
//  Utils.cpp
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 Oleg Kulchytskyi. All rights reserved.
//

#include "Utils.h"

void * MallocNoFail(vm_size_t size)
{
    void * buff = nullptr;

    while (!(buff = IOMalloc(size)))
    {
        IOSleep(1);
    }

    return buff;
}
