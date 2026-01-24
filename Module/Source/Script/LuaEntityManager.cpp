// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaEntityManager.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <Script/Lua.h>
#include <SDK/Funcs.h>
#include <Script/LuaDataContainer.h>
#include <Script/LuaPlayerManager.h>

namespace Kyber
{
lua_State* LuaEntityManager::s_lua = nullptr;

template<>
void LuaUtils::Push<NativeEntity*>(lua_State* L, NativeEntity* value)
{
    LuaEntityManager::WrapEntity(value);
    luaL_getmetatable(L, "Entity");
    lua_setmetatable(L, -2);
}

template<>
void LuaUtils::Push<EntityBus*>(lua_State* L, EntityBus* value)
{
    LuaEntityManager::WrapEntityBus(value);
    luaL_getmetatable(L, "EntityBus");
    lua_setmetatable(L, -2);
}

const NativeEntity** LuaEntityManager::WrapEntity(NativeEntity* entity)
{
    const NativeEntity** userdata = (const NativeEntity**)lua_newuserdata(s_lua, sizeof(NativeEntity*));
    *userdata = entity;
    return userdata;
}

const EntityBus** LuaEntityManager::WrapEntityBus(EntityBus* entity)
{
    const EntityBus** userdata = (const EntityBus**)lua_newuserdata(s_lua, sizeof(EntityBus*));
    *userdata = entity;
    return userdata;
}

NativeEntity* LuaEntityManager::GetEntity(int index)
{
    if (!lua_isuserdata(s_lua, index))
    {
        luaL_error(s_lua, "Expected userdata for entity, got %s", lua_typename(s_lua, lua_type(s_lua, index)));
        return NULL;
    }

    NativeEntity** userdata = (NativeEntity**)lua_touserdata(s_lua, index);
    if (userdata == NULL)
    {
        luaL_error(s_lua, "Expected userdata for entity");
        return NULL;
    }

    return *userdata;
}

EntityBus* LuaEntityManager::GetEntityBus(int index)
{
    if (!lua_isuserdata(s_lua, index))
    {
        luaL_error(s_lua, "Expected userdata for entity bus, got %s", lua_typename(s_lua, lua_type(s_lua, index)));
        return NULL;
    }

    EntityBus** userdata = (EntityBus**)lua_touserdata(s_lua, index);
    if (userdata == NULL)
    {
        luaL_error(s_lua, "Expected userdata for entity bus");
        return NULL;
    }

    return *userdata;
}

static int CreateEntityFunc(lua_State* L)
{
    GameObjectData* container = (GameObjectData*)LuaDataContainer::GetDataContainer(L, 1);
    KYBER_LOG(Info, "Spawning " << container->m_dcType->typeInfoData->name);

    int realm = ScriptManager::GetPlugin(L)->GetRealm();
    GameWorld* gameWorld = g_gameWorld[realm];
    if (gameWorld == nullptr)
    {
        KYBER_LOG(Warning, "Game world is null");
        return 1;
    }

    SubLevel* subLevel = gameWorld->m_rootLevel;

    ClientPlayerManager* playerManager = ClientGameContext::Get()->GetPlayerManager();
    if (playerManager == nullptr)
    {
        KYBER_LOG(Warning, "Player manager is null");
        return 1;
    }

    ClientPlayer* player = playerManager->GetLocalPlayer(LocalPlayerId_0);
    if (player == nullptr)
    {
        KYBER_LOG(Warning, "Player is null");
        return 1;
    }

    Camera* camera = ClientCameraViewManager_getActiveCamera(player->cameraViewManager);
    if (camera == nullptr)
    {
        KYBER_LOG(Warning, "Camera is null");
        return 1;
    }

    LinearTransform cameraTransform = GameRenderer::Get()->renderView->transform;
    // ClientCameraViewManager_getActiveCameraTransform(player->cameraViewManager, cameraTransform);
    //container->Transform = cameraTransform;

    NativeEntity* entity = g_program->m_entityManager->CreateEntity(subLevel->m_rootEntityBus, container, cameraTransform, (Realm)realm);
    if (entity != nullptr)
    {
        entity->Init();
        KYBER_LOG(Info, "Created entity: " << std::hex << entity << " " << entity->getType()->typeInfoData->name);
    }
    else
    {
        KYBER_LOG(Warning, "Failed to create entity");
    }

    LuaUtils::Push(L, entity);
    return 1;
}

static int GetListFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    std::string entityName = luaL_checkstring(L, 1);

    if (!lua_isinteger(L, 2))
    {
        luaL_error(L, "Expected integer for realm, got %s", lua_typename(L, lua_type(L, 2)));
        return 0;
    }
    int realm = luaL_checkinteger(L, 2);

    GameWorld* gameWorld = g_gameWorld[realm];
    if (gameWorld == nullptr)
    {
        KYBER_LOG(Warning, "Game world is null");
        return 1;
    }

    SubLevel* subLevel = gameWorld->m_rootLevel;
    auto entityList = subLevel->GetOwnedEntitiesRecursively();
    lua_createtable(L, entityList.size(), 0);
    
    int i = 1;
    for (auto entity : entityList)
    {
        if (entity->getType()->typeInfoData->name == entityName)
        {
            LuaUtils::Push(L, entity);
            lua_rawseti(L, -2, i++);
        }
    }

    return 1;
}

static int ServerPlayerEventFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    std::string eventName = luaL_checkstring(L, 1);

    ServerPlayer* player = LuaPlayerManager::GetServerPlayer(L, 2);
    if (player == nullptr)
    {
        return 0;
    }

    ServerPlayerEvent* event = (ServerPlayerEvent*) lua_newuserdata(L, sizeof(ServerPlayerEvent));
    event->init(player, StringUtils::HashQuick(eventName.c_str()));
    event->m_sendToPlayerOnly = true;
    event->m_team = Team1;
    return 1;
}

static int EntityEventFunc(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        return 0;
    }
    std::string eventName = luaL_checkstring(L, 1);

    EntityEvent* event = (EntityEvent*) lua_newuserdata(L, sizeof(EntityEvent));
    new (event) EntityEvent(StringUtils::HashQuick(eventName.c_str()));
    return 1;
}

static int EntityFireEvent(lua_State* L)
{
    NativeEntity* entity = LuaEntityManager::GetEntity(1);
    if (entity == nullptr)
    {
        return 0;
    }

    if (!lua_isuserdata(L, 2))
    {
        return 0;
    }

    ServerPlayerEvent* event = (ServerPlayerEvent*)lua_touserdata(L, 2);
    if (event == nullptr)
    {
        return 0;
    }

    KYBER_LOG(Info, "Entity: " << std::hex << entity << " Event: " << event->eventId);
    entity->FireEvent(event);
    return 1;
}

static int EntityEvent(lua_State* L)
{
    NativeEntity* entity = LuaEntityManager::GetEntity(1);
    if (entity == nullptr)
    {
        return 0;
    }

    if (!lua_isuserdata(L, 2))
    {
        return 0;
    }

    ServerPlayerEvent* event = (ServerPlayerEvent*)lua_touserdata(L, 2);
    if (event == nullptr)
    {
        return 0;
    }

    KYBER_LOG(Info, "Entity: " << std::hex << entity << " Event: " << event->eventId);
    entity->Event(event);
    return 1;
}

static int EntityWrite(lua_State* L)
{
    NativeEntity* entity = LuaEntityManager::GetEntity(1);
    if (entity == nullptr)
    {
        return 0;
    }

    const char* key = luaL_checkstring(L, 2);
    const char* typeName = luaL_checkstring(L, 3);

    int fieldHash = StringUtils::HashQuick(key);

    DataContext dc;
    DataContext_ctor(entity->GetEntityBus(), &dc);

    PropertyWriterBase writer;
    #define WRITEPROP(data) PropertyWriterBase_init(&writer, &dc, entity->GetData(), fieldHash, type, data, true)

    const TypeInfo* type = g_program->m_entityManager->GetNativeType(typeName);
    switch (type->getBasicType())
    {
    case kTypeCode_Void:
    case kTypeCode_DbObject:
        break;
    case kTypeCode_ValueType: {
        LuaValueTypeData* val = LuaDataContainer::GetValueType(L, 4);
        if (val->type != type)
        {
            KYBER_LOG(Warning, "Type mismatch");
            return 0;
        }

        WRITEPROP(val->value);
        break;
    }
    case kTypeCode_Class:
    case kTypeCode_Array:
    case kTypeCode_CString:
    case kTypeCode_Boolean:
    case kTypeCode_Int32:
    case kTypeCode_Uint32:
    case kTypeCode_Float32:
    case kTypeCode_Float64:
    default:
        KYBER_LOG(Warning, "Unknown type");
        return 0;
    }

    KYBER_LOG(Info, "Wrote " << key << " to " << entity->getType()->typeInfoData->name);
    return 1;
}

static int EntityRead(lua_State* L)
{
    NativeEntity* entity = LuaEntityManager::GetEntity(1);
    if (entity == nullptr)
    {
        return 0;
    }

    const char* key = luaL_checkstring(L, 2);
    const char* typeName = luaL_checkstring(L, 3);

    int fieldHash = StringUtils::HashQuick(key);

    DataContext dc;
    DataContext_ctor(entity->GetEntityBus(), &dc);

    PropertyWriterBase reader;
    PropertyWriterBase_init(&reader, &dc, entity->GetData(), fieldHash, nullptr, nullptr, false);
    KYBER_LOG(Info, "Reading " << key << " from " << entity->getType()->typeInfoData->name << std::hex << " " << &reader);
    void* value = PropertyWriterBase_get(&reader);
    if (value == nullptr)
    {
        KYBER_LOG(Warning, "Failed to read " << key);
        return 0;
    }

    const TypeInfo* type = g_program->m_entityManager->GetNativeType(typeName);
    switch (type->getBasicType())
    {
    case kTypeCode_Void:
    case kTypeCode_DbObject:
        break;
    case kTypeCode_ValueType: {
        KYBER_LOG(Info, "Reading " << key << " from " << entity->getType()->typeInfoData->name << " as " << typeName << " " << std::hex << value);
        LuaDataContainer::WrapValueType(L, type, value);
        luaL_getmetatable(L, "ValueType");
        lua_setmetatable(L, -2);
        break;
    }
    case kTypeCode_Class:
    case kTypeCode_Array:
    case kTypeCode_CString:
    case kTypeCode_Boolean:
    case kTypeCode_Int32:
    case kTypeCode_Uint32:
    case kTypeCode_Float32:
    case kTypeCode_Float64:
    default:
        KYBER_LOG(Warning, "Unknown type");
        return 0;
    }

    KYBER_LOG(Info, "Wrote " << key << " to " << entity->getType()->typeInfoData->name);
    return 1;
}

static int EntityIndex(lua_State* L)
{
    NativeEntity* entity = LuaEntityManager::GetEntity(1);
    std::string key = luaL_checkstring(L, 2);

    if (key == "data")
    {
        LuaUtils::Push(L, (DataContainer*)entity->GetData());
        return 1;
    }
    else if (key == "bus")
    {
        LuaUtils::Push(L, entity->GetEntityBus());
        return 1;
    }
    else if (key == "FireEvent")
    {
        lua_pushcfunction(L, EntityFireEvent);
        return 1;
    }
    else if (key == "Event")
    {
        lua_pushcfunction(L, EntityEvent);
        return 1;
    }
    else if (key == "Write")
    {
        lua_pushcfunction(L, EntityWrite);
        return 1;
    }
    else if (key == "Read")
    {
        lua_pushcfunction(L, EntityRead);
        return 1;
    }

    return 0;
}

static int EntityBusIndex(lua_State* L)
{
    NativeEntity* entity = LuaEntityManager::GetEntity(1);
    std::string key = luaL_checkstring(L, 2);

    if (key == "data")
    {
        LuaUtils::Push(L, entity->GetEntityBus()->GetExposedObject());
        return 1;
    }

    return 0;
}

static const luaL_Reg s_entityMeta[] = { { "__index", EntityIndex }, { NULL, NULL } };
static const luaL_Reg s_entityBusMeta[] = { { "__index", EntityBusIndex }, { NULL, NULL } };

void LuaEntityManager::Register(lua_State* lua)
{
    s_lua = lua;

    luaL_Reg funcs[] = { { "Create", CreateEntityFunc }, {"GetList", GetListFunc}, { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(lua, "EntityManager", funcs);
    
    lua_pushcfunction(lua, ServerPlayerEventFunc);
    lua_setglobal(lua, "ServerPlayerEvent");

    lua_pushcfunction(lua, EntityEventFunc);
    lua_setglobal(lua, "EntityEvent");

    luaL_newmetatable(s_lua, "Entity");
    luaL_setfuncs(s_lua, s_entityMeta, 0);

    luaL_newmetatable(s_lua, "EntityBus");
    luaL_setfuncs(s_lua, s_entityBusMeta, 0);
}
} // namespace Kyber