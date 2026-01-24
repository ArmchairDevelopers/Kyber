// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <mutex>

namespace Kyber
{
class MemoryArena
{
public:
    char pad_0000[136]; // 0x0000

    void* alloc(size_t size, size_t align);
    void* alloc(size_t size);

    void free(void* mem);
};

#define FB_STATIC_ARENA ((MemoryArena*)0x143CF74E0)
#define FB_GLOBAL_ARENA ((MemoryArena*)0x143CF74C0)
#define FB_CLIENT_ARENA ((MemoryArena*)0x143CF89E0)
#define FB_SERVER_ARENA ((MemoryArena*)0x143CFA7C0)
#define FB_FIXUP_ARENA ((MemoryArena*)0x143D23E80)

void InitializeEASTL();

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