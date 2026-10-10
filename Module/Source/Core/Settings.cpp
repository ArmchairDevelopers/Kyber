#include <Core/Settings.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

namespace Kyber
{
KyberSettingsManager::KyberSettingsManager() {}

void KyberSettingsManager::RegisterSettings(const char* groupName, TypeInfo* typeInfo)
{
    m_registeredSettings.push_back({ groupName, typeInfo });
}

void KyberSettingsManager::ApplySettings()
{
    if (g_program->m_entityManager == nullptr)
    {
        return;
    }

    for (const auto& settings : m_registeredSettings)
    {
        DataContainer* instance = g_program->m_entityManager->CreateContainer<DataContainer>(settings.typeInfo->getName());
        SettingsManager_add(g_program->GetSettingsManager(), settings.groupName.c_str(), instance, true, "", settings.typeInfo, true);
    }
}
} // namespace Kyber
