// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Script/LuaHookManager.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <Script/Lua.h>

namespace Kyber
{
static int ListenFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        std::cerr << "Error: First argument is not a string\n";
        return 0;
    }
    const char* eventName = luaL_checkstring(L, 1);

    if (!lua_istable(L, 2))
    {
        std::cerr << "Error: Second argument is not a table\n";
        return 0;
    }
    lua_pushvalue(L, 2);
    int instanceRef = luaL_ref(L, LUA_REGISTRYINDEX);

    if (!lua_isfunction(L, 3))
    {
        std::cerr << "Error: Third argument is not a function\n";
        return 0;
    }
    lua_pushvalue(L, 3);
    int callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);

    LuaEventCallback luaCallback = [L, instanceRef, callbackRef](LuaCallbackParamSetupFunc setupFunc, LuaCallbackParamCleanupFunc cleanupFunc) {
        KB_LUA_LOCK;

        lua_rawgeti(L, LUA_REGISTRYINDEX, instanceRef);
        lua_rawgeti(L, LUA_REGISTRYINDEX, callbackRef);
        lua_pushvalue(L, -2);

        int args = setupFunc(L) + 1;
        if (lua_pcall(L, args, 0, 0) != LUA_OK)
        {
            std::cerr << "Error calling Lua function: " << lua_tostring(L, -1) << std::endl;
            lua_pop(L, 1);
        }

        cleanupFunc(L);

        lua_pop(L, 1);
    };

    g_program->m_scriptManager->GetEventManager().Listen(eventName, luaCallback);
    return 0;
}

void LuaHookManager::Hook(const std::string& eventName, LuaHookCallback callback)
{
    std::cout << "Subscribed to hook: " << eventName << std::endl;
    m_hooks[eventName].push_back(callback);
}

LuaHookManager::LuaHookManager(lua_State* L)
{
    luaL_Reg funcs[] = {
        { "Listen", ListenFunc },
        { NULL, NULL}
    };

    LuaUtils::RegisterFunctionTable(L, "HookManager", funcs);
}
} // namespace Kyber
