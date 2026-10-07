// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Core/DebugHooks.h>

#include <Core/Program.h>
#include <Base/Log.h>
#include <Hook/HookManager.h>
#include <Core/Memory.h>
#include <Core/Console.h>
#include <Utilities/PlatformUtils.h>
#include <Utilities/MemoryUtils.h>
#include <Core/Sentry.h>
#include <SDK/Funcs.h>

#include <processthreadsapi.h>
#include <functional>

#define OFFSET_MOUNTSUPERBUNDLES HOOK_OFFSET(0x1401FEFC0)
#define OFFSET_SUPERBUNDLEMANAGER_PARSEMANIFEST HOOK_OFFSET(0x14024A260)
#define OFFSET_SUPERBUNDLEMANAGER_MOUNT HOOK_OFFSET(0x140248AF0)
#define OFFSET_DBOBJECT_GETVALUE HOOK_OFFSET(0x1453D9DE0)
#define OFFSET_DEBUGCONTEXTDATA_PUSHCONTEXTDATA HOOK_OFFSET(0x140235190)
#define OFFSET_DEBUGCONTEXTDATA_PUSHCONTEXTDATA_INT HOOK_OFFSET(0x140235310)
#define OFFSET_WIN32FILESYSTEM_CTOR HOOK_OFFSET(0x140241B30)
#define OFFSET_VIRTUALFILESYSTEM_MOUNT HOOK_OFFSET(0x14023A210)
#define OFFSET_VIRTUALFILESYSTEM_CREATEBUFFER HOOK_OFFSET(0x140238C60)
#define OFFSET_WIN32BUFFER_READEX HOOK_OFFSET(0x14024AFA0)
#define OFFSET_SERVERGAMEPLAYEREXTENT_INITNETWORKABLES HOOK_OFFSET(0x146872BF0)
#define OFFSET_CLASSINFO_CTOR HOOK_OFFSET(0x1453BBCC0)
#define OFFSET_NATIVETYPEREGISTRY_INIT HOOK_OFFSET(0x1453DB400)
#define OFFSET_LUAWIDGETDATA_INIT HOOK_OFFSET(0x141D7EAB0)
#define OFFSET_BITARRAY_INTERNALINIT HOOK_OFFSET(0x145460230)
#define OFFSET_BITARRAY_INIT HOOK_OFFSET(0x14545A640)
#define OFFSET_GAMERENDERER_RENDER HOOK_OFFSET(0x141503B20)
#define OFFSET_DX11TEXTURE_CREATE HOOK_OFFSET(0x1416169B0)
#define OFFSET_RESOURCEREFRESOLVER_ADDRESOURCEREF HOOK_OFFSET(0x1454B93B0)
#define OFFSET_HEARTBEATMONITOR_BEAT HOOK_OFFSET(0x145494CA0)
#define OFFSET_TURBOLOOP HOOK_OFFSET(0x140229DE0)

namespace Kyber
{
static std::mutex s_heartbeatMutex;
static std::map<std::string, DWORD> s_heartbeatLastThreadIds;

void HeartbeatMonitorBeatHk(const char* name)
{
    static const auto trampoline = HookManager::Call(HeartbeatMonitorBeatHk);

    s_heartbeatMutex.lock();
    s_heartbeatLastThreadIds[name] = GetCurrentThreadId();
    s_heartbeatMutex.unlock();

    trampoline(name);
}

void DebugContextDataPushContextData(void* inst, const char* dataKey, const char* dataValue)
{
    static const auto trampoline = HookManager::Call(DebugContextDataPushContextData);
    KYBER_LOG(Debug, "[" << dataKey << "] " << dataValue);

    Sentry::s_debugContextData[dataKey] = dataValue;

    if (std::string(dataKey).find("turbo.buffer") != std::string::npos)
    {
        KYBER_LOG(Debug, "[Turbo Debugger Trip] [" << dataKey << "] " << dataValue);
    }

    if (std::string(dataKey) == "HeartbeatData")
    {
        nlohmann::json json = nlohmann::json::parse(dataValue);
        std::string timer = json["StalledTimer"].get<std::string>();
        KYBER_LOG(Warning, "Stall detected, last thread id for '" << timer << "': " << s_heartbeatLastThreadIds[timer]);

        KYBER_LOG(Warning, "All thread IDs:");
        for (const auto& [name, id] : s_heartbeatLastThreadIds)
        {
            KYBER_LOG(Warning, " " << name << ": " << id);
        }

        KYBER_LOG(Info, "Dumping debug context:");
        for (const auto& [key, value] : Sentry::s_debugContextData)
        {
            KYBER_LOG(Info, " " << key.c_str() << ": " << value.c_str());
        }
    }

    return trampoline(inst, dataKey, dataValue);
}

// I've always referred to this as "turboLogger" in my research, but it's called by the memory
// system as well and I have no idea what it is, so I'm gonna guess it's part of DebugContextData
void DebugContextDataPushContextDataInt(void* inst, const char* dataKey, int dataValue)
{
    static const auto trampoline = HookManager::Call(DebugContextDataPushContextDataInt);

    // There are constant messages for MemAvailPhysMB, MemAvailVirtualMB, and MemAvailPageFileMB
    if (strstr(dataKey, "MemAvail") == nullptr)
    {
        KYBER_LOG(Debug, "[" << dataKey << "] " << dataValue);
    }

    return trampoline(inst, dataKey, dataValue);
}

std::map<void*, std::string> s_vfsBufferPaths;

void* Win32FileSystemCtorHk(void* inst, const char* basePath)
{
    static const auto trampoline = HookManager::Call(Win32FileSystemCtorHk);
    KYBER_LOG(Info, "[VFS] Creating Win32 Fs " << std::hex << inst << ": " << basePath);
    return trampoline(inst, basePath);
}

void* VirtualFileSystemMountHk(void* inst, void* backend, const char* pathName)
{
    static const auto trampoline = HookManager::Call(VirtualFileSystemMountHk);
    KYBER_LOG(Info, "[VFS] Mounting " << pathName << " to backend " << std::hex << backend);
    return trampoline(inst, backend, pathName);
}

void* VirtualFileSystemCreateBufferHk(void* inst, unsigned bufferFlags, const char* pathName)
{
    static const auto trampoline = HookManager::Call(VirtualFileSystemCreateBufferHk);
    KYBER_LOG(Debug,
        "[VFS] Creating buffer for " << pathName << " (Flags: " << bufferFlags << ", Return: " << std::hex << _ReturnAddress() << ")");

    void* result = trampoline(inst, bufferFlags, pathName);
    if (result == nullptr)
    {
        KYBER_LOG(Trace, "Failed to open '" << pathName << "'!");
    }

    s_vfsBufferPaths[result] = pathName;
    return result;
}

uint64_t Win32BufferReadExHk(void* inst, void* destination, int64_t byteCount)
{
    static const auto trampoline = HookManager::Call(Win32BufferReadExHk);

    uint64_t result = trampoline(inst, destination, byteCount);
    if (result != 0)
    {
        auto it = s_vfsBufferPaths.find(inst);
        if (it != s_vfsBufferPaths.end())
        {
            KYBER_LOG(Error, "Failed to read " << byteCount << " bytes from Win32Buffer(" << it->second << ")!");
        }
        else
        {
            KYBER_LOG(Error, "Failed to read " << byteCount << " bytes from an unrecognized Win32Buffer!");
        }
    }

    return result;
}

BOOL TerminateProcessHk(HANDLE hProcess, UINT uExitCode)
{
    static const auto trampoline = HookManager::Call(TerminateProcessHk);
    KYBER_LOG(Info, "Process terminated");
    return trampoline(hProcess, uExitCode);
}

TL_DECLARE_FUNC(0x146C25060, uint32_t, getNetworkableClassId, const int category, const int type);

bool StreamManagerMessageAddMessageHk(void* inst, Message* message)
{
    static const auto trampoline = HookManager::Call(StreamManagerMessageAddMessageHk);
    KYBER_LOG(Info,
        "Adding networkable message " << message->getType()->getName() << ": " << getNetworkableClassId(message->m_category, message->m_type));
    return trampoline(inst, message);
}

using OptionVec = eastl::vector<const char*>;
static OptionVec::iterator* g_optionVecMpBegin = (OptionVec::iterator*)0x143A5A050;
static OptionVec::iterator* g_optionVecMpEnd = (OptionVec::iterator*)0x143A5A058;

static const char* getExecOption(int n)
{
    OptionVec options = OptionVec(*g_optionVecMpBegin, *g_optionVecMpEnd);
    if (n >= 0 && n < options.size())
    {
        return options[n];
    }

    return "";
}

bool ScriptContextImplExecuteScriptFileHk(void* inst, const char* fileName, bool mustExist, void* fs, eastl::string* outErr)
{
    static const auto trampoline = HookManager::Call(ScriptContextImplExecuteScriptFileHk);

    eastl::string luaTable = "commandLine = {";
    OptionVec optionVec(*g_optionVecMpBegin, *g_optionVecMpEnd);
    int argc = optionVec.size();

    for (int i = 1; i < argc; ++i)
    {
        const char* arg = getExecOption(i);

        if (arg[0] == '-')
        {
            int j = i + 1;

            const char* value = nullptr;
            if (j < argc)
            {
                value = getExecOption(j);
                if (value[0] == '-')
                {
                    value = nullptr;
                }
            }

            eastl::string key = arg + 1;
            for (char& c : key)
            {
                c = tolower(c);
            }

            if (value)
            {
                luaTable += "[ [==[" + key + "]==] ] = [==[" + value + "]==],";
            }
            else
            {
                luaTable += "[ [==[" + key + "]==] ] = true,";
            }
        }

        luaTable += StringUtils::Format("[%d] = [==[%s]==],", i, arg).c_str();
    }

    luaTable += "}";
    luaTable += "allowCommandlineSettings = true";

    ScriptContext_Impl_executeString(inst, luaTable.c_str(), luaTable.size(), nullptr);
    return trampoline(inst, fileName, mustExist, fs, outErr);
}

void* SettingsManagerAddHk(
    void* inst, const char* groupName, void* instance, bool exposeToConsole, const char* a5, void* a6, bool a7)
{
    static const auto trampoline = HookManager::Call(SettingsManagerAddHk);
    return trampoline(inst, groupName, instance, true, a5, a6, a7);
}

__int64 ExpressionTemporaryFixBFPlusHk(void* a1, void* a2)
{
    static const auto trampoline = HookManager::Call(ExpressionTemporaryFixBFPlusHk);

    if (a1 == nullptr)
    {
        KYBER_LOG(Info, "ExpressionJob crash detected. Please report this!");
        return 0;
    }

    return trampoline(a1, a2);
}

// BEGIN - Why is this in DebugHooks..?

static std::vector<RenderListener*> s_renderListeners;
static std::mutex s_renderListenerLock;

void RegisterRenderListener(RenderListener* listener)
{
    std::lock_guard<std::mutex> lock(s_renderListenerLock);
    s_renderListeners.push_back(listener);
}

void UnregisterRenderListener(RenderListener* listener)
{
    std::lock_guard<std::mutex> lock(s_renderListenerLock);
    s_renderListeners.erase(std::remove(s_renderListeners.begin(), s_renderListeners.end(), listener), s_renderListeners.end());
}

__int64 GameRendererRenderHk(void* inst, __int64 a2)
{
    static const auto trampoline = HookManager::Call(GameRendererRenderHk);

    {
        std::lock_guard<std::mutex> lock(s_renderListenerLock);
        for (const auto& listener : s_renderListeners)
        {
            listener->Render();
        }
    }

    return trampoline(inst, a2);
}

void GenericUpdateManager::GameSimInit()
{
    for (const auto& listener : m_listeners)
    {
        for (const auto& updateListener : listener.second)
        {
            updateListener->GameSimInit();
        }
    }
}

void GenericUpdateManager::Call(UpdateType type, const UpdateParameters& params)
{
    auto it = m_listeners.find(type);
    if (it != m_listeners.end())
    {
        for (GenericUpdateListener* listener : it->second)
        {
            listener->Update(type, params);
        }
    }
}

// END

void InitializeDebugHooks()
{
    HookTemplate hookOffsets[] = {
        { OFFSET_DEBUGCONTEXTDATA_PUSHCONTEXTDATA, DebugContextDataPushContextData },
        { OFFSET_DEBUGCONTEXTDATA_PUSHCONTEXTDATA_INT, DebugContextDataPushContextDataInt },
        { OFFSET_WIN32FILESYSTEM_CTOR, Win32FileSystemCtorHk },
        { OFFSET_VIRTUALFILESYSTEM_MOUNT, VirtualFileSystemMountHk },
        { OFFSET_VIRTUALFILESYSTEM_CREATEBUFFER, VirtualFileSystemCreateBufferHk },
        { OFFSET_WIN32BUFFER_READEX, Win32BufferReadExHk },
        { OFFSET_GAMERENDERER_RENDER, GameRendererRenderHk },
        { OFFSET_HEARTBEATMONITOR_BEAT, HeartbeatMonitorBeatHk },
        { HOOK_OFFSET(0x140208AE0), ScriptContextImplExecuteScriptFileHk },
        { HOOK_OFFSET(0x1401F54A0), SettingsManagerAddHk },
        { HOOK_OFFSET(0x1476FBD30), ExpressionTemporaryFixBFPlusHk },
        { GetProcAddress(GetModuleHandleA("kernel32.dll"), "TerminateProcess"), TerminateProcessHk },
    };

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }

    Hook::ApplyQueuedActions();

    BYTE ptch[] = { 0x75, 0x43 };
    MemoryUtils::Patch(HOOK_OFFSET(0x140229EA4), ptch, sizeof(ptch));

    BYTE ptch2[] = { 0x75, 0x1A };
    MemoryUtils::Patch(HOOK_OFFSET(0x140229ECD), ptch2, sizeof(ptch2));
}
} // namespace Kyber
