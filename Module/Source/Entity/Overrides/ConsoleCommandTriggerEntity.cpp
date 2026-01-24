// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Entity/Overrides/ConsoleCommandTriggerEntity.h>

#include <Entity/KyberSettings.h>
#include <Core/Program.h>

namespace Kyber
{
static void** g_realmContext = (void**) 0x143FBA4B8;
TL_DECLARE_FUNC(0x1471A19F0, void*, RealmContext_setCurrentContext, void* context);

KB_IMPLEMENT_ENTITY_OVERRIDE(ConsoleCommandTriggerEntity, ConsoleCommandTriggerEntityData);

ConsoleCommandTriggerEntity::ConsoleCommandTriggerEntity(EntityManager* entityManager, NativeEntity* entity, ConsoleCommandTriggerEntityData* data)
    : KyberEntity(entity, data)
    , m_commandCount(0)
{
    auto delegate = fastdelegate::MakeDelegate(this, &ConsoleCommandTriggerEntity::Execute);

    m_name = data->CommandName;

    // We override it in Console.cpp
    if (strcmp(data->CommandName, "restart") == 0)
    {
        return;
    }
    
    ConsoleRegistry_registerInstanceMethod(delegate, m_name.c_str(), "Kyber");

    SetWantUpdates(true);
}

ConsoleCommandTriggerEntity::~ConsoleCommandTriggerEntity()
{
    g_program->m_console->UnregisterCommand(m_name.c_str());
}

void ConsoleCommandTriggerEntity::Execute(ConsoleContext& cc)
{
    m_commandCount++;
}

void ConsoleCommandTriggerEntity::Update(const UpdateParameters& params)
{
    if (m_commandCount == 0)
    {
        return;
    }

    // TODO: Set arguments with WriteField and the params in ConsoleContext.
    // Will require there to be more than just a counter.

    void* prev = RealmContext_setCurrentContext(g_realmContext[m_nativeEntity->GetRealm()]);
    for (int i = 0; i < m_commandCount; ++i)
    {
        FireEvent("OnCommand");
    }
    RealmContext_setCurrentContext(prev);

    m_commandCount = 0;
}
} // namespace Kyber
