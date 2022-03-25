// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Base/Platform.h>

#include <cassert>
#include <iostream>
#include <sstream>
#include <stdio.h>
#include <string>

namespace Kyber
{
enum class LogLevel
{
    DebugPlusPlus,
    Debug,
    Info,
    Warning,
    Error,
    Fatal,

    Current = Debug
};

// We need this because we can't use X Macros for LogLevel (#level), or else the output will be "LogLevel::Info",
// instead of just "Info". If you have a better solution, feel free to make a PR or an issue.
// clang-format off
#define KYBER_LOG_LEVEL_TO_STRING(level)                                                                                                   \
    ((level == Kyber::LogLevel::Debug || level == Kyber::LogLevel::DebugPlusPlus) ? "Debug" :                                              \
    (level == Kyber::LogLevel::Info ? "Info" :                                                                                             \
    (level == Kyber::LogLevel::Warning ? "Warning" :                                                                                       \
    (level == Kyber::LogLevel::Error ? "Error" :                                                                                           \
    (level == Kyber::LogLevel::Fatal ? "Fatal" : "Unknown")))))

#define KYBER_LOG_LEVEL_COLOR(level)                                                                                                       \
    ((level == Kyber::LogLevel::Debug || level == Kyber::LogLevel::DebugPlusPlus) ? "\x1B[36m" :                                           \
    (level == Kyber::LogLevel::Info ? "" :                                                                                                 \
    (level == Kyber::LogLevel::Warning ? "\x1B[33m" :                                                                                      \
    (level == Kyber::LogLevel::Error ? "\x1B[31m" :                                                                                        \
    (level == Kyber::LogLevel::Fatal ? "\x1B[31m" : "")))))
// clang-format on

#define SHOULD_LOG(level) (level >= Kyber::LogLevel::Current)

// We could one-line this, but operator<< here returns an ostream, which doesn't have a str() method, and gcc doesn't
// like that.
#define STREAM_MESSAGE(message)                                                                                                            \
    std::stringstream ss;                                                                                                                  \
    ss << message << std::endl;                                                                                                            \
    std::cout << ss.str();

#define KYBER_LOG_INTERNAL_DEBUG(level, message)                                                                                           \
    if (Kyber::BuildChannel::Current == Kyber::BuildChannel::Debug)                                                                        \
    {                                                                                                                                      \
        STREAM_MESSAGE(KYBER_LOG_LEVEL_COLOR(level) << "[Kyber-" << KYBER_BUILD_CHANNEL_NAME << "] [" << KYBER_LOG_LEVEL_TO_STRING(level)  \
                                                    << "] [" << __FILE__ << ":" << __LINE__ << "] " << message << "\x1B[0m");              \
    }                                                                                                                                      \
    else                                                                                                                                   \
    {                                                                                                                                      \
        STREAM_MESSAGE(KYBER_LOG_LEVEL_COLOR(level) << "[Kyber-" << KYBER_BUILD_CHANNEL_NAME << "] [" << KYBER_LOG_LEVEL_TO_STRING(level)  \
                                                    << "] [" << __FUNCTION__ << "] " << message << "\x1B[0m");                             \
    }

#define KYBER_LOG_INTERNAL(level, message)                                                                                                 \
    STREAM_MESSAGE(KYBER_LOG_LEVEL_COLOR(level)                                                                                            \
                   << "[Kyber-" << KYBER_BUILD_CHANNEL_NAME << "] [" << KYBER_LOG_LEVEL_TO_STRING(level) << "] " << message << "\x1B[0m");

#ifndef KYBER_FORCE_DEBUG_LOGS
    #define KYBER_FORCE_DEBUG_LOGS 0
#endif

#define KYBER_LOG(level, message)                                                                                                          \
    if (SHOULD_LOG(level))                                                                                                                 \
    {                                                                                                                                      \
        if (level == Kyber::LogLevel::Debug || KYBER_FORCE_DEBUG_LOGS)                                                                     \
        {                                                                                                                                  \
            KYBER_LOG_INTERNAL_DEBUG(level, message);                                                                                      \
        }                                                                                                                                  \
        else                                                                                                                               \
        {                                                                                                                                  \
            KYBER_LOG_INTERNAL(level, message);                                                                                            \
        }                                                                                                                                  \
    }

// Assertions
#define KYBER_ASSERT_DESC(condition, message)                                                                                              \
    if (!(condition))                                                                                                                      \
    {                                                                                                                                      \
        KYBER_LOG(Kyber::LogLevel::Fatal, message);                                                                                        \
        assert(condition);                                                                                                                 \
    }

#define KYBER_ASSERT(condition) KYBER_ASSERT_DESC(condition, "Assertion failed: " #condition)
} // namespace Kyber