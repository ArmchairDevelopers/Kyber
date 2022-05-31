// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <API/APIService.h>

#include <experimental/thread_pool>

#define _WINSOCKAPI_
#define CPPHTTPLIB_OPENSSL_SUPPORT
#include <cpp-httplib/httplib.h>

namespace Kyber
{
class KyberAPIService : public APIService
{
public:
    KyberAPIService();

    virtual void GetServerList(int page, std::function<void(int, std::optional<std::vector<ServerModel>>)> callback) override;
    virtual void GetProxies(std::function<void(std::optional<std::vector<KyberProxy>>)> callback) override;
    virtual int GetPing(std::string ip);
private:
    httplib::SSLClient m_client;
    mutable std::experimental::thread_pool m_thread_pool;
};
} // namespace Kyber