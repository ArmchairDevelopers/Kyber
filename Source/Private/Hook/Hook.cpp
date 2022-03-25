// Copyright BattleDash. All Rights Reserved.
// Adapted from ReShade.

#include <Hook/Hook.h>
#include <MinHook/MinHook.h>

#include <cassert>

namespace Kyber
{
// Verify status codes match the ones from MinHook
static_assert(static_cast<int>(Hook::Status::unknown) == MH_UNKNOWN);
static_assert(static_cast<int>(Hook::Status::success) == MH_OK);
static_assert(static_cast<int>(Hook::Status::not_executable) == MH_ERROR_NOT_EXECUTABLE);
static_assert(static_cast<int>(Hook::Status::unsupported_function) == MH_ERROR_UNSUPPORTED_FUNCTION);
static_assert(static_cast<int>(Hook::Status::allocation_failure) == MH_ERROR_MEMORY_ALLOC);
static_assert(static_cast<int>(Hook::Status::memory_protection_failure) == MH_ERROR_MEMORY_PROTECT);

static unsigned long s_reference_count = 0;

void Hook::enable() const
{
    MH_QueueEnableHook(target);
}

void Hook::disable() const
{
    MH_QueueDisableHook(target);
}

Hook::Status Hook::install()
{
    if (!valid())
        return Hook::Status::unsupported_function;

    // Only leave MinHook active as long as any hooks exist
    if (s_reference_count++ == 0)
        MH_Initialize();

    const MH_STATUS status_code = MH_CreateHook(target, replacement, &trampoline);
    if (status_code == MH_OK || status_code == MH_ERROR_ALREADY_CREATED)
    {
        // Installation was successful, so enable the hook and return
        enable();

        return Hook::Status::success;
    }

    if (--s_reference_count == 0)
        MH_Uninitialize();

    return static_cast<Hook::Status>(status_code);
}

Hook::Status Hook::uninstall()
{
    if (!valid())
        return Hook::Status::unsupported_function;

    const MH_STATUS status_code = MH_RemoveHook(target);
    if (status_code == MH_ERROR_NOT_CREATED)
        return Hook::Status::success; // If the hook was never created, then uninstallation is implicitly successful
    else if (status_code != MH_OK)
        return static_cast<Hook::Status>(status_code);

    trampoline = nullptr;

    // MinHook can be uninitialized after all hooks were uninstalled
    if (--s_reference_count == 0)
        MH_Uninitialize();

    return Hook::Status::success;
}

Hook::Address Hook::Call() const
{
    assert(installed());

    return trampoline;
}

bool Hook::ApplyQueuedActions()
{
    return MH_ApplyQueued() == MH_OK;
}
} // namespace Kyber