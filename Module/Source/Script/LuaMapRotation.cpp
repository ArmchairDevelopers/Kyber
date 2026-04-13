// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#include <Core/Program.h>
#include <Script/Lua.h>

namespace Kyber
{
// Helper
static void PushMapRotationEntry(lua_State* L, const MapRotationEntry& entry)
{
    lua_createtable(L, 2, 0);
    lua_pushstring(L, entry.level.c_str());
    lua_setfield(L, -2, "level");
    lua_pushstring(L, entry.mode.c_str());
    lua_setfield(L, -2, "mode");
}

static int MapRotationAddMapFunc(lua_State* L)
{
    MapRotation& rotation = g_program->m_server->m_mapRotation;

    std::string level = luaL_checkstring(L, 1);
    std::string mode = luaL_checkstring(L, 2);

    rotation.AddEntry(level, mode);
    return 0;
}

static int MapRotationClearFunc(lua_State* L)
{
    MapRotation& rotation = g_program->m_server->m_mapRotation;
    rotation.Reset();

    // Clear with a required at least 1 entry, as there is no backup.
    std::string level = luaL_checkstring(L, 1);
    std::string mode = luaL_checkstring(L, 2);

    rotation.AddEntry(level, mode);
    return 0;
}

static int MapRotationGetNextMapFunc(lua_State* L)
{
    const MapRotation& rotation = g_program->m_server->m_mapRotation;
    auto& nextEntry = rotation.PeekNextEntry();
    PushMapRotationEntry(L, nextEntry);
    return 1; // Return table { level, mode }
}

static int MapRotationRemoveNextMapFunc(lua_State* L)
{
    MapRotation& rotation = g_program->m_server->m_mapRotation;
    rotation.RemoveNextEntry();
    return 0;
}

static int MapRotationGetListFunc(lua_State* L)
{
    const MapRotation& rotation = g_program->m_server->m_mapRotation;
    std::vector<MapRotationEntry> list = rotation.GetList();

    lua_createtable(L, list.size(), 0);
    for (int i = 0; i < list.size(); i++)
    {
        PushMapRotationEntry(L, list[i]);
        lua_rawseti(L, -2, i + 1);
    }

    return 1; // Return list of map rotation entries { level, mode }[]
}

// clang-format off
static const luaL_Reg s_mapRotationFuncs[] = { 
    { "AddMap", MapRotationAddMapFunc }, 
    { "Clear", MapRotationClearFunc },
    { "GetNextMap", MapRotationGetNextMapFunc }, 
    { "RemoveNextMap", MapRotationRemoveNextMapFunc }, 
    { "GetList", MapRotationGetListFunc }, 
    { NULL, NULL } 
};
// clang-format on

static void RegisterMapRotation(lua_State* L)
{
    KB_LUA_NEW_GLOBAL_LIB(L, "MapRotation", s_mapRotationFuncs);
}

KB_REGISTER_LUA_CONTENT(RegisterMapRotation);
} // namespace Kyber
