// Copyright BattleDash. All Rights Reserved.

#pragma once

namespace Kyber
{

#if defined(_DEBUG)
    #define KYBER_BUILD_CHANNEL_NAME "Debug"
#else
    #define KYBER_BUILD_CHANNEL_NAME "Release"
#endif

enum class BuildChannel
{
    Debug,
    Release,

#if defined(_DEBUG)
    Current = Debug
#else
    Current = Release
#endif
};

#define HOOK_OFFSET(offset) (reinterpret_cast<void*>(offset))

} // namespace Kyber