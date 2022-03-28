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
        "CREATOR & DEVELOPER",
        "BattleDash",
        "",
        "COMMUNITY MANAGER",
        "Dangercat",
        "",
        "CONTRIBUTORS",
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