#pragma once

#include <Entity/NativeEntityManager.h>

#include <Core/DebugHooks.h>

namespace Kyber
{

// There is a bug in the current type building algorithm that 
// fails to correctly pad the types. It immediately causes a crash
// if not done properly, and for now requires trial and error to get correct.
// This class is padded to 0x10 + 0xA

class KyberSettings : public SystemSettings
{
public:
    bool DisableTeamBalancing;
    bool EnableShuffleTeams;
    bool RenderBundles;
    bool RenderPropertyDebug;
    bool RenderCameraDebug;
    bool EnableUnlimitedPowerEvent;
    bool LogFilteredChatMessages;
    bool RenderServerPerformance;
    bool RenderLatencyDisplay;
    float BundleDebugFontSize;
    int32_t unused1;
    int32_t unused2;
    int32_t unused3;
};
} // namespace Kyber
