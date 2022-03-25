// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <string>

namespace Kyber
{
class MemoryUtils
{
  public:
    static void Patch(void* dst, void* src, unsigned int size);
    static void Nop(void* dst, unsigned int size);
};
} // namespace Kyber