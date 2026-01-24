// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Script/LuaPlayerManager.h>
#include <Hook/HookManager.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

namespace Kyber
{
TL_DECLARE_FUNC(0x14686B6F0, ServerPlayer*, ServerPlayerManager_createPlayer, void* inst, uint8_t connectionId, const eastl::string& name,
    LocalPlayerId localPlayerId, uint32_t playerId, bool isSpectator, bool a7);
TL_DECLARE_FUNC(0x146881270, void*, ServerGamePlayerExtent_setSelectedCustomizationAsset, void* inst, DataContainer* asset);

template<>
void LuaUtils::Push<ServerPlayer*>(lua_State* L, ServerPlayer* value)
{
    if (value == nullptr)
    {
        lua_pushnil(L);
        return;
    }

    LuaPlayerManager::WrapServerPlayer(L, value);
    luaL_getmetatable(L, "ServerPlayer");
    lua_setmetatable(L, -2);
}

ServerPlayer* LuaPlayerManager::GetServerPlayer(lua_State* L, int index)
{
    if (!lua_isuserdata(L, index))
    {
        luaL_error(L, "Expected userdata for container, got %s", lua_typename(L, lua_type(L, index)));
        return NULL;
    }

    ServerPlayer** userdata = (ServerPlayer**)lua_touserdata(L, index);
    if (userdata == NULL)
    {
        luaL_error(L, "Expected userdata for container");
        return NULL;
    }

    return *userdata;
}

const ServerPlayer** LuaPlayerManager::WrapServerPlayer(lua_State* L, const ServerPlayer* player)
{
    const ServerPlayer** userdata = (const ServerPlayer**)lua_newuserdata(L, sizeof(ServerPlayer*));
    *userdata = player;
    return userdata;
}

static int CreatePlayerFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    const char* playerName = luaL_checkstring(L, 1);

    ServerPlayer* player = ServerPlayerManager_createPlayer(
        g_program->m_server->GetServerGameContext()->serverPlayerManager, 0, playerName, LocalPlayerId_Invalid, 0xFFFFFFFF, false, false);

    player->SetTeam(2);
    return 0;
}

static int GetPlayerFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    const char* playerName = luaL_checkstring(L, 1);

    ServerPlayer* player = g_program->m_server->GetServerGameContext()->serverPlayerManager->GetPlayer(playerName);
    if (player == nullptr)
    {
        return 0;
    }

    KYBER_LOG(Info, "Got player: " << player->m_name);

    LuaUtils::Push(L, player);
    return 1;
}

static int GetPlayersFunc(lua_State* L)
{
    auto& playerList = g_program->m_server->GetServerGameContext()->serverPlayerManager->m_players;
    lua_createtable(L, playerList.size(), 0);

    int i = 1;
    for (auto player : playerList)
    {
        LuaUtils::Push(L, player);
        lua_rawseti(L, -2, i++);
    }

    return 1;
}

struct NetworkPlayerSelectedWeaponMessage
{
    char gap0[88];
    int m_slot;
    char gap5C[4];
    DataContainer* m_soldierWeaponUnlockAsset;
    FBArray<DataContainer*> m_unlockAssets;
    char gap70;
    bool m_isFirstWeapon;
};

TL_DECLARE_FUNC(0x1416A7840, bool, SoldierServerPlayerExtent_onPlayerSelectedWeaponMessage, void* inst, NetworkPlayerSelectedWeaponMessage* message);

static int ServerPlayerGetWeapon(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    SoldierServerPlayerExtent* extent = reinterpret_cast<SoldierServerPlayerExtent*>(player->GetExtent("SoldierServerPlayerExtent"));
    if (extent == nullptr)
    {
        KYBER_LOG(Warning, "Failed to get extent");
        return 0;
    }

    const auto& weapon = extent->m_weapons[0];
    LuaUtils::Push(L, (DataContainer*)weapon.asset);
    return 1;
}

static int ServerPlayerSetWeapon(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    TypeObject* extent = player->GetExtent("SoldierServerPlayerExtent");
    if (extent == nullptr)
    {
        KYBER_LOG(Warning, "Failed to get extent");
        return 0;
    }

    const char* weaponName = luaL_checkstring(L, 2);

    DataContainer* container = ResourceManagerLookupDataContainer(weaponName);
    if (container == nullptr)
    {
        KYBER_LOG(Warning, "Failed to get container");
        return 0;
    }

    NetworkPlayerSelectedWeaponMessage message;
    message.m_slot = 0;
    message.m_soldierWeaponUnlockAsset = container;
    message.m_unlockAssets.init(1);
    message.m_unlockAssets.m_data[0] = container;
    message.m_isFirstWeapon = false;

    KYBER_LOG(Info, "Setting weapon");
    SoldierServerPlayerExtent_onPlayerSelectedWeaponMessage(extent, &message);
    return 1;
}

static int ServerPlayerSetTeam(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int team = luaL_checkinteger(L, 2);
    player->SetTeam(team);
    return 1;
}

static int ServerPlayerSetCustomizationAsset(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    const char* assetName = luaL_checkstring(L, 2);
    
    DataContainer* container = ResourceManagerLookupDataContainer(assetName);
    if (container == nullptr)
    {
        KYBER_LOG(Warning, "Failed to get customization container '" << assetName << "'");
        return 0;
    }

    void* extent = player->GetExtent("ServerGamePlayerExtent");
    ServerGamePlayerExtent_setSelectedCustomizationAsset(extent, container);

    KYBER_LOG(Info, "Set customization asset '" << assetName << "'");
    return 1;
}

static int ServerPlayerKick(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isstring(L, 2))
    {
        return 0;
    }
    const char* kickReason = luaL_checkstring(L, 2);
    
    g_program->m_server->KickPlayer(player, kickReason);
    return 1;
}

static int ServerPlayerIndex(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    std::string key = luaL_checkstring(L, 2);

    if (key == "GetWeapon")
    {
        lua_pushcfunction(L, ServerPlayerGetWeapon);
        return 1;
    }
    else if (key == "SetWeapon")
    {
        lua_pushcfunction(L, ServerPlayerSetWeapon);
        return 1;
    }
    else if (key == "SetTeam")
    {
        lua_pushcfunction(L, ServerPlayerSetTeam);
        return 1;
    }
    else if (key == "SetCustomizationAsset")
    {
        lua_pushcfunction(L, ServerPlayerSetCustomizationAsset);
        return 1;
    }
    else if (key == "Kick")
    {
        lua_pushcfunction(L, ServerPlayerKick);
        return 1;
    }
    else if (key == "name")
    {
        lua_pushstring(L, player->m_name);
        return 1;
    }
    else if (key == "team")
    {
        lua_pushinteger(L, player->m_teamId);
        return 1;
    }
    else if (key == "isBot")
    {
        lua_pushboolean(L, player->IsAIPlayer());
        return 1;
    }

    return 0;
}

static const luaL_Reg s_serverPlayerMeta[] = { { "__index", ServerPlayerIndex }, { NULL, NULL } };

void LuaPlayerManager::Register(lua_State* L)
{
    L = L;

    luaL_newmetatable(L, "ServerPlayer");
    luaL_setfuncs(L, s_serverPlayerMeta, 0);

    luaL_Reg funcs[] = { { "CreatePlayer", CreatePlayerFunc }, { "GetPlayer", GetPlayerFunc }, { "GetPlayers", GetPlayersFunc }, { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(L, "PlayerManager", funcs);
}
} // namespace Kyber
