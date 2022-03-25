// Copyright BattleDash. All Rights Reserved.

#include <Base/Log.h>
#include <Base/Platform.h>
#include <Base/Version.h>
#include <Core/Program.h>

#include <string>

BOOL APIENTRY DllMain(HMODULE hModule, DWORD dwReason, LPVOID lpReserved)
{
    if (dwReason == DLL_PROCESS_ATTACH)
    {
        g_program = new Kyber::Program(hModule);
    }
    else if (dwReason == DLL_PROCESS_DETACH)
    {
        delete g_program;
    }

    return TRUE;
}