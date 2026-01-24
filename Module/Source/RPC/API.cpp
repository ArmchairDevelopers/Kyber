#define _WINSOCKAPI_

#include <RPC/API.h>

#include <Utilities/PlatformUtils.h>

#include <errhandlingapi.h>
#include <grpc++/alarm.h>

#include <grpc/grpc.h>
#include <memory>
#include <wincrypt.h>

namespace Kyber
{
std::string Utf8Encode(const std::wstring& wstr)
{
	if (wstr.empty())
		return std::string();

	int sizeNeeded = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
	std::string strTo(sizeNeeded, 0);
	WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], sizeNeeded, NULL, NULL);
	return strTo;
}

grpc::SslCredentialsOptions GetSslOptions()
{
	grpc::SslCredentialsOptions result;

    std::ifstream certFile(PlatformUtils::GetModulePath() / "ca_root.pem");
    if (!certFile.is_open())
    {
        KYBER_LOG(Error, "Failed to open root certificate file");
        return result;
    }

    std::stringstream certBuffer;
    certBuffer << certFile.rdbuf();

    result.pem_root_certs = certBuffer.str();
	return result;
}

void ListenToStateChanges(const std::shared_ptr<grpc::Channel>& channel) {
    auto state = channel->GetState(true);

    while (true) {
        std::chrono::system_clock::time_point deadline = std::chrono::system_clock::now() + std::chrono::seconds(60);
        channel->WaitForStateChange(state, deadline);

		auto newState = channel->GetState(false);
		if (newState == state)
		{
			continue;
		}

		if (newState == GRPC_CHANNEL_TRANSIENT_FAILURE)
		{
			KYBER_LOG(Error, "gRPC entered transient failure state!");
		}
		else if (state == GRPC_CHANNEL_TRANSIENT_FAILURE && newState == GRPC_CHANNEL_CONNECTING)
		{
			KYBER_LOG(Warning, "Attempting gRPC reconnection...");
		}

		state = newState;
    }
}

API::API(std::string token)
{
    auto credentials = grpc::SslCredentials(GetSslOptions());

    std::string rpcUri = PlatformUtils::GetEnv("KYBER_API_HOSTNAME", "api-rpc.prod.kyber.gg");
    std::string httpUri = PlatformUtils::GetEnv("KYBER_HTTP_HOSTNAME", "api.prod.kyber.gg");
    
    std::shared_ptr<Channel> channel = grpc::CreateChannel(rpcUri, credentials);

    m_stateListenerThread = std::thread(ListenToStateChanges, channel);

    m_clientServer = std::make_unique<ClientServerAPI>(channel, &m_asyncManager, token);
    m_proxy = std::make_unique<ProxyAPI>(channel, token);
    m_serverBrowser = std::make_unique<ServerBrowserAPI>(channel, &m_asyncManager, token);
    m_serverManagement = std::make_unique<ServerManagementAPI>(httpUri, token);
    m_statistics = std::make_unique<StatisticsAPI>(channel, &m_asyncManager, token);
    m_voip = std::make_unique<VoipAPI>(channel, &m_asyncManager, token);

    std::string launcherPort = PlatformUtils::GetEnv("KYBER_LAUNCHER_PORT");
    std::shared_ptr<Channel> launcherChannel = grpc::CreateChannel("127.0.0.1:" + launcherPort, grpc::InsecureChannelCredentials());
    m_launcherInterface = std::make_unique<LauncherInterface>(launcherChannel, &m_asyncManager);
}

void API::Update() const
{
    m_asyncManager.Update();
}
} // namespace Kyber
