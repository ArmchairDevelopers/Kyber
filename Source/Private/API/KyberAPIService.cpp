// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <API/KyberAPIService.h>

namespace Kyber
{
std::vector<ServerModel> KyberAPIService::GetServerList(int page)
{
    std::vector<ServerModel> serverList;
    serverList.push_back({ "Test Server", "Test Mode", "Test Level", "Test Host" });
    return serverList;
}
} // namespace Kyber