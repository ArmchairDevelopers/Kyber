// Copyright Armchair Developers / Nuuby. Licensed under GPLv3.

#pragma once

#include <Network/StreamManager.h>

namespace Kyber
{

class CooldownModifierStreamedEvent : public KyberStreamedEvent
{
public:
    float data;

    void Write(BitStreamWrite* stream) override
    {
        stream->WriteFloat(data);
    }

    void Read(BitStreamRead* stream) override
    {
        data = stream->ReadFloat();
    }
};

KB_REGISTER_STREAMED_EVENT(CooldownModifierStreamedEvent);

class ClientPlayerGameplayManager : EventListener
{
public:
    ClientPlayerGameplayManager(EventManager* clientEventManager);
    ~ClientPlayerGameplayManager() override = default;

    virtual void OnEvent(const Event& event) override;
};

class ServerPlayerGameplayManager
{
public:
    static void SyncCooldownModifier(ServerPlayer* player, float modifier);
};
}
