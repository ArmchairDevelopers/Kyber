#include <Voip/UI/KyberVoipSettingsEntity.h>

#include <Core/Program.h>
#include <Utilities/StringUtils.h>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberVoipSettingsEntityData)
{
    KyberTypeInfo info("KyberVoipSettingsEntityData", "EntityData");
    info.AddField("Float32", "InputVolume");
    return info;
}

KB_IMPLEMENT_ENTITY(KyberVoipSettingsEntity, KyberVoipSettingsEntityData);

KyberVoipSettingsEntity::KyberVoipSettingsEntity(EntityManager* entityManager, NativeEntity* entity, KyberVoipSettingsEntityData* data)
    : KyberEntity(entity, data)
{
    KYBER_LOG(Info, "Created Voip Settings entity");
}

void KyberVoipSettingsEntity::PropertyChanged(PropertyModification* modification)
{
    if (modification->Is("InputVolume"))
    {
        float newVolume = round(*reinterpret_cast<float*>(modification->value) * 100);
        KYBER_LOG(Info, "Voip volume changed: " << newVolume);

        if (g_program->m_client->m_voipManager != nullptr)
        {
            g_program->m_client->m_voipManager->SetInputVolume(newVolume);
        }
    }
}
} // namespace Kyber
