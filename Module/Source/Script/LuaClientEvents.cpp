// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Script/LuaClientEvents.h>

#include <Core/Program.h>
#include <Hook/HookManager.h>
#include <Script/LuaDataContainer.h>
#include <SDK/Funcs.h>
#include <Utilities/PlatformUtils.h>

namespace Kyber
{
TL_DECLARE_FUNC(0x146A70100, Camera*, CameraScene_getActiveCamera, void* inst);
typedef LinearTransform*(__fastcall* Camera_getTransform_t)(Camera* inst);

typedef void CameraScene;

KB_LUA_DECLARE_TABLE(CameraScene*, CameraScene);
KB_LUA_DECLARE_TABLE(Camera*, Camera);

void* ClientCameraManagerPushHk(void* inst, CameraScene* scene, uint32_t priority, LocalPlayerId localPlayerId, LocalPlayerViewId viewId)
{
    static const auto trampoline = HookManager::Call(ClientCameraManagerPushHk);
    void* result = trampoline(inst, scene, priority, localPlayerId, viewId);
    
    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire("ClientCameraManager:Push", scene);
    }
    
    return result;
}

static int CameraSceneIndex(lua_State* L)
{
    CameraScene* camera = GetCameraScene(L, 1);
    if (camera == nullptr)
    {
        return 0;
    }

    std::string key = luaL_checkstring(L, 2);
    if (key == "activeCamera")
    {
        Camera* activeCamera = CameraScene_getActiveCamera(camera);
        LuaUtils::Push(L, activeCamera);
        return 1;
    }

    return 0;
}

KB_LUA_CREATE_TABLE(CameraScene*, CameraScene)
KB_LUA_FUNCTION("__index", CameraSceneIndex)
KB_LUA_END_TABLE(CameraScene)

static int CameraIndex(lua_State* L)
{
    Camera* camera = GetCamera(L, 1);
    if (camera == nullptr)
    {
        KYBER_LOG(Warning, "Camera is null");
        return 0;
    }

    std::string key = luaL_checkstring(L, 2);
    if (key == "transform")
    {
        auto func = reinterpret_cast<Camera_getTransform_t>(PlatformUtils::GetVTableFunction(camera, 4));
        LinearTransform* transform = func(camera);

        const TypeInfo* type = g_program->m_entityManager->GetNativeType("LinearTransform");
        LinearTransform* copied = reinterpret_cast<LinearTransform*>(LuaDataContainer::ValueTypeCreate(L, type));
        LinearTransform_copyCtor(transform, copied);

        KYBER_LOG(Info, "Camera: " << std::hex << camera);
        LuaValueTypeData data = { type, copied };
        LuaUtils::Push(L, data);
        return 1;
    }
    else if (key == "data")
    {
        LuaUtils::Push(L, camera->m_data);
        return 1;
    }
    else if (key == "typeInfo")
    {
        LuaUtils::Push(L, camera->getType());
        return 1;
    }

    return 0;
}

KB_LUA_CREATE_TABLE(Camera*, Camera)
KB_LUA_FUNCTION("__index", CameraIndex)
KB_LUA_END_TABLE(Camera)

namespace Script
{
void RegisterClientEvents(lua_State* L)
{
    RegisterCameraScene(L);
    RegisterCamera(L);

    HookManager::CreateHook(HOOK_OFFSET(0x1465C52F0), ClientCameraManagerPushHk);
}
} // namespace Script
} // namespace Kyber
