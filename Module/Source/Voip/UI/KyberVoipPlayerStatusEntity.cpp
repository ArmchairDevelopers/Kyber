#include <Voip/UI/KyberVoipPlayerStatusEntity.h>

#include <Core/Program.h>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberVoipPlayerStatusEntityData)
{
    KyberTypeInfo info("KyberVoipPlayerStatusEntityData", "EntityData");
    info.AddField("CString", "PlayerName");
    return info;
}

KB_IMPLEMENT_ENTITY(KyberVoipPlayerStatusEntity, KyberVoipPlayerStatusEntityData);

KyberVoipPlayerStatusEntity::KyberVoipPlayerStatusEntity(EntityManager* entityManager, NativeEntity* entity, KyberVoipPlayerStatusEntityData* data) 
    : KyberEntity(entity, data)
{
    SetWantUpdates(true);

    m_isPlayerTalking = CreateFieldOverride<bool>("IsPlayerTalking", g_program->m_entityManager->GetNativeType("Boolean"));
}

void KyberVoipPlayerStatusEntity::Update(const UpdateParameters& params)
{
    char* m_currentPlayer = nullptr;

    PropertyReader<char*> playerString = GetFieldReader<char*>("PlayerName");
    if (playerString.HasConnection())
    {
        bool hasValue = playerString.HasConnectionValue();
        if (hasValue)
        {
            m_currentPlayer = playerString.Get();
        }
    }

    if (!m_currentPlayer)
    {
        KYBER_LOG(Trace, "[VoIP] KyberVoipPlayerStatusEntity couldn't find a player!");
        return;
    }

    bool isPlayerSpeaking = g_program->m_client->m_voipManager->IsParticipantSpeaking(m_currentPlayer);
    m_isPlayerTalking = &isPlayerSpeaking;

    // KYBER_LOG(Trace, "[VoIP] Speaking Status for " << m_currentPlayer << " is " << isPlayerSpeaking);
}
} // namespace Kyber
