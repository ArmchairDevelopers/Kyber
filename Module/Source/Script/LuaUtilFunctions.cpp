// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaUtilFunctions.h>
#include <Script/LuaDataContainer.h>
#include <SDK/Funcs.h>
#include <SDK/FB/Core.h>

#include <Core/Program.h>

namespace Kyber::Script
{
static int GetClientCameraTransformFunc(lua_State* L)
{
    LinearTransform* transform = (LinearTransform*)lua_newuserdata(L, sizeof(LinearTransform));
    memcpy(transform, &GameRenderer::Get()->renderView->transform, sizeof(LinearTransform));

    LuaValueTypeData data = { typeInfo_LinearTransform, transform };
    LuaUtils::Push(L, data);

    return 1;
}

static int GetActiveCameraTransformFunc(lua_State* L)
{
    LuaValueTypeData* value = LuaDataContainer::GetValueType(L, 1);
    if (value->type != typeInfo_LinearTransform)
    {
        luaL_error(L, "Expected LinearTransform, got %s", value->type->getName());
        return 0;
    }

    ClientPlayerManager* playerManager = ClientGameContext::Get()->GetPlayerManager();
    if (playerManager == nullptr)
    {
        return 1;
    }

    ClientPlayer* player = playerManager->GetLocalPlayer(LocalPlayerId_0);
    if (player == nullptr)
    {
        return 1;
    }

    Camera* camera = ClientCameraViewManager_getActiveCamera(player->cameraViewManager);
    if (camera == nullptr)
    {
        return 1;
    }

    LinearTransform& transform = *reinterpret_cast<LinearTransform*>(value->value);
    ClientCameraViewManager_getActiveCameraTransform(player->cameraViewManager, transform);
    return 1;
}

void RegisterUtilTable(lua_State* L)
{
    luaL_Reg funcs[] = { { "GetClientCameraTransform", GetClientCameraTransformFunc },
        { "GetActiveCameraTransform", GetActiveCameraTransformFunc }, { NULL, NULL } };
    KB_LUA_NEW_GLOBAL_LIB(L, "Utils", funcs);
}

KB_REGISTER_LUA_CONTENT(RegisterUtilTable);
} // namespace Kyber::Script
