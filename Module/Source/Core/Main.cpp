// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Base/Log.h>
#include <Base/Platform.h>
#include <Core/Program.h>

#include <string>

#define EASTL_USER_DEFINED_ALLOCATOR

void* operator new[](
    size_t size, size_t alignment, size_t alignmentOffset, const char* pName, int flags, unsigned debugFlags, const char* file, int line)
{
    return new uint8_t[size];
}

void* operator new[](size_t size, const char* name, int flags, unsigned debugFlags, const char* file, int line)
{
    return new uint8_t[size];
}

BOOL APIENTRY DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpReserved)
{
    if (dwReason == DLL_PROCESS_ATTACH)
    {
        Kyber::g_program = new Kyber::Program(hModule);
    }
    else if (dwReason == DLL_PROCESS_DETACH)
    {
        KYBER_LOG(Info, "Kyber unloaded");
        delete Kyber::g_program;
    }

    return TRUE;
}