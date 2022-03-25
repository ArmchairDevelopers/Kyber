// Copyright BattleDash. All Rights Reserved.
// Adapted from ReShade.

#pragma once

#include <Windows.h>

namespace Kyber
{
struct HookTemplate
{
    void* offset;
    void* hook;
};

class Hook
{
public:
    using Address = void*;

    enum class Status
    {
        unknown = -1,
        success,
        not_executable = 7,
        unsupported_function,
        allocation_failure,
        memory_protection_failure,
    };

    static bool ApplyQueuedActions();

    bool valid() const
    {
        return target != nullptr && replacement != nullptr && target != replacement;
    }

    bool installed() const
    {
        return trampoline != nullptr;
    }
    bool uninstalled() const
    {
        return trampoline == nullptr;
    }

    void enable() const;
    void disable() const;

    Hook::Status install();
    Hook::Status uninstall();

    Address Call() const;
    template<typename T>
    T Call() const
    {
        return reinterpret_cast<T>(Call());
    }

    Address target = nullptr;
    Address trampoline = nullptr;
    LPVOID replacement = nullptr;
};
} // namespace Kyber