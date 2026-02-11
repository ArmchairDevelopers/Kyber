#include <Entity/Entities/KyberDateTimeEntity.h>
#include <Core/Program.h>

#include <chrono>
#include <ctime>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberDateTimeEntityData)
{
    KyberTypeInfo info("KyberDateTimeEntityData", "EntityData");
    info.AddField("Boolean", "UseUtc");
    info.AddField("Int32", "Month");
    info.AddField("Int32", "Day");
    info.AddField("Int32", "Hour");
    info.AddField("Int32", "Minute");
    return info;
}

KB_IMPLEMENT_ENTITY(KyberDateTimeEntity, KyberDateTimeEntityData);

KyberDateTimeEntity::KyberDateTimeEntity(EntityManager* entityManager, NativeEntity* entity, KyberDateTimeEntityData* data)
    : KyberEntity(entity, data)
{
    UpdateDateTime(data->UseUtc);
}

void KyberDateTimeEntity::Event(EntityEvent* event)
{
    if (!event->Is("Update"))
    {
        return;
    }

    // KYBER_LOG(Info, "[Module] Updating time for date time entity");
    UpdateDateTime(GetData()->UseUtc);
}

void KyberDateTimeEntity::PropertyChanged(PropertyModification* modification)
{
    if (!modification->Is("UseUtc"))
    {
        return;
    }

    bool useUtc = *reinterpret_cast<bool*>(modification->value);
    UpdateDateTime(useUtc);
}

void KyberDateTimeEntity::UpdateDateTime(bool useUtc)
{
    auto now = std::chrono::system_clock::now();
    std::time_t now_c = std::chrono::system_clock::to_time_t(now);
    std::tm* time_info;

    if (useUtc)
    {
        time_info = std::gmtime(&now_c);
    }
    else
    {
        time_info = std::localtime(&now_c);
    }

    if (!time_info)
    {
        return;
    }

    const TypeInfo* int32Type = g_program->m_entityManager->GetNativeType("Int32");
    if (!int32Type)
    {
        return;
    }

    int32_t month = time_info->tm_mon + 1;
    int32_t day = time_info->tm_mday;
    int32_t hour = time_info->tm_hour;
    int32_t minute = time_info->tm_min;

    WriteField("Month", int32Type, &month);
    WriteField("Day", int32Type, &day);
    WriteField("Hour", int32Type, &hour);
    WriteField("Minute", int32Type, &minute);
}
} // namespace Kyber
