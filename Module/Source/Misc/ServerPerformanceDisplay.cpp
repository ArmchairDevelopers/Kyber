// Copyright Armchair Developers. Licensed under GPLv3.

#include <Core/Program.h>
#include <Entity/KyberSettings.h>
#include <Network/StreamManager.h>

#include <numeric>

namespace Kyber
{

class KyberServerPerformanceEvent : public KyberStreamedEvent
{
    KyberServerPerformanceEvent(float tps)
        : m_tps(tps)
    {}

    void Write(BitStreamWrite* stream) override
    {
        stream->WriteFloat(m_tps);
    }

    void Read(BitStreamRead* stream) override
    {
        m_tps = stream->ReadFloat();
    }

    float m_tps;
};

class ServerPerformanceDisplay : public GenericUpdateListener
{
public:
    void Update(UpdateType type, const UpdateParameters& params) override
    {
        KyberSettings* settings = Settings<KyberSettings>("Kyber");
        if (settings == nullptr || !settings->RenderServerPerformance)
        {
            return;
        }

        float rawDelta = params.simulationDeltaTimeUnscaled.toSecondsAsFloat();

        char buf[50];
        snprintf(buf, sizeof(buf), "Instant TPS: %.1f / %.1f", 1 / rawDelta, rawDelta * 1000);

        DebugRenderer_drawText(20, 20, Colors::GREEN, buf, 1);

        char buf2[50];

        m_pastTicks[m_pastTicksIndex++] = rawDelta;
        if (m_pastTicksIndex >= sizeof(m_pastTicks) / sizeof(*m_pastTicks))
        {
            m_pastTicksIndex = 0;
        }
        
        float averageTps = std::accumulate(m_pastTicks, m_pastTicks + 30, 0.f) / 30.f;

        snprintf(buf2, sizeof(buf2), "Average TPS: %.1f / %.1f", 1 / averageTps, averageTps * 1000);

        DebugRenderer_drawText(20, 40, Colors::GREEN, buf2, 1);
    }

    float m_lastSecond;
    uint8_t m_pastTicksIndex;
    float m_pastTicks[30];
};

static ServerPerformanceDisplay s_serverPerformanceDisplay;

KB_REGISTER_GENERIC_UPDATE_LISTENER(s_serverPerformanceDisplay, UpdateType_Server_PreFrame);
} // namespace Kyber
