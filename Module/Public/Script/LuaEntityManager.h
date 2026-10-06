// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Script/LuaEventManager.h>

#include <SDK/TypeInfo.h>

namespace Kyber
{
class LuaEntityManager
{
public:
    static const NativeEntity** WrapEntity(NativeEntity* entity);
    static const EntityBus** WrapEntityBus(EntityBus* entity);

    static NativeEntity* GetEntity(int index);
    static EntityBus* GetEntityBus(int index);

    static void Register(lua_State* L);

private:
    static lua_State* s_lua;
};
} // namespace Kyber
