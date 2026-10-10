// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Entity/Entities/KyberFakeChatEntity.h>

#include <Core/Program.h>

namespace Kyber
{
KB_IMPLEMENT_TYPE(KyberFakeChatEntityData)
{
    KyberTypeInfo info("KyberFakeChatEntityData", "EntityData");
    info.AddField("CString", "Name");
    info.AddField("CString", "Message");
    info.AddField("Uint32", "Channel");
    return info;
}

KB_IMPLEMENT_ENTITY(KyberFakeChatEntity, KyberFakeChatEntityData);

KyberFakeChatEntity::KyberFakeChatEntity(EntityManager* entityManager, NativeEntity* entity, KyberFakeChatEntityData* data)
    : KyberEntity(entity, data)
{}

void KyberFakeChatEntity::Event(EntityEvent* event)
{
    if (event->eventId == StringUtils::HashQuick("Send"))
    {
        if (!g_program->m_server->IsRunning())
        {
            return;
        }

        std::string name = GetField("Name");
        std::string message = GetField("Message");
        g_program->m_server->BroadcastMessage(message, name, GetData()->Channel);
    }
}

std::string KyberFakeChatEntity::GetField(const char* fieldName) const
{
    auto nameField = KyberEntityBase::GetFieldReader<char*>("Name");
    if (!nameField.HasConnection() || !nameField.HasConnectionValue())
    {
        return GetData()->Name;
    }

    return nameField.Get();
}
} // namespace Kyber
