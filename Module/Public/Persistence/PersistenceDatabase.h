// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Network/SocketManager.h>
#include <SDK/SDK.h>
#include <SDK/TypeInfo.h>
#include <Core/Settings.h>

#include <RPC/API/Statistics.h>

#include <EASTL/hash_map.h>

#include <Windows.h>
#include <string>

#include <map>

namespace Kyber
{
class PersistentStorageTemplate
{
public:
    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x140A7B9D0, uint32_t, GetCount)
    KB_DECLARE_GAMEMEMBERFUNC(0x1467D3220, const char*, GetName, (offset), uint32_t offset)
    KB_DECLARE_GAMEMEMBERFUNC(0x1467D32D0, uint32_t, GetOffset, (name), const char* name)
};

class PersistentStorage
{
public:
    struct Value
    {
        float current;
        float reference;
        float original;
    };

    typedef eastl::vector<Value> Values;

    Values m_values;
    char m_padding[0x70 - sizeof(Values)];

    __declspec(align(16)) PersistentStorageTemplate* m_template;
};

class PersistenceDatabase
{
public:
    virtual ~PersistenceDatabase() = default;

    virtual void Load(const OnlineId& id, std::function<void(PlayerStatsMap)> callback) = 0;
    virtual void Save(const OnlineId& id, const PlayerStatsMap& stats) = 0;
};

class APIPersistenceDatabase : public PersistenceDatabase
{
public:
    explicit APIPersistenceDatabase(kyber_api::StatsSource source);

    void Load(const OnlineId& id, std::function<void(PlayerStatsMap)> callback) override;
    void Save(const OnlineId& id, const PlayerStatsMap& stats) override;

private:
    kyber_api::StatsSource m_source;
};
} // namespace Kyber