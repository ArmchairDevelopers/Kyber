// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <atomic>
#include <condition_variable>
#include <mutex>
#include <string>
#include <thread>

namespace Kyber
{
struct ServerCreationInfo;

class LanBeacon
{
public:
    LanBeacon();
    ~LanBeacon();

    void Start(const ServerCreationInfo& info, int port);
    void Stop();

private:
    std::string BuildPayload(const ServerCreationInfo& info, int port, int playerCount) const;
    void Run(const ServerCreationInfo& info, int port);

    std::atomic_bool m_running;
    std::thread m_thread;
    std::mutex m_mutex;
    std::condition_variable m_condition;
};
} // namespace Kyber
