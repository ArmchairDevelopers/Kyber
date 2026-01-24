// Copyright Armchair Developers. Licensed under GPLv3.

#include <RPC/AsyncRPCManager.h>
#include <Base/Log.h>
#include <Utilities/PlatformUtils.h>

namespace Kyber
{
void AsyncRPCManager::Update() const
{
    void* tag;
    bool ok;
    auto zeroTimeout = gpr_time_0(GPR_CLOCK_MONOTONIC);
    while (m_cq.AsyncNext(&tag, &ok, zeroTimeout) == grpc::CompletionQueue::GOT_EVENT)
    {
        GenericAsyncClientCall* call = static_cast<GenericAsyncClientCall*>(tag);
        call->Process(ok);
        FB_GLOBAL_ARENA->free(call);
    }
}
} // namespace Kyber
