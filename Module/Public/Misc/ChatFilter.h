// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#pragma once

#include <Base/Log.h>
#include <SDK/Types.h>
#include <Script/Lua.h>

#include <EASTL/vector.h>
#include <EASTL/string.h>
#include <EASTL/fixed_substring.h>
#include <EASTL/hash_set.h>

namespace Kyber
{
struct ChatFilterResult
{
    ChatFilterResult(eastl::string& inOriginalString) : anythingFiltered(false)
    {
        originalString = inOriginalString;
        filteredString = inOriginalString;
    }

    ChatFilterResult() = default;

    eastl::string originalString;
    eastl::string filteredString;
    eastl::vector<eastl::fixed_substring<char>> flaggedSubStrings;
    bool anythingFiltered;

    friend class ChatFilter;

private:
    void AppendFilteredData(size_t pos, size_t len);
};

class ChatFilter
{
public:
    ChatFilter();

    bool AddBlockedPhrase(const char* str);
    bool AddBlockedRegex(const char* str)
    {
        KB_UNIMPLEMENTED;
    }
    void ClearBlockedPhrases();
    void ClearBlockedRegex()
    {
        KB_UNIMPLEMENTED;
    }
    void Clear();

    void Enable()
    {
        m_enabled = true;
    }
    void Disable()
    {
        m_enabled = false;
    }
    bool IsEnabled() const
    {
        return m_enabled;
    }

    eastl::vector<eastl::string> GetBlockedPhrases() const;

    ChatFilterResult Filter(const char* message) const;

    static void InitializeHooks();
    static char s_filterCharacter;

private:
    void CheckBlockedPhrases(ChatFilterResult& result) const;
    void CheckBlockedRegex(ChatFilterResult& result) const;

    eastl::hash_set<eastl::string> m_blockedPhrases;
    eastl::hash_set<eastl::string> m_blockedRegex;
    bool m_enabled;
};
} // namespace Kyber