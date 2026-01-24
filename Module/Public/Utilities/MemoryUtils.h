// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/Memory.h>

namespace Kyber
{
class MemoryUtils
{
public:
    template<typename T>
    static T* Copy(T* src, unsigned int size);
    template<typename T>
    static T* Copy(MemoryArena* arena, T* src, unsigned int size);

    static void Patch(void* dst, void* src, unsigned int size);
    static void Nop(void* dst, unsigned int size);
};

template<typename T>
T* MemoryUtils::Copy(T* src, unsigned int size)
{
    void* dst = FB_GLOBAL_ARENA->alloc(size);
    memcpy(dst, src, size);
    return (T*) dst;
}

template<typename T>
T* MemoryUtils::Copy(MemoryArena* arena, T* src, unsigned int size)
{
    void* dst = arena->alloc(size);
    memcpy(dst, src, size);
    return (T*)dst;
}
} // namespace Kyber