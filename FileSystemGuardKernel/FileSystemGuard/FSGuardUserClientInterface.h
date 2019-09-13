//
//  FSGuardUserClientInterface.h
//  FileSystemGuard
//
//  Created by Oleg Kulchytskyi on 9/13/19.
//  Copyright © 2019 c0de1n. All rights reserved.
//

#ifndef FSGuardUserClientInterface_h
#define FSGuardUserClientInterface_h

#include <sys/param.h>

constexpr const char *kFSGuardServiceClass = "FSGuardService";

enum class FSGuardMethod
{
    PostFSGuardResponse,

    Count
};

constexpr uint32_t kFGNotificationPortQueue = 1;
constexpr uint32_t kFGMemoryMapQueue = 1;

enum class FSGuardAction
{
    Read,
    Write,
    Execute
};

struct FSGuardRequest
{
    void *rid;
    pid_t pid;
    FSGuardAction action;
    char filePath[PATH_MAX];

};

struct FSGuardResponse
{
    void *rid;

};

#endif /* FSGuardUserClientInterface_h */
