// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Hook/HookManager.h>
#include <Core/Console.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <SDK/Funcs.h>
#include <Entity/KyberSettings.h>

namespace Kyber
{
typedef LinearTransform*(__fastcall* SpatialEntity_getTransform_t)(Camera* inst);

class CameraManager : public GenericUpdateListener
{
public:
    void Update(UpdateType type, const UpdateParameters& params) override
    {
        KyberSettings* settings = Settings<KyberSettings>("Kyber");
        if (settings == nullptr || !settings->RenderCameraDebug)
        {
            return;
        }

        ClientPlayerManager* playerManager = ClientGameContext::Get()->GetPlayerManager();
        if (playerManager == nullptr)
        {
            return;
        }

        ClientPlayer* player = playerManager->GetLocalPlayer(LocalPlayerId_0);
        if (player == nullptr)
        {
            return;
        }

        Camera* camera = ClientCameraViewManager_getActiveCamera(player->cameraViewManager);
        if (camera == nullptr)
        {
            return;
        }

        DebugRenderer_drawText(10, 10, Color32(0, 255, 0, 255),
            StringUtils::Format("Camera: %p [ViewManager: %p]", camera, player->cameraViewManager));

        DebugRenderer_drawText(10, 24, Color32(0, 255, 0, 255),
            StringUtils::Format("Camera Type: %s", camera->getType()->getName()));

        DebugRenderer_drawText(10, 38, Color32(0, 255, 0, 255),
            StringUtils::Format("Camera Data: %s", camera->m_data->m_dcType->getName()));
            
        //LinearTransform cameraTransform;
        //ClientCameraViewManager_getActiveCameraTransform(player->cameraViewManager, cameraTransform);

        auto func = reinterpret_cast<SpatialEntity_getTransform_t>(PlatformUtils::GetVTableFunction(camera, 4));
        LinearTransform* cameraTransform = func(camera);

        // Copy
        LinearTransform copy;
        LinearTransform_copyCtor(cameraTransform, &copy);

        DebugRenderer_drawText(10, 52, Color32(0, 255, 0, 255),
            StringUtils::Format("Camera Pos: (%7.3f, %7.3f, %7.3f)", copy.trans.x, copy.trans.y, copy.trans.z));

        ClientSoldierEntity* entity = player->controlledControllable;
        if (entity == nullptr)
        {
            return;
        }

        if (strcmp(entity->getType()->getName(), "WSClientSoldierEntity") != 0)
        {
            return;
        }

        DebugRenderer_drawText(10, 52 + 14, Color32(0, 255, 0, 255),
            StringUtils::Format("Entity: %p", entity));
    }
};

static CameraManager s_cameraManager;

KB_REGISTER_GENERIC_UPDATE_LISTENER(s_cameraManager, UpdateType_Client_PostFrame);
} // namespace Kyber
