// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Base/Platform.h>

#include <cassert>
#include <iostream>
#include <sstream>
#include <cstdio>
#include <string>
#include <fstream>
#include <regex>
#include <mutex>

#include <spdlog/spdlog.h>

namespace Kyber
{
enum class LogLevel
{
    Trace,
    Debug,
    Info,
    Warning,
    Error,
    Fatal,

    Current = Trace
};

// We need this because we can't use X Macros for LogLevel (#level), or else the output will be "LogLevel::Info",
// instead of just "Info". If you have a better solution, feel free to make a PR or an issue.
// clang-format off
#define KYBER_LOG_LEVEL_TO_STRING(level)                                                                                                   \
    ((level == Kyber::LogLevel::Debug || level == Kyber::LogLevel::Trace) ? "Debug" :                                              \
    (level == Kyber::LogLevel::Info ? "Info" :                                                                                             \
    (level == Kyber::LogLevel::Warning ? "Warning" :                                                                                       \
    (level == Kyber::LogLevel::Error ? "Error" :                                                                                           \
    (level == Kyber::LogLevel::Fatal ? "Fatal" : "Unknown")))))

#define KYBER_LOG_LEVEL_COLOR(level)                                                                                                       \
    ((level == Kyber::LogLevel::Debug || level == Kyber::LogLevel::Trace) ? "\x1B[36m" :                                           \
    (level == Kyber::LogLevel::Info ? "" :                                                                                                 \
    (level == Kyber::LogLevel::Warning ? "\x1B[33m" :                                                                                      \
    (level == Kyber::LogLevel::Error ? "\x1B[31m" :                                                                                        \
    (level == Kyber::LogLevel::Fatal ? "\x1B[31m" : "")))))
// clang-format on

#define SHOULD_LOG(level) (level >= Kyber::LogLevel::Current)

namespace Log
{
static std::ofstream s_logFileStream;
static std::regex s_colorRegex("/[\\u001b\\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g");
static std::mutex s_logMutex;
} // namespace Log

#define STRIP_COLORS(message) (std::regex_replace(message, Kyber::Log::s_colorRegex, ""))

// We could one-line this, but operator<< here returns an ostream, which doesn't have a str() method, and gcc doesn't
// like that.
#define STREAM_MESSAGE(message)                                                                                                            \
    std::unique_lock<std::mutex> locked(Kyber::Log::s_logMutex);                                                                           \
    std::stringstream ss;                                                                                                                  \
    ss << message << std::endl;                                                                                                            \
    std::cout << ss.str();                                                                                                                 \
    Kyber::Log::s_logFileStream << STRIP_COLORS(ss.str()) << std::flush;

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

#define FORCE_SC(code)                                                                                                                     \
    do                                                                                                                                     \
    {                                                                                                                                      \
        code                                                                                                                               \
    } while (false)

__forceinline void logInternal(LogLevel level, const char* label, const char* fmt)
{
    switch (level)
    {
    case Kyber::LogLevel::Info:
        spdlog::info(fmt);
        break;
    case Kyber::LogLevel::Warning:
        spdlog::warn(fmt);
        break;
    case Kyber::LogLevel::Debug:
        spdlog::debug(fmt);
        break;
    case Kyber::LogLevel::Trace:
        spdlog::trace(fmt);
        break;
    case Kyber::LogLevel::Error:
        spdlog::error(fmt);
        break;
    case Kyber::LogLevel::Fatal:
        spdlog::critical(fmt);
        break;
    }
}

#define KYBER_IS_DEBUG(level) (Kyber::LogLevel::level <= Kyber::LogLevel::Debug)
#define KYBER_LOG_STRINGIFY_DETAIL(s) #s
#define KYBER_LOG_STRINGIFY(s) KYBER_LOG_STRINGIFY_DETAIL(s)

#define KYBER_LOG(level, message, ...)                                                                                                     \
    FORCE_SC(if (SHOULD_LOG(Kyber::LogLevel::level)) {                                                                                     \
        std::stringstream _ss;                                                                                                             \
        if constexpr                                                                                                                       \
            KYBER_IS_DEBUG(level)                                                                                                          \
            {                                                                                                                              \
                _ss << "[" __FILE__ ":" KYBER_LOG_STRINGIFY(__LINE__) "] ";                                                                \
            }                                                                                                                              \
        _ss << message;                                                                                                                    \
        logInternal(Kyber::LogLevel::level, "Kyber", _ss.str().c_str());                                                                   \
    })

// Assertions
#define KYBER_ASSERT_DESC(condition, message)                                                                                              \
    FORCE_SC(if (!(condition)) {                                                                                                           \
        KYBER_LOG(Fatal, message);                                                                                                         \
        assert(condition);                                                                                                                 \
    })

#define KYBER_ASSERT(condition) KYBER_ASSERT_DESC(condition, "Assertion failed: " #condition)
} // namespace Kyber
