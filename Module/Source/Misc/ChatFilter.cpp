// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#include <Misc/ChatFilter.h>

#include <Base/Log.h>
#include <SDK/SDK.h>
#include <Hook/HookManager.h>
#include <Core/Program.h>
#include <Entity/KyberSettings.h>

namespace Kyber
{
char ChatFilter::s_filterCharacter = '#'; // We could do '*' but that bolds text in the chat and looks weird

ChatFilter::ChatFilter()
    : m_enabled(true)
{}

void ChatFilter::CheckBlockedPhrases(ChatFilterResult& result) const
{
    for (const eastl::string& blockedPhrase : m_blockedPhrases)
    {
        size_t phrasePos = 0;
        while ((phrasePos = result.originalString.find(blockedPhrase, phrasePos)) != eastl::string::npos)
        {
            result.AppendFilteredData(phrasePos, blockedPhrase.size());
            phrasePos += blockedPhrase.size();
            result.anythingFiltered |= true;
        }
    }
}

void ChatFilterResult::AppendFilteredData(size_t pos, size_t len)
{
    // Replace flagged range with filter character in filteredString
    memset(const_cast<char*>(filteredString.data()) + pos, ChatFilter::s_filterCharacter, len * sizeof(char));

    // Append what string was filtered to flaggedSubStrings. The strings in this list are readonly and take from originalString
    flaggedSubStrings.push_back(eastl::fixed_substring<char>(originalString, pos, len));
}

ChatFilterResult ChatFilter::Filter(const char* message) const
{
    eastl::string messageStr(message);

    // Due to a bug in EASTL, we cannot use eastl::string::make_lower(). So we have to manually transform it :P
    StringUtils::MakeLower(messageStr.begin(), messageStr.end());

    ChatFilterResult result((messageStr));

    CheckBlockedPhrases(result);

    return result;
}

// Accessors

bool ChatFilter::AddBlockedPhrase(const char* inStr)
{
    eastl::string str(inStr);
    str.trim();
    // See comment in ChatFilter::Filter
    StringUtils::MakeLower(str.begin(), str.end());

    return m_blockedPhrases.insert(str).second;
}

void ChatFilter::ClearBlockedPhrases()
{
    m_blockedPhrases.clear();
}

void ChatFilter::Clear()
{
    ClearBlockedPhrases();
}

eastl::vector<eastl::string> ChatFilter::GetBlockedPhrases() const
{
    eastl::vector<eastl::string> phrases;
    phrases.reserve(m_blockedPhrases.size());

    for (const eastl::string& phrase : m_blockedPhrases)
    {
        phrases.push_back(phrase);
    }

    return phrases;
}

eastl::string ConcatFlaggedSubStrings(eastl::vector<eastl::fixed_substring<char>>& vector)
{
    eastl::string out;

    if (vector.size() == 0)
    {
        return out;
    }

    for (int i = 0; i < vector.size() - 1; i++)
    {
        out += '"' + vector[i] + "\", ";
    }

    out += '"' + vector.end()[-1] + '"';

    return out;
}

void ChatSystemProcessAndSendChatMessageHk(
    void* inst, ChatChannel channel, const char* message, const char* filteredMessage, ServerPlayer* sender)
{
    static const auto trampoline = HookManager::Call(ChatSystemProcessAndSendChatMessageHk);

    // Bug fix: for whatever reason, Group & Team channels are swapped in release
    if (channel == ChatChannel_Group)
    {
        channel = ChatChannel_Team;
    }
    else if (channel == ChatChannel_Team)
    {
        channel = ChatChannel_Group;
    }

    ChatFilterResult result;
    {
        MutexGuard<ChatFilter> cfLock = g_program->m_server->m_chatFilter.Lock();
        ChatFilter* chatFilter = &*cfLock;
        if (chatFilter == nullptr || !chatFilter->IsEnabled() || channel == ChatChannel_Admin)
        {
            return trampoline(inst, channel, message, filteredMessage, sender);
        }

        // Basically the only work we need to actually do here
        // is trampoline with an actually filtered message.
        // The function when ran by the game passes the same string
        // into both `message` and `filteredMessage` and we will do the filtration
        // work and trampoline that. The per player isFilterEnabled is handled
        // by the game in this hooked function.

        result = chatFilter->Filter(message);
    }

    if (result.anythingFiltered)
    {
        KyberSettings* kyberSettings = Settings<KyberSettings>("Kyber");
        if (kyberSettings != nullptr && kyberSettings->LogFilteredChatMessages)
        {
            KYBER_LOG(Info, "Filtered message from player " << sender->m_name << " (" << sender->m_onlineId.m_nativeData << ")!");
            KYBER_LOG(Info, "   Before: \"" << message << "\"");
            KYBER_LOG(Info, "   After : \"" << result.filteredString.c_str() << "\"");
            KYBER_LOG(Info, "   Filtered phrases: " << ConcatFlaggedSubStrings(result.flaggedSubStrings).c_str());
        }

        g_program->m_server->SendConsoleMessage(StringUtils::Format("Filtered message from %s (%llu): \"%s\" -> \"%s\"", sender->m_name,
            sender->m_onlineId.m_nativeData, message, result.filteredString.c_str()));

        filteredMessage = result.filteredString.data();

        if (g_program->m_scriptManager != nullptr)
        {
            g_program->m_scriptManager->GetEventManager().Fire("ChatFilter:Filter", sender, message, filteredMessage);
        }
    }

    trampoline(inst, channel, message, filteredMessage, sender);
}

void ChatSystemProcessIncomingMessageHk(ChatChannel channel, const char* message, OnlineId& senderOnlineId, LocalPlayerId localPlayerId)
{
    static const auto trampoline = HookManager::Call(ChatSystemProcessIncomingMessageHk);

    // Reverse channel switch done in ChatSystemProcessAndSendChatMessageHk so it displays properly
    if (channel == ChatChannel_Group)
    {
        channel = ChatChannel_Team;
    }
    else if (channel == ChatChannel_Team)
    {
        channel = ChatChannel_Group;
    }

    return trampoline(channel, message, senderOnlineId, localPlayerId);
}

void ChatFilter::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x1484AB3E0), ChatSystemProcessAndSendChatMessageHk);
    HookManager::CreateHook(HOOK_OFFSET(0x1484A9250), ChatSystemProcessIncomingMessageHk);
}
} // namespace Kyber