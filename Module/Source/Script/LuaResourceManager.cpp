// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaResourceManager.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

namespace Kyber::Script
{
static int LookupDataContainer(lua_State* L)
{
    const char* name = luaL_checkstring(L, 1);

    DataContainer* container = ResourceManagerLookupDataContainer(name);
    if (container == nullptr)
    {
        KYBER_LOG(Warning, "Failed to get data container '" << name << "'");
        lua_pushnil(L);
        return 0;
    }
    
    LuaUtils::Push(L, container);
    return 1;
}

void RegisterResourceManagerTable(lua_State* L)
{
    luaL_Reg funcs[] = { { "LookupDataContainer", LookupDataContainer }, { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(L, "ResourceManager", funcs);
}
} // namespace Kyber::Script
