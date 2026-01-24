// Copyright Armchair Developers. Licensed under GPLv3.

#include <Core/Memory.h>
#include <Core/ThreadExecutor.h>
#include <Base/Log.h>

namespace Kyber
{
ThreadExecutor* g_threadExecutor;

void ThreadExecutor::QueueDelayTicks(GameThread thread, uint32_t delayTicks, Func func)
{
    auto dataGuard = m_threadData[thread].Lock();
    dataGuard->delayedFuncs.push_back({dataGuard->tickCount + delayTicks, func});
}

void ThreadExecutor::Process(GameThread thread)
{
    auto dataGuard = m_threadData[thread].Lock();

    auto& delayedFuncs = dataGuard->delayedFuncs;
    delayedFuncs.erase(eastl::remove_if(delayedFuncs.begin(), delayedFuncs.end(),
         [tickCount = dataGuard->tickCount](const DelayedFunc& delayedFunc) {
             if (tickCount >= delayedFunc.targetTicks)
             {
                 delayedFunc.func();
                 return true;
             }
     
             return false;
         }), delayedFuncs.end());

    dataGuard->tickCount++;
}

void ThreadExecutor::StaticInit()
{
    static ThreadExecutor staticThreadExecutor;
    g_threadExecutor = &staticThreadExecutor;
}
} // namespace Kyber