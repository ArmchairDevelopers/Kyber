// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Render/Windows/Window.h>

#include <Base/Version.h>

namespace Kyber
{
class CreditsWindow : public Window
{
public:
    // clang-format off
    const char* credits[11] = {
        ("Kyber v" + KYBER_VERSION).c_str(),
        ""
        "Creator and Developer:",
        "BattleDash",
        "",
        "Management:",
        "Dangercat",
        "",
        "Contributors:",
        "Cade",
        "Mophead",
        "Dyvinia"
    };
    // clang-format on

    CreditsWindow();
    ~CreditsWindow();
    void Draw() override;
    bool IsEnabled() override;
};
} // namespace Kyber