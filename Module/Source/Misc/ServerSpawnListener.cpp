#include <Misc/ServerSpawnListener.h>

#include <Base/Log.h>
#include <Hook/HookManager.h>
#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>
#include <SDK/Funcs.h>

#define OFFSET_SERVERSPAWNMANAGER_ONMESSAGE HOOK_OFFSET(0x141BC03F0)

namespace Kyber
{

void ServerSpawnManagerOnMessageHk(__int64 a1, Message* msg)
{
    static const auto trampoline = HookManager::Call(ServerSpawnManagerOnMessageHk);

    if (!msg->Is("NetworkPlayerSpawnMessage"))
    {
        trampoline(a1, msg);
        return;
    }
    
    NetworkPlayerSpawnMessage* spawnMessage = static_cast<NetworkPlayerSpawnMessage*>(msg);

    ServerPlayer* player = spawnMessage->serverConnection->GetPlayer(spawnMessage->localPlayerId, true);
    if (player != nullptr && player->GetCharacterEntity() != nullptr)
    {
        KYBER_LOG(Warning,"[ServerSpawnListener] " << player->m_name << " (" << player->m_onlineId.m_nativeData << ") tried spawning whilst already spawned in");
        return;
    }

    // TODO implement NetworkPlayerSpawnWithLoadoutMessage
    KYBER_LOG(Debug, "[ServerSpawnListener] " << player->m_name << " spawned");

    trampoline(a1, msg);
}


void InitializeSpawnListenerHook()
{
    HookManager::CreateHook(OFFSET_SERVERSPAWNMANAGER_ONMESSAGE, ServerSpawnManagerOnMessageHk);
}
}