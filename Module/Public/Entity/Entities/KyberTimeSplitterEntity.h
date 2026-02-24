// Copyright Armchair Developers. Licensed under GPLv3.

#pragma once

#include <Entity/NativeEntityManager.h>

namespace Kyber
{
class KyberTimeSplitterEntityData : public EntityData
{
public:
    bool UseUTC;
};
    
class KyberTimeSplitterEntity : public KyberEntity<KyberTimeSplitterEntityData>
{
public:
    KyberTimeSplitterEntity(EntityManager* entityManager, NativeEntity* entity, KyberTimeSplitterEntityData* data);

    void PropertyChanged(PropertyModification* modification) override;
    
private:
    PropertyWriter<char*> m_dateStrOut;
    PropertyWriter<int> m_secIntOut;
    PropertyWriter<int> m_minIntOut;
    PropertyWriter<int> m_hourIntOut;
    PropertyWriter<char*> m_dayStrOut;
    PropertyWriter<char*> m_monthStrOut;
    PropertyWriter<char*> m_yearStrOut;
    PropertyWriter<int> m_dayIntOut;
    PropertyWriter<int> m_monthIntOut;
    PropertyWriter<int> m_yearIntOut;
};
} // namespace Kyber
