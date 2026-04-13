// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#include <Core/Program.h>
#include <Misc/ChatFilter.h>
#include <Script/Lua.h>

namespace Kyber
{
static int ChatFilterClearFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();
    chatFilter->Clear();
    return 0;
}

static int ChatFilterClearBlockedPhrasesFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();
    chatFilter->ClearBlockedPhrases();
    return 0;
}

static int ChatFilterClearBlockedRegexFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();
    chatFilter->ClearBlockedRegex();
    return 0;
}

static int ChatFilterEnableFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();
    chatFilter->Enable();
    return 0;
}

static int ChatFilterDisableFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();
    chatFilter->Disable();
    return 0;
}

static int ChatFilterIsEnabledFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();
    lua_pushboolean(L, chatFilter->IsEnabled());
    return 1;
}

static int ChatFilterAddBlockedPhraseFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();

    const char* phrase = luaL_checkstring(L, 1);
    if (phrase == nullptr || phrase[0] == '\0')
    {
        lua_pushboolean(L, false);
        return 1;
    }

    lua_pushboolean(L, chatFilter->AddBlockedPhrase(phrase));
    return 1;
}

static int ChatFilterAddBlockedRegexFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();

    const char* regex = luaL_checkstring(L, 1);
    if (regex == nullptr || regex[0] == '\0')
    {
        lua_pushboolean(L, false);
        return 1;
    }

    lua_pushboolean(L, chatFilter->AddBlockedRegex(regex));
    return 1;
}

static int ChatFilterSetFilterCharacterFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();

    const char* character = luaL_checkstring(L, 1);
    if (character == nullptr || character[0] == '\0')
    {
        return 0;
    }

    chatFilter->s_filterCharacter = character[0];
    return 0;
}

static int ChatFilterGetFilterCharacterFunc(lua_State* L)
{
    MutexGuard<ChatFilter> chatFilter = g_program->m_server->m_chatFilter.Lock();

    const char charStr[] = { chatFilter->s_filterCharacter, '\0' };
    lua_pushstring(L, charStr);
    return 0;
}

// clang-format off
static const luaL_Reg s_chatFilterFuncs[] = { 
    { "Clear", ChatFilterClearFunc }, 
    { "ClearBlockedPhrases", ChatFilterClearBlockedPhrasesFunc },
    { "ClearBlockedRegex", ChatFilterClearBlockedRegexFunc }, 
    { "Enable", ChatFilterEnableFunc }, 
    { "Disable", ChatFilterDisableFunc }, 
    { "IsEnabled", ChatFilterIsEnabledFunc },
    { "AddBlockedPhrase", ChatFilterAddBlockedPhraseFunc }, 
    { "AddBlockedRegex", ChatFilterAddBlockedRegexFunc },
    { "SetFilterCharacter", ChatFilterSetFilterCharacterFunc }, 
    { "GetFilterCharacter", ChatFilterGetFilterCharacterFunc }, 
    { NULL, NULL } 
};
// clang-format on

static void RegisterChatFilter(lua_State* L)
{
    KB_LUA_NEW_GLOBAL_LIB(L, "ChatFilter", s_chatFilterFuncs);
}

KB_REGISTER_LUA_CONTENT(RegisterChatFilter);
} // namespace Kyber
