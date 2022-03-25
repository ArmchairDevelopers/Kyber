// Copyright BattleDash. All Rights Reserved.
// Adapted from ReShade.

#pragma once

#include <vector>
#include "hook.h"
#include <Windows.h>
#include <thread>
#include <mutex>

namespace Kyber
{
class HookManager
{
public:
    static void CreateHook(Hook::Address target, LPVOID replacement);
    static void CreateHook(LPCSTR lpPattern, LPCSTR lpMask, LPVOID replacement);
    static void CreateHook(LPCSTR lpPattern, LPCSTR lpMask, int patternIndex, LPVOID replacement);
    static void DisableHook(Hook::Address target);
    static void EnableHook(Hook::Address target);
    static void RemoveHook(Hook::Address target);
    static void RemoveHooks();
    static Hook::Address Call(Hook::Address replacement, Hook::Address target);
    template<typename T>
    static inline T Call(T replacement, Hook::Address target = nullptr)
    {
        return reinterpret_cast<T>(Call(reinterpret_cast<Hook::Address>(replacement), target));
    }
};
} // namespace Kyber