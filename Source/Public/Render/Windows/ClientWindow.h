// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Render/Windows/Window.h>

namespace Kyber
{
class ClientWindow : public Window
{
public:
    ClientWindow();
    ~ClientWindow();
    void Draw() override;
    bool IsEnabled() override;
};
} // namespace Kyber