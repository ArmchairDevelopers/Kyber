#pragma once

#include <Entity/NativeEntityManager.h>

namespace Kyber
{
class KyberDateTimeEntityData : public EntityData
{
public:
    bool UseUtc;
    int32_t Month;
    int32_t Day;
    int32_t Hour;
    int32_t Minute;
};

class KyberDateTimeEntity : public KyberEntity<KyberDateTimeEntityData>
{
public:
    KyberDateTimeEntity(EntityManager* entityManager, NativeEntity* entity, KyberDateTimeEntityData* data);

    void Event(EntityEvent* event) override;
    void PropertyChanged(PropertyModification* modification) override;

private:
    void UpdateDateTime(bool useUtc);
};
} // namespace Kyber
