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
    m_dateStrOut = CreateFieldOverride<char*>("DateString", g_program->m_entityManager->GetNativeType("CString"));
    m_dayStrOut = CreateFieldOverride<char*>("DayString", g_program->m_entityManager->GetNativeType("CString"));
    m_monthStrOut = CreateFieldOverride<char*>("MonthString", g_program->m_entityManager->GetNativeType("CString"));
    m_yearStrOut = CreateFieldOverride<char*>("YearString", g_program->m_entityManager->GetNativeType("CString"));
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
    if (fieldValue.HasConnection())
    {
        bool hasValue = fieldValue.HasConnectionValue();
        if (hasValue)
        {
            currentTime = fieldValue.Get();
        }
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

    // Use strftime to get day/month/year names from dates and save them to a buffer
    char* dateStr = new char[100];
    strftime(dateStr, 100, "%A, %B %d, %Y", time);
    char* dayStr = new char[10];;
    strftime(dayStr, 10, "%A", time);
    char* monthStr = new char[10];;
    strftime(monthStr, 10, "%d", time);
    char* yearStr = new char[10];;
    strftime(yearStr, 10, "%Y", time);

    // Get Second, Minute, Hour, Day, Month, Year
    int second = time->tm_sec;
    int minute = time->tm_min;
    int hour = time->tm_hour;
    int day = time->tm_mday;
    int month = time->tm_mon + 1;
    int year = time->tm_year + 1900;

    // Update property outputs
    m_dateStrOut = &dateStr;
    m_dayStrOut = &dayStr;
    m_monthStrOut = &monthStr;
    m_yearStrOut = &yearStr;
    m_dayIntOut = &day;
    m_monthIntOut = &month;
    m_yearIntOut = &year;
    m_secIntOut = &second;
    m_minIntOut = &minute;
    m_hourIntOut = &hour;
}
} // namespace Kyber
