// Copyright Armchair Developers. Licensed under GPLv3.

#pragma once

#include <Entity/NativeEntityManager.h>

namespace Kyber
{
class KyberCurrentTimeEntityData : public EntityData
{
public:
    bool EnableUpdates;
};
    
class KyberCurrentTimeEntity : public KyberEntity<KyberCurrentTimeEntityData>
{
public:
    KyberCurrentTimeEntity(EntityManager* entityManager, NativeEntity* entity, KyberCurrentTimeEntityData* data);

    void Event(EntityEvent* event) override;
    void Update(const UpdateParameters& params) override;
    float GetTime();

private:
    PropertyWriter<float> m_timeOut;
};
} // namespace Kyber
