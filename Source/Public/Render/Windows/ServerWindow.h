// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Render/Windows/Window.h>
#include <Core/Program.h>

namespace Kyber
{
class ServerWindow : public Window
{
public:
    std::optional<std::vector<KyberProxy>> m_proxies;
    ServerWindow();
    ~ServerWindow();
    void Draw() override;
    bool IsEnabled() override;
};
} // namespace Kyber