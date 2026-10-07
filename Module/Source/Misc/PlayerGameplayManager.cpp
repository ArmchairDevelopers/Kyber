// Copyright Armchair Developers / Nuuby. Licensed under GPLv3.

#include <Misc/PlayerGameplayManager.h>
#include <Core/Program.h>

namespace Kyber
{
void ServerPlayerGameplayManager::SyncCooldownModifier(ServerPlayer* player, float modifier)
{
    ServerConnection* connection = g_program->m_server->GetServerGameContext()->m_serverPeer->GetConnectionForPlayer(player);
    CooldownModifierStreamedEvent* groupAssignedEvent = new (FB_GLOBAL_ARENA) CooldownModifierStreamedEvent();
    groupAssignedEvent->data = modifier;
    ServerStreamedEventManager::Send(connection, groupAssignedEvent);
}

ClientPlayerGameplayManager::ClientPlayerGameplayManager(EventManager* clientEventManager)
{ 
    clientEventManager->RegisterListener<CooldownModifierStreamedEvent>(this); 
}

void ClientPlayerGameplayManager::OnEvent(const Event& event)
{
    if (event.is<CooldownModifierStreamedEvent>())
    {
        const auto& cooldownModifiedEvent = event.as<CooldownModifierStreamedEvent>();
        ClientPlayer* player = ClientGameContext::Get()->GetPlayerManager()->GetLocalPlayer(LocalPlayerId_0);
        if (player == nullptr) 
        {
            return;
        }

        ClientCharacterEntity* character = player->GetCharacterEntity();
        if (character == nullptr)
        {
            return;
        }

        character->SetCooldownModifier(cooldownModifiedEvent.data);

        KYBER_LOG(Debug, "Set Client Cooldown Modifier To" << cooldownModifiedEvent.data);
    }
}
}
