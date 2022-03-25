// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <string>
#include <vector>
#include <functional>
#include <optional>

namespace Kyber
{
struct Proxy
{
    std::string ip;
    std::string name;
    std::string flag;
};
struct ServerModel
{
    std::string name;
    std::string mode;
    std::string level;
    std::vector<std::string> mods;
    std::string host;
    Proxy proxy;
};

class APIService
{
public:
    virtual void GetServerList(int page, std::function<void(int, std::optional<std::vector<ServerModel>>)> callback) = 0;
};
} // namespace Kyber