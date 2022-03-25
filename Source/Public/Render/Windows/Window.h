// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <string>
#include <imgui/imgui.h>

namespace Kyber
{
class Window
{
public:
    Window();
    virtual void Draw();
    virtual void PostRender();
    virtual void Resize();
    virtual bool IsEnabled();
    void SetEnabled(bool enabled)
    {
        m_isEnabled = enabled;
    }

    bool m_isEnabled = false;
};
} // namespace Kyber