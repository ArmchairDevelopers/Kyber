// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Persistence/PersistenceDatabase.h>

#include <Core/Program.h>
#include <Base/Log.h>
#include <Hook/HookManager.h>
#include <Core/Memory.h>
#include <Core/Console.h>
#include <Utilities/MemoryUtils.h>

namespace Kyber
{
APIPersistenceDatabase::APIPersistenceDatabase(kyber_api::StatsSource source)
    : m_source(source)
{}

void APIPersistenceDatabase::Load(const OnlineId& id, std::function<void(PlayerStatsMap)> callback)
{
    g_program->GetAPI()->GetStatistics()->GetStats(
        m_source, std::to_string(id.m_nativeData), [&, callback = std::move(callback)](std::optional<PlayerStatsMap> stats) {
            if (!stats)
            {
                KYBER_LOG(Error, "Failed to load persistence for player " << id.m_id);
                return;
            }

            callback(*stats);
        });
}

void APIPersistenceDatabase::Save(const OnlineId& id, const PlayerStatsMap& stats)
{
    g_program->GetAPI()->GetStatistics()->UpdateStats(m_source, std::to_string(id.m_nativeData), stats);
}
} // namespace Kyber
