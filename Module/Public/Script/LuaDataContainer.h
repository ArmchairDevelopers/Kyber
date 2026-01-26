// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Script/LuaEventManager.h>

#include <SDK/TypeInfo.h>

namespace Kyber
{
struct LuaValueTypeData
{
    const TypeInfo* type;
    void* value;
    bool owned;
};

struct LuaFBArrayData
{
    const TypeInfo* type;
    FBArray<void*>* value;
    bool owned;
};

class LuaDataContainer
{
    friend class ScriptManager;

public:
    static const TypeInfo** WrapTypeInfo(lua_State* L, const TypeInfo* info);
    static const DataContainer** WrapDataContainer(lua_State* L, const DataContainer* container);
    template<typename T>
    static LuaFBArrayData* WrapFBArray(lua_State* L, const TypeInfo* elementType, FBArray<T>* arr);
    static LuaValueTypeData* WrapValueType(lua_State* L, const TypeInfo* type, void* value);

    static TypeInfo* GetTypeInfo(lua_State* L, int index);
    static DataContainer* GetDataContainer(lua_State* L, int index);
    static LuaValueTypeData* GetValueType(lua_State* L, int index);
    static LuaFBArrayData* GetFBArray(lua_State* L, int index);

    static void* ValueTypeCreate(lua_State* L, const TypeInfo* info);

    static void RegisterTypeConstructors(lua_State* L);

private:
    static void Register(lua_State* lua);

    static lua_State* s_lua;
};
} // namespace Kyber
