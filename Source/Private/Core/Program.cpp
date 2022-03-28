// Copyright BattleDash. All Rights Reserved.

#include <Core/Program.h>

#include <Base/Version.h>
#include <Base/Log.h>
#include <Render/Renderer.h>
#include <Utilities/ErrorUtils.h>
#include <Utilities/PlatformUtils.h>
#include <Utilities/MemoryUtils.h>
#include <Hook/HookManager.h>
#include <SDK/SDK.h>
#include <Network/SocketManager.h>
#include <API/KyberAPIService.h>

#include <MinHook/MinHook.h>

#include <Windows.h>
#include <cstdio>
#include <chrono>
#include <thread>

#define OFFSET_CLIENT_STATE_CHANGE 0x140A8C7A0
#define OFFSET_GET_SETTINGS_OBJECT 0x1401F7BD0
#define OFFSET_GET_CLIENT_INSTANCE 0x14659DE50

Kyber::Program* g_program;

namespace Kyber
{
Program::Program(HMODULE module)
    : m_api(nullptr)
    , m_server(nullptr)
    , m_clientState(ClientState::ClientState_None)
    , m_joining(false)
{
    if (g_program || MH_Initialize() != MH_OK)
    {
        ErrorUtils::ThrowException("Initialization failed. Please restart Battlefront and try again!");
    }

    // Open a console
    AllocConsole();
    FILE* pFile;
    freopen_s(&pFile, "CONOUT$", "w", stdout);

    // ANSI Colors
    HANDLE stdoutHandle = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD dwMode;
    GetConsoleMode(stdoutHandle, &dwMode);
    dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    SetConsoleMode(stdoutHandle, dwMode);

    SetConsoleTitleA(("Kyber v" + KYBER_VERSION).c_str());

    new std::thread(&Program::InitializationThread, this);
}

Program::~Program()
{
    KYBER_LOG(LogLevel::Info, "Disposing of Kyber!");
}

DWORD WINAPI Program::InitializationThread()
{
    KYBER_LOG(LogLevel::Info, "Initializing...");
    KYBER_LOG(LogLevel::Info, "   _____     _   _   _     ____          _        ");
    KYBER_LOG(LogLevel::Info, "  | __  |___| |_| |_| |___|    \\___ ___| |_      ");
    KYBER_LOG(LogLevel::Info, "  | __ -| .'|  _|  _| | -_|  |  | .'|_ -|   |     ");
    KYBER_LOG(LogLevel::Info, "  |_____|__,|_| |_| |_|___|____/|__,|___|_|_|     ");
    KYBER_LOG(LogLevel::Info, "                                                  ");
    KYBER_LOG(LogLevel::Info, "           ^@GPP5555555555555555G&:               ");
    KYBER_LOG(LogLevel::Info, "          7@!  ~5YYYYYYYYYYYYY5Y 7@~              ");  
    KYBER_LOG(LogLevel::Info, "         P&.   ~@@@@@@@@@@@@@@@5. :&Y             ");
    KYBER_LOG(LogLevel::Info, "        #B ~&    @@@@@@@@@@@G^      #B            ");
    KYBER_LOG(LogLevel::Info, "      :&Y Y@B    !@@@@@@@@B!   :J&@? P&.          ");
    KYBER_LOG(LogLevel::Info, "     !@! B@@@~    &@@@@&J.   :Y&@@@@@P 7@         ");
    KYBER_LOG(LogLevel::Info, "    Y&..&@@@@&    !@&5:   :Y&@@@@@@@@@# :@        ");
    KYBER_LOG(LogLevel::Info, "   G# ^@@@@@@@?   ^   ^P&@@@@@@@@@@@@@@:.&P       ");
    KYBER_LOG(LogLevel::Info, "  B@ .@@@@@@@@@      ^YGB#&@@@@@@@@@@@@@  @P      ");
    KYBER_LOG(LogLevel::Info, "   G# ^@@@@@@@@5   .         :^!J5G#&@&:.&P       ");
    KYBER_LOG(LogLevel::Info, "    Y&..&@@@@@@@.  .@@&#GY7^.          ^@J        ");
    KYBER_LOG(LogLevel::Info, "     !@! B@@@@@@B   J@@@@@@@@@&#GY7^  ?@~         ");
    KYBER_LOG(LogLevel::Info, "      :&Y Y@@@@@@~   &@@@@@@@@@@@@@? P&.          ");
    KYBER_LOG(LogLevel::Info, "        #B ~@@@@@&    K@@@@@@@@@@@@^#B            ");
    KYBER_LOG(LogLevel::Info, "         P&..&@@@@J   Y@@@@@@@@@&.:&Y             ");
    KYBER_LOG(LogLevel::Info, "          7@~ JYYY?    JYYYYYYYJ !@~              ");
    KYBER_LOG(LogLevel::Info, "           ^@G55555PPPP555555555G&                ");   
    KYBER_LOG(LogLevel::Info, "                                                  ");

    InitializeGameHooks();

    m_api = new KyberAPIService();
    g_renderer = new Renderer();
    m_server = new Server();

    KYBER_LOG(LogLevel::Info, "Initialized Kyber v" << KYBER_VERSION);
    KYBER_LOG(LogLevel::Warning, "Press [INSERT] on your Keyboard to use Kyber!");

    return 0;
}

void DispatchMessageHk(__int64 pMessageManagerImpl, Message* pMessage)
{
    static const auto trampoline = HookManager::Call(DispatchMessageHk);
    __int64 serverGameContext = g_program->m_server->GetServerGameContext();
    __int64 serverMessageManager = serverGameContext ? *reinterpret_cast<__int64*>(serverGameContext + 0x10) : 0;
    if (pMessage != nullptr && pMessage != NULL)
    {
        TypeInfo* pType = pMessage->getType();

        if (pType == nullptr && pType != NULL)
        {
            KYBER_LOG(LogLevel::Debug, "pType was null.");
        }
        else if (pType->m_InfoData != nullptr)
        {
            if (true && strcmp(pType->m_InfoData->m_Name, "ClientInputUnchangedInputMessage") != 0)
            {
                if (serverMessageManager == pMessageManagerImpl)
                {
                    KYBER_LOG(LogLevel::Debug, "[SERVER] Dispatched Message " << pType->m_InfoData->m_Name);
                }
                else
                {
                    if (strcmp(pType->m_InfoData->m_Name, "ClientExitToMenuMessage") == 0)
                    {
                        KYBER_LOG(LogLevel::Debug, "[CLIENT] Dispatched exit to menu message " << std::hex << pMessage);
                    }
                    KYBER_LOG(LogLevel::Debug, "[CLIENT] Dispatched Message " << pType->m_InfoData->m_Name);
                }
            }
            if (false && strcmp(pType->m_InfoData->m_Name, "StatSessionStartMessage") == 0)
            {
                KYBER_LOG(LogLevel::Debug, "Dispatched Message " << pType->m_InfoData->m_Name);
            }
            if (strcmp(pType->m_InfoData->m_Name, "ClientPlayerLocalSetMessage") == 0) {}

            // if ( reinterpret_cast<uintptr_t>( pType ) == 0x000 )
            //	util::PauseProcess( FALSE );
        }
        else
        {
            KYBER_LOG(LogLevel::Debug, "Dispatched Message: " << reinterpret_cast<uintptr_t>(pMessage));
        }
    }
    else
    {
        KYBER_LOG(LogLevel::Debug, "Message was null.");
    }
    return trampoline(pMessageManagerImpl, pMessage);
}

void QueueMessageHk(__int64 pMessageManagerImpl, Message* pMessage, float delayTime)
{
    static const auto trampoline = HookManager::Call(QueueMessageHk);
    __int64 serverGameContext = g_program->m_server->GetServerGameContext();
    __int64 serverMessageManager = serverGameContext ? *reinterpret_cast<__int64*>(serverGameContext + 0x10) : 0;
    if (pMessage != nullptr && pMessage != NULL)
    {
        TypeInfo* pType = pMessage->getType();

        if (pType == nullptr && pType != NULL)
        {
            KYBER_LOG(LogLevel::Debug, "pType was null.");
        }
        else if (pType->m_InfoData != nullptr)
        {
            if (serverMessageManager == pMessageManagerImpl)
            {
                KYBER_LOG(LogLevel::Debug, "[SERVER] Queued Message " << pType->m_InfoData->m_Name);
            }
            else
            {
                if (strcmp(pType->m_InfoData->m_Name, "ClientExitToMenuMessage") == 0)
                {
                    KYBER_LOG(LogLevel::Debug, "[CLIENT] Queued exit to menu message " << std::hex << pMessage);
                }
                KYBER_LOG(LogLevel::Debug, "[CLIENT] Queued Message " << pType->m_InfoData->m_Name);
            }
        }
        else
        {
            KYBER_LOG(LogLevel::Debug, "Queued Message: " << reinterpret_cast<uintptr_t>(pMessage));
        }
    }
    else
    {
        KYBER_LOG(LogLevel::Debug, "Message was null.");
    }
    return trampoline(pMessageManagerImpl, pMessage, delayTime);
}

void Program::InitializeGameHooks()
{
    HookManager::CreateHook(reinterpret_cast<void*>(0x1401F6CA0), DispatchMessageHk);
    HookManager::CreateHook(reinterpret_cast<void*>(0x1401F8950), QueueMessageHk);
    HookManager::CreateHook(reinterpret_cast<void*>(OFFSET_CLIENT_STATE_CHANGE), ClientStateChangeHk);
    HookManager::CreateHook(reinterpret_cast<void*>(OFFSET_GET_SETTINGS_OBJECT), GetSettingsObjectHk);
    HookManager::CreateHook(reinterpret_cast<void*>(OFFSET_GET_CLIENT_INSTANCE), GetClientInstanceHk);
    Hook::ApplyQueuedActions();
}

__int64 ClientStateChangeHk(__int64 inst, ClientState currentClientState, ClientState lastClientState)
{
    static const auto trampoline = HookManager::Call(ClientStateChangeHk);
    g_program->m_clientState = currentClientState;
    KYBER_LOG(LogLevel::DebugPlusPlus, "Client state changed to " << currentClientState);
    Server* server = g_program->m_server;
    if (currentClientState == ClientState_Startup)
    {
        if (server->m_running)
        {
            server->Stop();

            GameSettings* gameSettings = Settings<GameSettings>("Game");
            gameSettings->Level = "Levels/FrontEnd/FrontEnd";
            gameSettings->DefaultLayerInclusion = "";
        }
        else
        {
            if (!g_program->m_joining)
            {
                Settings<ClientSettings>("Client")->ServerIp = "";
            }
            else
            {
                g_program->m_joining = false;
            }
        }
    }
    else if (currentClientState == ClientState_Ingame && server->m_running)
    {
        server->InitializeGameSettings();
    }
    return trampoline(inst, currentClientState, lastClientState);
}

__int64 GetSettingsObjectHk(__int64 inst, const char* identifier)
{
    static const auto trampoline = HookManager::Call(GetSettingsObjectHk);
    return trampoline(inst, identifier);
}

__int64 GetClientInstanceHk()
{
    static const auto trampoline = HookManager::Call(GetClientInstanceHk);
    return trampoline();
}
} // namespace Kyber