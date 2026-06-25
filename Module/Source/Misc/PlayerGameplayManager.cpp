// Copyright Armchair Developers / Nuuby. Licensed under GPLv3.

#include <Misc/PlayerGameplayManager.h>
#include <Core/Program.h>

namespace Kyber
{
ClientPlayerGameplayManager::ClientPlayerGameplayManager(EventManager* clientEventManager)
{
    clientEventManager->RegisterListener<CooldownModifierStreamedEvent>(this);
}

void ClientPlayerGameplayManager::OnEvent(const Event& event)
{
    if (event.is<CooldownModifierStreamedEvent>())
    {
        const auto& cooldownModifiedEvent = event.as<CooldownModifierStreamedEvent>();
        ClientGameContext::Get()->GetPlayerManager()->GetLocalPlayer(LocalPlayerId_0)->GetCharacterEntity()
            ->SetCooldownModifier(cooldownModifiedEvent.data);

        KYBER_LOG(Debug, "Set Client Cooldown Modifier To" << cooldownModifiedEvent.data);
    }
}

void ServerPlayerGameplayManager::SyncCooldownModifier(ServerPlayer* player, float modifier)
{
    ServerConnection* connection = g_program->m_server->GetServerGameContext()->m_serverPeer->GetConnectionForPlayer(player);
    CooldownModifierStreamedEvent* groupAssignedEvent = new (FB_GLOBAL_ARENA) CooldownModifierStreamedEvent();
    groupAssignedEvent->data = modifier;
    ServerStreamedEventManager::Send(connection, groupAssignedEvent);
}
}
