// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#pragma once

#include <Core/EventManager.h>

#include <EASTL/vector.h>

#include <cstdint>

namespace Kyber
{
class ServerPlayer;

class ClientSquadManager : EventListener
{
public:
    using PlayerId = uint64_t;

    ClientSquadManager(EventManager* clientEventManager);
    ~ClientSquadManager() override = default;

    virtual void OnEvent(const Event& event) override;

    static void InitializeHooks();

    eastl::vector<PlayerId> m_squadMates;
};
} // namespace Kyber