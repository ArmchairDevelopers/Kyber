// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Hook/HookManager.h>
#include <Core/Console.h>
#include <Core/Program.h>
#include <Utilities/PlatformUtils.h>
#include <SDK/Funcs.h>
#include <Entity/KyberSettings.h>
#include <SDK/TypeInfo.h>

namespace Kyber
{
class LatencyDisplay : public GenericUpdateListener
{
public:
    void Update(UpdateType type, const UpdateParameters& params) override
    {
        KyberSettings* kyberSettings = Settings<KyberSettings>("Kyber");
        PerfOverlaySettings* perfOverlaySettings = Settings<PerfOverlaySettings>("PerfOverlay");
        if (kyberSettings == nullptr || perfOverlaySettings == nullptr)
        {
            return;
        }

        if (!kyberSettings->RenderLatencyDisplay && !perfOverlaySettings->DrawFps)
        {
            return;
        }

        if (ClientGameContext::Get()->onlineManager == nullptr)
        {
            return;
        }

        ClientConnection* connection = ClientGameContext::Get()->GetOnlineManager()->GetClientConnection();
        if (connection == nullptr)
        {
            return;
        }

        float latency = connection->GetAverageLatency() * 1000;

        char buf[100];
        snprintf(buf, 100, "Latency: %.3fms", latency);

        DebugRenderer_drawText(20, 20, Color32(0, 255, 0), buf, 1);
    }
};

static LatencyDisplay s_latencyDisplay;

KB_REGISTER_GENERIC_UPDATE_LISTENER(s_latencyDisplay, UpdateType_Client_PostFrame);
} // namespace Kyber
