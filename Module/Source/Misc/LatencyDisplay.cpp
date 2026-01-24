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

// NOTE: This display is not regarded as being accurate, as it gives absurdly large
// numbers (around 200ms for locally hosted servers, when that should be 0)
// It is not to be put in prod until that is fixed.

class LatencyDisplay : public GenericUpdateListener
{
public:
    void Update(UpdateType type, const UpdateParameters& params) override
    {
        return;

        KyberSettings* settings = Settings<KyberSettings>("Kyber");
        if (settings == nullptr)
        {
            return;
        }

        if (ClientGameContext::Get()->onlineManager == nullptr)
        {
            return;
        }

        void* connection = OnlineManager_clientConnection(ClientGameContext::Get()->onlineManager);
        if (connection == nullptr)
        {
            return;
        }

        float latency = ClientConnection_getAverageLatency(connection) * 1000;

        char buf[100];
        snprintf(buf, 100, "Latency: %.3fms", latency);

        DebugRenderer_drawText(20, 20, Color32(0, 255, 0), buf, 1);
    }
};

static LatencyDisplay s_latencyDisplay;

KB_REGISTER_GENERIC_UPDATE_LISTENER(s_latencyDisplay, UpdateType_Client_PostFrame);
} // namespace Kyber
