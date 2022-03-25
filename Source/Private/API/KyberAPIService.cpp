// Copyright BattleDash. All Rights Reserved.

#include <Base/Log.h>
#include <API/KyberAPIService.h>

#include <json/json.hpp>

namespace Kyber
{
KyberAPIService::KyberAPIService()
    : m_client(httplib::SSLClient("kyber.gg"))
    , m_thread_pool(std::experimental::thread_pool(4))
{
    m_client.set_connection_timeout(20);
    m_client.enable_server_certificate_verification(false);
}
void KyberAPIService::GetServerList(int page, std::function<void(int, std::optional<std::vector<ServerModel>>)> callback)
{
    std::experimental::post(m_thread_pool, [this, page, callback = std::move(callback)]() mutable {
        auto response = m_client.Get(("/api/servers?limit=20&page=" + std::to_string(page)).c_str());
        if (response && response->status == 200)
        {
            auto json = nlohmann::json::parse(response->body);
            std::vector<ServerModel> serverModels;
            for (auto& server : json["servers"])
            {
                ServerModel serverModel;
                serverModel.name = server["name"];
                serverModel.mode = server["mode"];
                serverModel.level = server["map"];
                serverModel.mods = server["mods"].get<std::vector<std::string>>();
                serverModel.host = server["host"];
                serverModel.proxy = { server["proxy"]["ip"], server["proxy"]["name"], server["proxy"]["flag"] };
                serverModels.push_back(serverModel);
            }
            callback(page, std::optional<std::vector<ServerModel>>(serverModels));
        }
        else
        {
            KYBER_LOG(LogLevel::Error, "Failed to get server list (" << (response ? std::to_string(response->status) : "no response") << ")");
            callback(page, std::nullopt);
        }
    });
}
} // namespace Kyber
