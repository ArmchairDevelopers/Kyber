// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Entity/KyberSettings.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberSettings)
{
    KyberTypeInfo info("KyberSettings", "SystemSettings");
    info.AddField("Boolean", "DisableTeamBalancing");
    info.AddField("Boolean", "EnableShuffleTeams");
    info.AddField("Boolean", "RenderBundles");
    info.AddField("Boolean", "RenderPropertyDebug");
    info.AddField("Boolean", "RenderCameraDebug");
    info.AddField("Boolean", "EnableUnlimitedPowerEvent");
    info.AddField("Float32", "BundleDebugFontSize");
    info.AddField("Int32", "unused1");
    info.AddField("Int32", "unused2");
    info.AddField("Int32", "unused3");
    info.AddField("Int32", "unused4");
    return info;
}

KB_TYPE_REGISTRATION_CALLBACK(KyberSettings)
{
    KYBER_LOG(Info, "[Entity] Registered Kyber Settings");
    g_program->m_settingsManager->RegisterSettings("Kyber", typeInfo);
}
} // namespace Kyber
