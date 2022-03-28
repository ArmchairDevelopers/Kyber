// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <API/APIService.h>

#include <string>

namespace Kyber
{
class KyberAPIService : public APIService
{
public:
    virtual std::vector<ServerModel> GetServerList(int page) override;
};
} // namespace Kyber