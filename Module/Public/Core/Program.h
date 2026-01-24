// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/Server.h>

#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>
#include <SDK/Types.h>
#include <Core/Console.h>
#include <ModLoader/ModLoader.h>
#include <RPC/API.h>
#include <RPC/InterfaceService.h>

#include <Entity/NativeEntityManager.h>
#include <Script/ScriptManager.h>
#include <Voip/VoipManager.h>

#include <Windows.h>
#include <condition_variable>

#define OFFSET_GLOBAL_CLIENT 0x143DCB9D0
#define OFFSET_GLOBAL_SETTINGS_MANAGER 0x143D11950
#define OFFSET_GET_CLIENT_INSTANCE 0x14659DE50

namespace Kyber
{
TL_DECLARE_FUNC(0x1401F7BD0, DataContainer*, SettingsManager_getSettingsObject, void* inst, const char* identifier);

__int64 ClientStateChangeHk(__int64 a1, ClientState currentClientState, ClientState lastClientState);
const char* GetHostIdHk(__int64 inst);
void MessageManagerQueueMessageHk(void* pMessageManagerImpl, Message* pMessage, float delayTime);
void MessageManagerDispatchMessageHk(void* pMessageManagerImpl, Message* pMessage);
void OnGotDisconnectedHk(void* inst, SecureReason reason, const eastl::string& reasonText);
__int64 OriginSDKInitializeHk(void* inst, int a2, uint16_t lsxPort, void* a4, void* a5);
__int64 StreamManagerMoveClientTransmitHk(__int64 inst, __int64 stream, __int64 record, __int64 context);
__int64 StreamManagerMoveServerReceiveHk(__int64 inst, __int64 stream);
__int64 StreamManagerChatTransmitHk(__int64 inst, __int64 stream, __int64* context);
__int64 EntryInputStateNetworkMoveMoveWriteHk(__int64 inst, __int64 ghost, __int64 stream);
__int64 EntryInputStateNetworkMoveMoveReadHk(__int64 inst, __int64 ghost, __int64 stream);

class Program
{
public:
    Program(HMODULE module);
    ~Program();

    void Uninitialize() const;
    void InitializationThread();

    void InitializeConsole();
    void InitializeGameHooks();
    void InitializeGamePatches();
    void Initialize();

    void RegisterClientUpdatePassListener(ClientUpdatePassListener* listener);
    void HandleClientServerJoin(NetworkCreatePlayerMessage* message);
    
    // If proxied is true, IP is assumed to be a proxy ID
    void JoinServer(const std::string& id, std::string ip, uint16_t port, bool spectate, bool proxied = false, bool changeState = true);

    void AttemptJoinVoip();

    void* GetSettingsManager()
    {
        return *reinterpret_cast<void**>(OFFSET_GLOBAL_SETTINGS_MANAGER);
    }

    template<typename T>
    T* GetSettingsObject(const char* identifier)
    {
        return reinterpret_cast<T*>(SettingsManager_getSettingsObject(GetSettingsManager(), identifier));
    }

    __int64 ChangeClientState(ClientState currentClientState)
    {
        return ClientStateChangeHk(
            *reinterpret_cast<__int64*>(*reinterpret_cast<__int64*>(((__int64 (*)(void))OFFSET_GET_CLIENT_INSTANCE)() + 0x20) + 0x28),
            currentClientState, m_clientState);
    }

    API* GetAPI()
    {
        return m_api.get();
    }

    HMODULE m_module;

    // Consumed when ModLoader is created
    ModData m_modData;

    Server* m_server;
    Console* m_console;

    EntityManager* m_entityManager;
    ScriptManager* m_scriptManager;

    KyberSettingsManager* m_settingsManager;
    VoipManager* m_voipManager;

    SocketManager* m_clientSocketManager;

    ClientState m_clientState;

    std::vector<std::function<void()>> m_consoleRegistrationCallbacks;
    std::vector<ClientUpdatePassListener*> m_clientUpdatePassListeners;

    std::mutex m_startupMutex;
    std::condition_variable m_startupCondition;

    std::string m_joinToken;

    bool m_startupInitialized;
    bool m_joining;
    bool m_spectator;
    bool m_connected;
    bool m_allowInteraction;
    bool m_isDedicatedServer;
    bool m_messageDebugEnabled;

private:
    std::unique_ptr<API> m_api;
    std::unique_ptr<InterfaceService> m_interface;
};

extern Program* g_program;

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