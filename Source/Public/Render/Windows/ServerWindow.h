// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Render/Windows/Window.h>
#include <API/APIService.h>

namespace Kyber
{
class ServerWindow : public Window
{
public:
    ServerWindow();
    ~ServerWindow();

    void Draw() override;
    bool IsEnabled() override;

private:
    std::optional<std::vector<KyberProxy>> m_proxies;
};
} // namespace Kyber