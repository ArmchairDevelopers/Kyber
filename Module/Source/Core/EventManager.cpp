// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Core/EventManager.h>
#include <Hook/HookManager.h>
#include <SDK/Funcs.h>

namespace Kyber
{
void EventManager::UnregisterListeners(EventListener* listener)
{
    for (auto& [_, vec] : m_listeners)
    {
        vec.erase(std::remove(vec.begin(), vec.end(), listener), vec.end());
    }
}

void EventManager::ProcessEventQueue()
{
    std::lock_guard<std::mutex> lock(m_mutex);

    while (!m_eventQueue.empty())
    {
        Event* e = const_cast<Event*>(m_eventQueue.front());
        DispatchEvent(*e);

        if (MemoryArena* arena = ArenaMap_findArenaForObjectInternal(e, false))
        {
            arena->free(e);
        }
        else
        {
            delete e;
        }

        m_eventQueue.pop();
    }
}

void EventManager::DispatchEvent(const Event& event)
{
    auto type = std::type_index(typeid(event));
    for (auto& listener : m_listeners[type])
    {
        listener->OnEvent(event);
    }
}
} // namespace Kyber