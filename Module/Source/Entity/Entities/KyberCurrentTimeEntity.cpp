// Copyright Armchair Developers. Licensed under GPLv3.

#include <Entity/Entities/KyberCurrentTimeEntity.h>

#include <Core/Program.h>

#include <chrono>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberCurrentTimeEntityData)
{
    KyberTypeInfo info("KyberCurrentTimeEntityData", "EntityData");
    info.AddField("Boolean", "EnableUpdates");
    return info;
}

KB_IMPLEMENT_ENTITY(KyberCurrentTimeEntity, KyberCurrentTimeEntityData);

KyberCurrentTimeEntity::KyberCurrentTimeEntity(EntityManager* entityManager, NativeEntity* entity, KyberCurrentTimeEntityData* data)
    : KyberEntity(entity, data)
{
    m_timeOut = CreateFieldOverride<float>("Time", g_program->m_entityManager->GetNativeType("Float32"));

    SetWantUpdates(data->EnableUpdates);
}

void KyberCurrentTimeEntity::Event(EntityEvent* event)
{
    if (event->Is("Update"))
    {
        float currentTime = GetTime();
        m_timeOut = &currentTime;
        FireEvent("OnUpdate");
    }
}

void KyberCurrentTimeEntity::Update(const UpdateParameters& params)
{
    float currentTime = GetTime();
    m_timeOut = &currentTime;
}

float KyberCurrentTimeEntity::GetTime()
{
    auto now = std::chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    auto seconds = std::chrono::duration_cast<std::chrono::duration<float>>(duration);
    return seconds.count();
}
} // namespace Kyber
