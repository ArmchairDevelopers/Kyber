// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <ToolLib/Func.h>

#include <mutex>
#include <vector>

namespace Kyber
{
class MemoryArena
{
public:
    char pad_0000[136]; // 0x0000

    void* alloc(size_t size, size_t align);
    void* alloc(size_t size);

    void free(void* mem);

    template <typename T>
    void del(T* mem)
    {
        if (mem != nullptr)
        {
            mem->~T();
            this->free(mem);
        }
    }
};

#define FB_STATIC_ARENA (reinterpret_cast<MemoryArena*>(0x143CF74E0))
#define FB_GLOBAL_ARENA (reinterpret_cast<MemoryArena*>(0x143CF74C0))
#define FB_CLIENT_ARENA (reinterpret_cast<MemoryArena*>(0x143CF89E0))
#define FB_SERVER_ARENA (reinterpret_cast<MemoryArena*>(0x143CFA7C0))
#define FB_FIXUP_ARENA (reinterpret_cast<MemoryArena*>(0x143D23E80))

void InitializeEASTL();

TL_DECLARE_FUNC(0x1401C7F90, MemoryArena*, ArenaMap_findArenaForObjectInternal, void* object, bool retGlobalOnFail);
class ArenaMap
{
public:
    inline static MemoryArena* FindArenaForObject(void* object, bool retGlobalOnFail = false)
    {
        return ArenaMap_findArenaForObjectInternal(object, retGlobalOnFail);
    }
};

class MemoryLeakDb
{
public:
    static void AddEntry(size_t amount, const char* description);

    static size_t GetTotalLeaked()
    {
        return s_totalLeaked;
    }

private:
    static size_t s_totalLeaked;
};

template<typename T>
struct MutexGuard
{
    MutexGuard(std::mutex& mutex, T& instance)
        : m_lock(mutex), m_instance(instance)
    {}

    T* operator->() { return &m_instance; }
    T& operator*() { return m_instance; }
    
private:
    std::unique_lock<std::mutex> m_lock;
    T& m_instance;
};

template<typename T>
struct Mutex
{
    Mutex() requires std::default_initializable<T> : m_instance() {}

    Mutex(T instance)
       : m_instance(std::move(instance))
    {}

    MutexGuard<T> Lock()
    {
        return MutexGuard<T>(m_mutex, m_instance);
    }

private:
    std::mutex m_mutex;
    T m_instance;
};
} // namespace Kyber

void* operator new(size_t size, Kyber::MemoryArena* arena);
void* operator new[](size_t size, Kyber::MemoryArena* arena);
void operator delete(void* ptr, Kyber::MemoryArena* arena);
