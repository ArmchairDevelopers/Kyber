// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Script/Lua.h>

#include <functional>
#include <map>
#include <string>

namespace Kyber
{
typedef std::function<int(lua_State*)> LuaCallbackParamSetupFunc;
typedef std::function<void(lua_State*)> LuaCallbackParamCleanupFunc;

typedef std::function<void(LuaCallbackParamSetupFunc, LuaCallbackParamCleanupFunc)> LuaEventCallback;

class LuaEventManager
{
public:
    LuaEventManager();

    void Listen(const std::string& eventName, LuaEventCallback callback);

    template<typename... Args>
    void Fire(const std::string& eventName, Args... args)
    {
        KB_LUA_LOCK;
        m_eventCancelled = false;
        for (const auto& callback : m_listeners[eventName])
        {
            callback(
                [args...](lua_State* L) {
                    (LuaUtils::Push(L, args), ...);
                    return static_cast<int>(sizeof...(args));
                },
                [args...](lua_State* L) {});
        }
    }

    void SetEventCancelled(const bool isCancelled)
    {
        m_eventCancelled = isCancelled;
    }

    bool IsEventCancelled()
    {
        return m_eventCancelled;
    }

    void Reset();

    static void Register(lua_State* L);

private:
    std::map<std::string, std::vector<LuaEventCallback>> m_listeners;
    bool m_eventCancelled;
};
} // namespace Kyber
