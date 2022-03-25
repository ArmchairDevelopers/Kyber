// Copyright BattleDash. All Rights Reserved.

#include <Render/Windows/Window.h>

#include <Render/Renderer.h>
#include <imgui/imgui.h>

namespace Kyber
{
Window::Window()
{
    Renderer::RegisterWindow(this);
}

void Window::Draw() {}

void Window::PostRender() {}

void Window::Resize() {}

bool Window::IsEnabled()
{
    return false;
}
} // namespace Kyber