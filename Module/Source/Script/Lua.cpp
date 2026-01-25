// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaDataContainer.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <Script/Lua.h>

namespace Kyber
{
std::recursive_mutex LuaUtils::s_lock;

template<>
void LuaUtils::Push<int>(lua_State* L, int value)
{
    lua_pushinteger(L, value);
}

template<>
void LuaUtils::Push<float>(lua_State* L, float value)
{
    lua_pushnumber(L, value);
}

template<>
void LuaUtils::Push<const char*>(lua_State* L, const char* value)
{
    lua_pushstring(L, value);
}

template<>
void LuaUtils::Push<char*>(lua_State* L, char* value)
{
    Push(L, const_cast<const char*>(value));
}

template<>
void LuaUtils::Push<std::string>(lua_State* L, std::string value)
{
    LuaUtils::Push(L, value.c_str());
}
} // namespace Kyber
