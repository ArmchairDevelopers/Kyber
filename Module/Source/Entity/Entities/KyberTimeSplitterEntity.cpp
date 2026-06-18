// Copyright Armchair Developers. Licensed under GPLv3.

#include <Entity/Entities/KyberTimeSplitterEntity.h>

#include <Core/Program.h>

#include <chrono>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberTimeSplitterEntityData)
{
    KyberTypeInfo info("KyberTimeSplitterEntityData", "EntityData");
    info.AddField("Boolean", "UseUTC");
    return info;
}

KB_IMPLEMENT_ENTITY(KyberTimeSplitterEntity, KyberTimeSplitterEntityData);

KyberTimeSplitterEntity::KyberTimeSplitterEntity(EntityManager* entityManager, NativeEntity* entity, KyberTimeSplitterEntityData* data)
    : KyberEntity(entity, data)
{
    m_dayIntOut = CreateFieldOverride<int>("DayInt", g_program->m_entityManager->GetNativeType("Int32"));
    m_monthIntOut = CreateFieldOverride<int>("MonthInt", g_program->m_entityManager->GetNativeType("Int32"));
    m_yearIntOut = CreateFieldOverride<int>("YearInt", g_program->m_entityManager->GetNativeType("Int32"));
    m_secIntOut = CreateFieldOverride<int>("SecondInt", g_program->m_entityManager->GetNativeType("Int32"));
    m_minIntOut = CreateFieldOverride<int>("MinuteInt", g_program->m_entityManager->GetNativeType("Int32"));
    m_hourIntOut = CreateFieldOverride<int>("HourInt", g_program->m_entityManager->GetNativeType("Int32"));
}

void KyberTimeSplitterEntity::PropertyChanged(PropertyModification* modification)
{
    float currentTime = 0;

    PropertyReader<float> fieldValue = GetFieldReader<float>("Time");
    if (fieldValue.HasConnectionValue())
    {
        currentTime = fieldValue.Get();
    }

    if (currentTime <= 0)
    {
        return;
    }
    
    // Convert to time_point from float
    auto duration = std::chrono::duration<float>(currentTime);
    auto timePoint = std::chrono::system_clock::time_point(
        std::chrono::duration_cast<std::chrono::system_clock::duration>(duration)
    );

    std::time_t sysClockTime = std::chrono::system_clock::to_time_t(timePoint);
    std::tm* time = GetData()->UseUTC ? std::gmtime(&sysClockTime) : std::localtime(&sysClockTime);

    // Get Second, Minute, Hour, Day, Month, Year
    int second = time->tm_sec;
    int minute = time->tm_min;
    int hour = time->tm_hour;
    int day = time->tm_mday;
    int month = time->tm_mon + 1;
    int year = time->tm_year + 1900;

    // Update property outputs
    m_dayIntOut = &day;
    m_monthIntOut = &month;
    m_yearIntOut = &year;
    m_secIntOut = &second;
    m_minIntOut = &minute;
    m_hourIntOut = &hour;
}
} // namespace Kyber
