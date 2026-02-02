// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Script/LuaPlayerManager.h>
#include <Hook/HookManager.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

namespace Kyber
{

extern void ServerPlayerSetUnlock(ServerPlayer* player, const Guid& guid, bool value);

TL_DECLARE_FUNC(0x14686B6F0, ServerPlayer*, ServerPlayerManager_createPlayer, void* inst, uint8_t connectionId, const eastl::string& name,
    LocalPlayerId localPlayerId, uint32_t playerId, bool isSpectator, bool a7);
TL_DECLARE_FUNC(0x14064F700, Asset*, getWsPlayerAbilityAsset, uint32_t abilityId);
TL_DECLARE_FUNC(0x14189EFD0, void*, sendPlayerSyncedGameSettings, void* unused, void* serverConnection);

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
        luaL_error(L, "Expected userdata for server player, got %s", lua_typename(L, lua_type(L, index)));
        return nullptr;
    }

    ServerPlayer** userdata = (ServerPlayer**)lua_touserdata(L, index);
    if (userdata == nullptr)
    {
        luaL_error(L, "Expected userdata for server player");
        return nullptr;
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

    LuaUtils::Push(L, player);
    return 1;
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
        lua_pushnil(L);
        return 0;
    }

    KYBER_LOG(Trace, "Got player: " << player->m_name);

    LuaUtils::Push(L, player);
    return 1;
}

static int GetPlayersFunc(lua_State* L)
{
    const ServerGameContext* serverGameContext = g_program->m_server->GetServerGameContext();
    if (serverGameContext == nullptr)
    {
        lua_pushnil(L);
        return 1;
    }

    auto& playerList = serverGameContext->serverPlayerManager->m_players;

    lua_createtable(L, playerList.size(), 0);

    int i = 1;
    for (auto player : playerList)
    {
        LuaUtils::Push(L, player);
        lua_rawseti(L, -2, i++);
    }

    return 1;
}

static int ServerPlayerGetWeapon(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    SoldierServerPlayerExtent* extent = player->GetSoldierServerPlayerExtent();
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

    SoldierServerPlayerExtent* extent = player->GetSoldierServerPlayerExtent();
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

    KYBER_LOG(Trace, "Setting weapon");
    extent->OnPlayerSelectedWeaponMessage(&message);
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

static int ServerPlayerSetBattlepoints(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int amount = luaL_checkinteger(L, 2);
    player->GetServerPlayerExtent4()->SetBattlepoints(amount);
    return 1;
}

static int ServerPlayerGiveBattlepoints(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int amount = luaL_checkinteger(L, 2);
    player->GetServerPlayerExtent4()->AddBattlepoints(amount);
    return 1;
}

static int ServerPlayerSetScore(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int amount = luaL_checkinteger(L, 2);
    player->GetPersistenceServerPlayerExtent()->SetScore(amount);
    return 1;
}

static int ServerPlayerSetKills(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int amount = luaL_checkinteger(L, 2);
    player->GetPersistenceServerPlayerExtent()->SetKills(amount);
    return 1;
}

static int ServerPlayerSetAssists(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int amount = luaL_checkinteger(L, 2);
    player->GetPersistenceServerPlayerExtent()->SetAssists(amount);
    return 1;
}

static int ServerPlayerSetDeaths(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    int amount = luaL_checkinteger(L, 2);
    player->GetPersistenceServerPlayerExtent()->SetDeaths(amount);
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

    player->GetServerGamePlayerExtent()->SetSelectedCustomizationAsset(container);

    KYBER_LOG(Info, "Set customization asset '" << assetName << "'");
    return 1;
}

static int ServerPlayerSetUnlock(lua_State* L)
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

    if (!lua_isboolean(L, 3))
    {
        return 0;
    }

    const char* assetGuid = luaL_checkstring(L, 2);
    Guid guid = Guid::FromString(assetGuid);

    const bool grant = lua_toboolean(L, 3);

    ServerPlayerSetUnlock(player, guid, grant);

    return 1;
}

static int ServerPlayerSetInvisible(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isboolean(L, 2))
    {
        return 0;
    }
    bool forceInvisible = lua_toboolean(L, 2);

    if (!player->GetCharacterEntity())
    {
        return 0;
    }

    player->GetCharacterEntity()->ForceInvisible(forceInvisible);
    return 1;
}

static int ServerPlayerSetAmmo(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isinteger(L, 2))
    {
        return 0;
    }
    int32_t count = luaL_checkinteger(L, 2);

    if (!player->GetCharacterEntity() || !player->GetCharacterEntity()->GetCurrentWeapon() 
        || !player->GetCharacterEntity()->GetCurrentWeapon()->GetWeaponFiring())
    {
        return 0;
    }

    player->GetCharacterEntity()->GetCurrentWeapon()->GetWeaponFiring()->SetPrimaryAmmoMags(count);
    return 1;
}

static int ServerPlayerSetHealth(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isinteger(L, 2))
    {
        return 0;
    }
    int32_t amount = luaL_checkinteger(L, 2);

    if (!player->GetCharacterEntity() || !player->GetCharacterEntity()->GetHealthComponent())
    {
        return 0;
    }

    player->GetCharacterEntity()->GetHealthComponent()->SetHealth(amount);
    return 1;
}

static int ServerPlayerSetMaxHealth(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isinteger(L, 2))
    {
        return 0;
    }
    int32_t amount = luaL_checkinteger(L, 2);

    if (!player->GetCharacterEntity() || !player->GetCharacterEntity()->GetHealthComponent())
    {
        return 0;
    }

    HealthComponent* healthComponent = player->GetCharacterEntity()->GetHealthComponent();
    if (healthComponent->getType()->isKindOf(typeInfo_WSServerSoldierHealthComponent))
    {
        WSServerSoldierHealthComponent* wsHealthComponent = static_cast<WSServerSoldierHealthComponent*>(healthComponent);
        wsHealthComponent->SetMaxHealth(amount);
    }
    else 
    {
        KYBER_LOG(Warning, "Invalid health component type: " << healthComponent->getType()->getName());
    }
    return 1;
}

static int ServerPlayerSetAbility(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isinteger(L, 2))
    {
        return 0;
    }

    uint32_t abilityId = luaL_checkinteger(L, 2);

    if (getWsPlayerAbilityAsset(abilityId) == nullptr)
    {
        KYBER_LOG(Warning, "Failed to load given ability id");
        return 0;
    }

    bool worked = player->GetWSServerPlayerAbilityExtent()->SetAbility(abilityId, true);

    if (!worked)
    {
        KYBER_LOG(Warning, "Failed to set player ability for " << player->m_name << " " << abilityId);
    }

    return 1;
}

static int ServerPlayerForceSendChatMessage(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    if (!lua_isinteger(L, 2))
    {
        return 0;
    }
    int32_t channel = luaL_checkinteger(L, 2);

    if (!lua_isstring(L, 2))
    {
        return 0;
    }
    const char* message = luaL_checkstring(L, 2);

    player->ForceSendChatMessage((ChatChannel)channel, message);
    return 1;
}

static int ServerPlayerSetInputEnabled(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }
    
    int32_t actionId = luaL_checkinteger(L, 2);
    bool enabled = lua_toboolean(L, 3);

    player->SetInputEnabled(actionId, enabled);
    return 1;
}

static int ServerPlayerSendSyncedSettings(lua_State* L)
{
    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 1);
    if (player == nullptr)
    {
        return 0;
    }

    ServerConnection* playerConnection = g_program->m_server->GetServerGameContext()->serverPeer->GetConnectionForPlayer(player);
    sendPlayerSyncedGameSettings(nullptr, playerConnection);
    return 0;
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
    else if (key == "SetBattlepoints")
    {
        lua_pushcfunction(L, ServerPlayerSetBattlepoints);
        return 1;
    }
    else if (key == "GiveBattlepoints")
    {
        lua_pushcfunction(L, ServerPlayerGiveBattlepoints);
        return 1;
    }
    else if (key == "SetScore")
    {
        lua_pushcfunction(L, ServerPlayerSetScore);
        return 1;
    }
    else if (key == "SetKills")
    {
        lua_pushcfunction(L, ServerPlayerSetKills);
        return 1;
    }
    else if (key == "SetAssists")
    {
        lua_pushcfunction(L, ServerPlayerSetAssists);
        return 1;
    }
    else if (key == "SetDeaths")
    {
        lua_pushcfunction(L, ServerPlayerSetDeaths);
        return 1;
    }
    else if (key == "SetCustomizationAsset")
    {
        lua_pushcfunction(L, ServerPlayerSetCustomizationAsset);
        return 1;
    }
    else if (key == "SetUnlock")
    {
        lua_pushcfunction(L, ServerPlayerSetUnlock);
        return 1;
    }
    else if (key == "Kick")
    {
        lua_pushcfunction(L, ServerPlayerKick);
        return 1;
    }
    else if (key == "SetInvisible")
    {
        lua_pushcfunction(L, ServerPlayerSetInvisible);
        return 1;
    }
    else if (key == "SetAmmo")
    {
        lua_pushcfunction(L, ServerPlayerSetAmmo);
        return 1;
    }
    else if (key == "SetHealth")
    {
        lua_pushcfunction(L, ServerPlayerSetHealth);
        return 1;
    }
    else if (key == "SetMaxHealth")
    {
        lua_pushcfunction(L, ServerPlayerSetMaxHealth);
        return 1;
    }
    else if (key == "SetAbility")
    {
        lua_pushcfunction(L, ServerPlayerSetAbility);
        return 1;
    }
    else if (key == "ForceSendChatMessage")
    {
        lua_pushcfunction(L, ServerPlayerForceSendChatMessage);
        return 1;
    }
    else if (key == "SetInputEnabled")
    {
        lua_pushcfunction(L, ServerPlayerSetInputEnabled);
        return 1;
    }
    else if (key == "SendSyncedSettings")
    {
        lua_pushcfunction(L, ServerPlayerSendSyncedSettings);
        return 1;
    }
    else if (key == "name")
    {
        lua_pushstring(L, player->m_name);
        return 1;
    }
    else if (key == "playerId")
    {
        lua_pushinteger(L, player->m_onlineId.m_nativeData);
        return 1;
    }
    else if (key == "team")
    {
        lua_pushinteger(L, player->m_teamId);
        return 1;
    }
    else if (key == "battlepoints")
    {
        lua_pushinteger(L, player->GetServerPlayerExtent4()->m_battlepoints);
        return 1;
    }
    else if (key == "score")
    {
        lua_pushinteger(L, player->GetPersistenceServerPlayerExtent()->m_score);
        return 1;
    }
    else if (key == "kills")
    {
        lua_pushinteger(L, player->GetPersistenceServerPlayerExtent()->m_kills);
        return 1;
    }
    else if (key == "assists")
    {
        lua_pushinteger(L, player->GetPersistenceServerPlayerExtent()->m_assists);
        return 1;
    }
    else if (key == "deaths")
    {
        lua_pushinteger(L, player->GetPersistenceServerPlayerExtent()->m_deaths);
        return 1;
    }
    else if (key == "characterEntity")
    {
        LuaUtils::Push(L, reinterpret_cast<NativeEntity*>(player->GetCharacterEntity()));
        return 1;
    }
    else if (key == "vehicleEntity")
    {
        LuaUtils::Push(L, reinterpret_cast<NativeEntity*>(player->GetVehicleEntity()));
        return 1;
    }
    else if (key == "activeKit")
    {
        LuaUtils::Push(L, reinterpret_cast<DataContainer*>(const_cast<Asset*>(player->GetServerGamePlayerExtent()->m_activeKit)));
        return 1;
    }
    else if (key == "isBot")
    {
        lua_pushboolean(L, player->IsAIPlayer());
        return 1;
    }
    else if (key == "isSpawned")
    {
        lua_pushboolean(L, player->GetCharacterEntity() != nullptr || player->GetVehicleEntity() != nullptr);
        return 1;
    }

    return 0;
}

static const luaL_Reg s_serverPlayerMeta[] = { { "__index", ServerPlayerIndex }, { NULL, NULL } };

void LuaPlayerManager::Register(lua_State* L)
{
    luaL_newmetatable(L, "ServerPlayer");
    luaL_setfuncs(L, s_serverPlayerMeta, 0);

    luaL_Reg funcs[] = { { "CreatePlayer", CreatePlayerFunc }, { "GetPlayer", GetPlayerFunc }, { "GetPlayers", GetPlayersFunc }, { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(L, "PlayerManager", funcs);
}

Asset* GetWSPlayerAbilityFromCustomizationAssetHk(ServerPlayer* player, uint32_t characterId, uint32_t abilityId, bool a4)
{
    Asset* asset = getWsPlayerAbilityAsset(abilityId);
    if (asset != nullptr)
    {
        KYBER_LOG(Debug, "getWsPlayerAbilityAsset: " << asset->Name);
    }
    return asset;
}

void LuaPlayerManager::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x1489639E0), GetWSPlayerAbilityFromCustomizationAssetHk);
}

} // namespace Kyber
