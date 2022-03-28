// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <string>
#include <vector>

namespace Kyber
{
struct ServerModel
{
    std::string name;
    std::string mode;
    std::string level;
    std::string host;
};

class APIService
{
public:
    virtual std::vector<ServerModel> GetServerList(int page) = 0;
};
} // namespace Kyber