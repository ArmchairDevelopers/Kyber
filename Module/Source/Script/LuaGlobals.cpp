// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaGlobals.h>
#include <Script/ScriptManager.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

namespace Kyber::Script
{
int ScriptLoader(lua_State* L)
{
    std::string path = lua_tostring(L, 1);

    PluginBase* plugin = ScriptManager::GetPlugin(L);
    if (!StringUtils::StartsWith(path, "common/"))
    {
        switch (plugin->GetRealm())
        {
        case PluginRealm_Client:
            path = "client/" + path;
            break;
        case PluginRealm_Server:
            path = "server/" + path;
            break;
        }
    }

    if (path.find(".lua") == std::string::npos)
    {
        path += ".lua";
    }

    auto content = plugin->LoadFile(path);
    if (!content)
    {
        KYBER_LOG(Error, plugin->LogPrefix() << " Failed to load '" << path << "'");
        lua_pushnil(L);
        return 1;
    }

    if (content->empty())
    {
        lua_pushnil(L);
        return 1;
    }

    if (luaL_loadstring(L, content->c_str()))
    {
        KYBER_LOG(Error, "Failed to load: " << lua_tostring(L, -1));
        lua_pop(L, 1);
        lua_pushnil(L);
        return 1;
    }

    return 1;
}

int Print(lua_State* L)
{
    PluginBase* plugin = ScriptManager::GetPlugin(L);

    std::string output;

    int n = lua_gettop(L);
    for (int i = 1; i <= n; i++)
    {
        if (i > 1)
        {
            output += "\t";
        }

        output += lua_tostring(L, i);
    }

    KYBER_LOG(Info, plugin->LogPrefix() << " " << output);
    return 0;
}

void RegisterGlobals(lua_State* L)
{
    // Set the file loader
    lua_getglobal(L, LUA_LOADLIBNAME);
    lua_getfield(L, -1, "searchers");
    lua_pushvalue(L, -2);
    lua_pushcclosure(L, ScriptLoader, 1);
    lua_rawseti(L, -2, 5);
    lua_setfield(L, -2, "searchers");

    // Set print
    static const luaL_Reg printFuncs[] = { { "print", Print }, { NULL, NULL } };
    lua_getglobal(L, "_G");
    luaL_setfuncs(L, printFuncs, 0);
    lua_pop(L, 1);
}

KB_REGISTER_LUA_CONTENT(RegisterGlobals);
} // namespace Kyber::Script
