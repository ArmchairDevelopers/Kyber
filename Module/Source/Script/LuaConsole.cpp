// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaConsole.h>

#include <Core/Program.h>

namespace Kyber::Script
{
class LuaConsoleCommand
{
public:
    LuaConsoleCommand(lua_State* L, int instanceRef, int callbackRef)
        : L(L)
        , instanceRef(instanceRef)
        , callbackRef(callbackRef)
    {}

    void Execute(ConsoleContext& cc)
    {
        KB_LUA_LOCK;

        lua_rawgeti(L, LUA_REGISTRYINDEX, instanceRef);
        lua_rawgeti(L, LUA_REGISTRYINDEX, callbackRef);
        lua_pushvalue(L, -2);

        lua_pushstring(L, cc.rawArguments);
        if (lua_pcall(L, 2, 1, 0) != LUA_OK)
        {
            KYBER_LOG(Warning, "Error calling Lua function: " << lua_tostring(L, -1));
            lua_pop(L, 1);
        }

        if (lua_isstring(L, -1))
        {
            cc.pushOutput(lua_tostring(L, -1));
        }

        lua_pop(L, 1);
    }

private:
    lua_State* L;
    int instanceRef;
    int callbackRef;
};

static int ConsoleRegisterFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    std::string groupName = luaL_checkstring(L, 1);

    if (!lua_isstring(L, 2))
    {
        return 0;
    }
    std::string name = luaL_checkstring(L, 2);

    if (!lua_isstring(L, 3))
    {
        return 0;
    }
    std::string description = luaL_checkstring(L, 3);

    if (!lua_istable(L, 4))
    {
        return 0;
    }

    lua_pushvalue(L, 4);
    int instanceRef = luaL_ref(L, LUA_REGISTRYINDEX);

    if (!lua_isfunction(L, 5))
    {
        return 0;
    }
    lua_pushvalue(L, 5);
    int callbackRef = luaL_ref(L, LUA_REGISTRYINDEX);

    auto registerLambda = [=]() {
        KYBER_LOG(Info, "Registering console command: " << groupName.c_str() << " " << name.c_str() << " " << description.c_str());
        LuaConsoleCommand* command = new LuaConsoleCommand(L, instanceRef, callbackRef);
        auto delegate = fastdelegate::MakeDelegate(command, &LuaConsoleCommand::Execute);
        ConsoleRegistry_registerInstanceMethod(delegate, name.c_str(), groupName.c_str());
    };

    if (g_program->m_console != nullptr)
    {
        registerLambda();
    }
    else
    {
        g_program->m_consoleRegistrationCallbacks.push_back(registerLambda);
    }

    return 0;
}

static int ConsoleExecuteFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    const char* command = luaL_checkstring(L, 1);

    if (g_program->m_console != nullptr)
    {
        g_program->m_console->EnqueueCommand(command);
    }

    return 0;
}

static int GetSettingsFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    std::string name = luaL_checkstring(L, 1);
    DataContainer* container = SettingsManager_getSettingsObject(g_program->GetSettingsManager(), name.c_str());
    if (container == nullptr)
    {
        KYBER_LOG(Error, ScriptManager::GetPlugin(L)->LogPrefix() << "Settings object not found: " << name);
        return 0;
    }
    LuaUtils::Push(L, container);
    return 1;
}

void RegisterConsoleTable(lua_State* L)
{
    luaL_Reg funcs[] = { { "Register", ConsoleRegisterFunc }, { "Execute", ConsoleExecuteFunc }, { "GetSettings", GetSettingsFunc },
        { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(L, "Console", funcs);
}
} // namespace Kyber::Script
