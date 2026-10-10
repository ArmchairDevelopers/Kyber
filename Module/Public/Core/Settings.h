// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <SDK/TypeInfo.h>

#include <Windows.h>
#include <string>

namespace Kyber
{
struct MapRotationEntry
{
    MapRotationEntry(const std::string& level, const std::string& mode)
        : level(level)
        , mode(mode)
    {}

    std::string level;
    std::string mode;
};

class MapRotation
{
public:
    const MapRotationEntry& GetNextEntry()
    {
        KYBER_ASSERT(m_entries.size() > 0);

        if (m_current + 1 > m_entries.size())
        {
            m_current = 0;
        }

        return m_entries[m_current++];
    }

    const MapRotationEntry& PeekNextEntry() const
    {
        KYBER_ASSERT(m_entries.size() > 0);

        uint16_t peakCurrent = m_current;
        if (peakCurrent + 1 > m_entries.size())
        {
            peakCurrent = 0;
        }

        return m_entries[peakCurrent];
    }

    void Reset()
    {
        m_entries.clear();
        m_current = 0;
    }

    void AddEntry(const std::string& level, const std::string& mode)
    {
        m_entries.emplace_back(level, mode);
    }

    void RemoveNextEntry()
    {
        if (m_entries.size() <= 0)
        {
            KYBER_LOG(Error, "Attempted to remove entry when nothing exists in the rotation.");
            return;
        }

        if (m_entries.size() == 1)
        {
            KYBER_LOG(Warning, "Attempted to remove next entry in map rotation when there is only one entry in the list.");
            return;
        }

        uint16_t peakCurrent = m_current;
        if (peakCurrent + 1 > m_entries.size())
        {
            peakCurrent = 0;
        }

        m_entries.erase(m_entries.begin() + peakCurrent);
    }

    // Returns a copy of the map rotation
    std::vector<MapRotationEntry> GetList() const
    {
        return m_entries;
    }

    uint16_t GetIndex() const
    {
        return m_current;
    }

private:
    std::vector<MapRotationEntry> m_entries;
    uint16_t m_current;
};

class KyberSettingsManager
{
public:
    KyberSettingsManager();

    void RegisterSettings(const char* groupName, TypeInfo* typeInfo);
    void ApplySettings();

private:
    struct RegisteredSettings
    {
        std::string groupName;
        TypeInfo* typeInfo;
    };

    std::vector<RegisteredSettings> m_registeredSettings;
};
}