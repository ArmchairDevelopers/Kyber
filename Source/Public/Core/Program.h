// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Core/Server.h>
#include <SDK/TypeInfo.h>
#include <API/APIService.h>

#include <Windows.h>

#define OFFSET_GLOBAL_CLIENT 0x143DCB9D0
#define OFFSET_GLOBAL_SETTINGS_MANAGER 0x143D11950
#define OFFSET_GET_CLIENT_INSTANCE 0x14659DE50

namespace Kyber
{
__int64 ClientStateChangeHk(__int64 a1, ClientState currentClientState, ClientState lastClientState);
__int64 GetSettingsObjectHk(__int64 inst, const char* identifier);

class Program
{
public:
    Program(HMODULE module);
    ~Program();

    DWORD WINAPI InitializationThread();
    void InitializeGameHooks();

    template<typename T>
    T* GetSettingsObject(const char* identifier)
    {
        return reinterpret_cast<T*>(GetSettingsObjectHk(*reinterpret_cast<__int64*>(OFFSET_GLOBAL_SETTINGS_MANAGER), identifier));
    }

    __int64 ChangeClientState(ClientState currentClientState)
    {
        return ClientStateChangeHk(
            *reinterpret_cast<__int64*>(*reinterpret_cast<__int64*>(((__int64 (*)(void))OFFSET_GET_CLIENT_INSTANCE)() + 0x20) + 0x28),
            currentClientState, m_clientState);
    }

    HMODULE m_module;
    APIService* m_api;
    Server* m_server;
    ClientState m_clientState;
    bool m_joining;
};

template<class T>
class Settings
{
public:
    Settings(const char* identifier)
    {
        m_settings = g_program->GetSettingsObject<T>(identifier);
    }

    inline T* operator->()
    {
        return m_settings;
    }
    inline const T* operator->() const
    {
        return m_settings;
    }
    inline operator T*()
    {
        return m_settings;
    }
    inline operator const T*() const
    {
        return m_settings;
    }

private:
    T* m_settings;
};
} // namespace Kyber

extern Kyber::Program* g_program;