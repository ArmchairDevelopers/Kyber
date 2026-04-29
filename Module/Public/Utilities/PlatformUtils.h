// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <EASTL/vector.h>

#include <Windows.h>

#include <filesystem>
#include <string>

namespace Kyber
{
class PlatformUtils
{
public:
    static std::filesystem::path GetModulePath();
    static std::filesystem::path GetProgramDataPath();
    static std::string GetEnv(const std::string& env, const std::string& def = "");
    static uintptr_t BaseAddress();
    static void* GetVTableFunction(const void* pVtable, int offset);
    static void* HookVTableFunction(void* pVtable, void* fnHookFunc, int offset);
    static void* DuplicateVTable(void* objectPtr, size_t numVirtualFunctions = 106 /* Entity Vtable Function Count */);
    static void SwapEASTLVectorPtrs(void* targetVec, void* sourceVec)
    {
        uintptr_t* target = reinterpret_cast<uintptr_t*>(targetVec);
        uintptr_t* source = reinterpret_cast<uintptr_t*>(sourceVec);

        // mpBegin(8) + mpEnd(8) + mpCapacity(8) + mAllocator(8) = 0x20
        // Even if the target is a fixed vec we dont have to really care 
        // since all code associated reference mpBegin and mpEnd
        memcpy(target, source, 0x20);
    }

private:
    static BOOL MaskCompare(PVOID pBuffer, LPCSTR lpPattern, LPCSTR lpMask);
};
} // namespace Kyber