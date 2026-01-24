// Copyright Armchair Developers. Licensed under GPLv3.

#pragma once

#include <Core/Memory.h>

#include <EASTL/vector.h>

#include <functional>

namespace Kyber
{
enum GameThread
{
    GameThread_Client,
    GameThread_Server,
    GameThread_Count,
};

class ThreadExecutor
{
public:
    using Func = std::function<void()>;

    void QueueDelayTicks(GameThread thread, uint32_t delayTicks, Func func);
    void QueueDelaySecs(GameThread thread, float delaySeconds, Func func)
    {
        QueueDelayTicks(thread, static_cast<uint32_t>(delaySeconds * 30.0f), func);
    }
    
    void Queue(GameThread thread, Func func)
    {
        QueueDelayTicks(thread, 0, func);
    }

    void Process(GameThread thread);

    static void StaticInit();

private:
    struct DelayedFunc
    {
        uint64_t targetTicks;
        Func func;
    };

    struct ThreadData
    {
        eastl::vector<DelayedFunc> delayedFuncs;
        uint64_t tickCount;
    };

    Mutex<ThreadData> m_threadData[GameThread_Count];
};

extern ThreadExecutor* g_threadExecutor;
} // namespace Kyber