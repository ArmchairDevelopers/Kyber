// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaEventManager.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <Script/Lua.h>

namespace Kyber
{
static int ListenFunc(lua_State* L)
{
    PluginBase* plugin = ScriptManager::GetPlugin(L);

    if (!lua_isstring(L, 1))
    {
        KYBER_LOG(Error, plugin->LogPrefix() << " First argument to EventManager.Listen should be a string");
        return 0;
    }
    const char* eventName = luaL_checkstring(L, 1);

    if (!lua_isfunction(L, 2))
    {
        KYBER_LOG(Error, plugin->LogPrefix() << " Second argument to EventManager.Listen should be a function");
        return 0;
    }
    lua_pushvalue(L, 2);
    int callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);

    int instanceRef = -1;
    if (lua_istable(L, 3))
    {
        lua_pushvalue(L, 3);
        instanceRef = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    std::string copiedEventName = eventName;
    LuaEventCallback luaCallback = [L, copiedEventName, instanceRef, callbackRef](
                                       LuaCallbackParamSetupFunc setupFunc, LuaCallbackParamCleanupFunc cleanupFunc) {
        KB_LUA_LOCK;

        bool useInst = instanceRef != -1;
        if (useInst)
        {
            lua_rawgeti(L, LUA_REGISTRYINDEX, instanceRef);
        }

        lua_rawgeti(L, LUA_REGISTRYINDEX, callbackRef);

        if (useInst)
        {
            lua_pushvalue(L, -2);
        }

        int args = setupFunc(L);
        if (useInst)
        {
            ++args;
        }

        if (lua_pcall(L, args, 0, 0) != LUA_OK)
        {
            KYBER_LOG(Error, ScriptManager::GetPlugin(L)->LogPrefix()
                                 << " Error calling event " << copiedEventName << ": " << lua_tostring(L, -1));
            lua_pop(L, 1);
        }

        cleanupFunc(L);

        if (useInst)
        {
            lua_pop(L, 1);
        }
    };

    g_program->m_scriptManager->GetEventManager().Listen(eventName, luaCallback);
    return 0;
}

void LuaEventManager::Listen(const std::string& eventName, LuaEventCallback callback)
{
    m_listeners[eventName].push_back(callback);
}

void FireEventCommand(ConsoleContext& cc)
{
    ConsoleStream stream(cc.rawArguments, " ");
    std::string event;
    stream >> event;

    g_program->m_scriptManager->GetEventManager().Fire(event, "Test", 42, 3.14f);
}

LuaEventManager::LuaEventManager()
{
    g_program->m_consoleRegistrationCallbacks.push_back([&]() { RegisterConsoleCommand(&FireEventCommand, "FireLua", "<event>"); });
}

void LuaEventManager::Register(lua_State* L)
{
    luaL_Reg funcs[] = { { "Listen", ListenFunc }, { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(L, "EventManager", funcs);
}
} // namespace Kyber
