// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Script/Lua.h>

#include <SDK/SDK.h>

namespace Kyber
{
class LuaPlayerManager
{
public:
    static ServerPlayer* GetServerPlayer(lua_State* L, int index);
    static const ServerPlayer** WrapServerPlayer(lua_State* L, const ServerPlayer* player);

    static void Register(lua_State* L);
    static void InitializeHooks();
};
} // namespace Kyber
