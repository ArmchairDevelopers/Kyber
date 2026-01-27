// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Core/Memory.h>

#include <Core/Program.h>
#include <Base/Log.h>
#include <Hook/HookManager.h>

#include <EASTL/internal/config.h>

namespace Kyber
{
TL_DECLARE_FUNC(0x14541CD00, void*, MemoryArena_alloc, MemoryArena* arena, size_t size, size_t alignment);
TL_DECLARE_FUNC(0x1401C8100, void, MemoryArena_free, MemoryArena* arena, void* mem);

void* MemoryArena::alloc(size_t size, size_t align)
{
    return MemoryArena_alloc(this, size, align);
}

void* MemoryArena::alloc(size_t size)
{
    return alloc(size, (((size - 0x10) >> 0x3F) & 0xFFFFFFFFFFFFFFF8L) + 0x10);
}

void MemoryArena::free(void* mem)
{
    return MemoryArena_free(this, mem);
}

void InitializeEASTL()
{
    EASTLArenaAllocator::s_allocateFunc = reinterpret_cast<EASTLArenaAllocator::EASTLArenaAllocatorAllocateFunc>(0x1454DF7B0);
    EASTLArenaAllocator::s_allocateAlignFunc = reinterpret_cast<EASTLArenaAllocator::EASTLArenaAllocatorAllocateAlignFunc>(0x1454DF760);
    EASTLArenaAllocator::s_deallocateFunc = reinterpret_cast<EASTLArenaAllocator::EASTLArenaAllocatorDeallocateFunc>(0x1454E2780);
}
} // namespace Kyber
