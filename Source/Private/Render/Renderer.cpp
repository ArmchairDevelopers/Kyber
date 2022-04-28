// Copyright BattleDash. All Rights Reserved.

#include <Render/Renderer.h>

#include <Base/Log.h>
#include <Render/Windows/MainWindow.h>
#include <Utilities/ErrorUtils.h>
#include <Hook/HookManager.h>
#include <Render/Fonts/BattlefrontUIRegular.h>

#include <imgui/imgui.h>
#include <imgui/imgui_impl_dx11.h>
#include <imgui/imgui_impl_win32.h>
#include <imgui/imgui_internal.h>
#include <MinHook/MinHook.h>

#include <Windows.h>
#include <winuser.h>
#include <typeinfo>

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

Kyber::Renderer* g_renderer;

namespace Kyber
{
std::list<Window*> Renderer::pUiInstances;

WNDPROC lpPrevWndFunc;
static HWND hWnd = 0;

LRESULT CALLBACK WndProcHk(HWND hWnd, UINT Msg, WPARAM wParam, LPARAM lParam)
{
    static const auto trampoline = HookManager::Call(WndProcHk);
    if (Msg == WM_KEYUP && (wParam == VK_INSERT || (g_mainWindow->IsEnabled() && wParam == VK_ESCAPE)))
    {
        g_mainWindow->SetEnabled(!g_mainWindow->IsEnabled());
        ImGui::GetIO().MouseDrawCursor = g_mainWindow->IsEnabled();
        KYBER_LOG(LogLevel::Info, "InputManMouse: 0x" << std::hex << GetWindowLongPtr(hWnd, 0));
    }

    ImGuiIO& io = ImGui::GetIO();

    if (g_mainWindow->IsEnabled())
    {
        ImGui_ImplWin32_WndProcHandler(hWnd, Msg, wParam, lParam);

        return TRUE;
    }

    return trampoline(hWnd, Msg, wParam, lParam);
}

HRESULT PresentHk(IDXGISwapChain* pInstance, UINT syncInterval, UINT flags)
{
    static const auto trampoline = HookManager::Call(PresentHk);
    static float fWidth = 0;
    static float fHeight = 0;

    // Poll and handle messages (inputs, window resize, etc)
    static MSG msg;
    ZeroMemory(&msg, sizeof(msg));
    if (::PeekMessage(&msg, hWnd, 0U, 0U, PM_REMOVE))
    {
        ::TranslateMessage(&msg);
        ::DispatchMessage(&msg);
    }

    if (!g_renderer)
    {
        return trampoline(pInstance, syncInterval, flags);
    }

    if (!g_renderer->m_currentDevice)
    {
        KYBER_LOG(LogLevel::Debug, "Initializing Current Rendering Device");
        pInstance->GetDevice(__uuidof(g_renderer->m_currentDevice), reinterpret_cast<PVOID*>(&g_renderer->m_currentDevice));
        g_renderer->m_currentDevice->GetImmediateContext(&g_renderer->m_currentContext);

        ID3D11Texture2D* pTarget = nullptr;
        pInstance->GetBuffer(0, __uuidof(pTarget), reinterpret_cast<PVOID*>(&pTarget));

        g_renderer->m_currentDevice->CreateRenderTargetView(pTarget, nullptr, &g_renderer->m_currentView);

        pTarget->Release();

        ID3D11Texture2D* pBuffer = nullptr;
        pInstance->GetBuffer(0, __uuidof(ID3D11Texture2D), reinterpret_cast<PVOID*>(&pBuffer));

        D3D11_TEXTURE2D_DESC desc = {};
        pBuffer->GetDesc(&desc);

        fWidth = static_cast<float>(desc.Width);
        fHeight = static_cast<float>(desc.Height);

        pBuffer->Release();

        ImGuiIO& io = ImGui::GetIO();

        if (io.BackendPlatformUserData == NULL && !ImGui_ImplWin32_Init(hWnd))
        {
            ErrorUtils::ThrowException("ImGui_ImplWIn32_Init Failed.");
        }
        if (io.BackendRendererUserData == NULL && !ImGui_ImplDX11_Init(g_renderer->m_currentDevice, g_renderer->m_currentContext))
        {
            ErrorUtils::ThrowException("ImGui_ImplDX11_Init Failed.");
        }
        if (!ImGui_ImplDX11_CreateDeviceObjects())
        {
            ErrorUtils::ThrowException("ImGui_ImplDX11_CreateDeviceObjects Failed.");
        }
    }

    ImGuiStyle& style = ImGui::GetStyle();

    style.Colors[ImGuiCol_Text] = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);
    style.Colors[ImGuiCol_TextDisabled] = ImVec4(0.60f, 0.60f, 0.60f, 1.00f);

    style.Colors[ImGuiCol_WindowBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.88f);
    style.Colors[ImGuiCol_ChildBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.88f);

    style.Colors[ImGuiCol_PopupBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.88f);

    style.Colors[ImGuiCol_Border] = ImVec4(0.471f, 0.510f, 0.529f, 1.00f);
    style.Colors[ImGuiCol_BorderShadow] = ImVec4(0.00f, 0.00f, 0.00f, 0.00f);

    style.Colors[ImGuiCol_FrameBg] = ImVec4(0.565f, 0.612f, 0.635f, 0.20f);
    style.Colors[ImGuiCol_FrameBgHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_FrameBgActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_TitleBg] = ImVec4(0.01f, 0.01f, 0.05f, 1.00f);
    style.Colors[ImGuiCol_TitleBgActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_TitleBgCollapsed] = ImVec4(0.01f, 0.01f, 0.05f, 0.80f);

    style.Colors[ImGuiCol_MenuBarBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.88f);

    style.Colors[ImGuiCol_ScrollbarBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.00f);
    style.Colors[ImGuiCol_ScrollbarGrab] = ImVec4(0.85f, 0.85f, 0.85f, 1.00f);
    style.Colors[ImGuiCol_ScrollbarGrabHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_ScrollbarGrabActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_CheckMark] = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);

    style.Colors[ImGuiCol_SliderGrab] = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);
    style.Colors[ImGuiCol_SliderGrabActive] = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);

    style.Colors[ImGuiCol_Button] = ImVec4(0.565f, 0.612f, 0.635f, 0.20f);
    style.Colors[ImGuiCol_ButtonHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_ButtonActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_Header] = ImVec4(0.95f, 0.68f, 0.04f, 1.00f);
    style.Colors[ImGuiCol_HeaderHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_HeaderActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_Separator] = ImVec4(0.471f, 0.510f, 0.529f, 1.00f);
    style.Colors[ImGuiCol_SeparatorHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_SeparatorActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_ResizeGrip] = ImVec4(0.471f, 0.510f, 0.529f, 1.00f);
    style.Colors[ImGuiCol_ResizeGripHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_ResizeGripActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_Tab] = ImVec4(0.01f, 0.05f, 0.06f, 0.88f);
    style.Colors[ImGuiCol_TabHovered] = ImVec4(0.95f, 0.68f, 0.04f, 1.00f);
    style.Colors[ImGuiCol_TabActive] = ImVec4(0.95f, 0.68f, 0.04f, 1.00f);
    style.Colors[ImGuiCol_TabUnfocused] = ImVec4(0.28f, 0.28f, 0.57f, 0.82f);
    style.Colors[ImGuiCol_TabUnfocusedActive] = ImVec4(0.35f, 0.35f, 0.65f, 0.84f);

    style.Colors[ImGuiCol_PlotLines] = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);
    style.Colors[ImGuiCol_PlotLinesHovered] = ImVec4(0.90f, 0.70f, 0.00f, 1.00f);
    style.Colors[ImGuiCol_PlotHistogram] = ImVec4(0.90f, 0.70f, 0.00f, 1.00f);
    style.Colors[ImGuiCol_PlotHistogramHovered] = ImVec4(1.00f, 0.60f, 0.00f, 1.00f);

    style.Colors[ImGuiCol_TableHeaderBg] = ImVec4(0.27f, 0.27f, 0.38f, 1.00f);
    style.Colors[ImGuiCol_TableBorderStrong] = ImVec4(0.31f, 0.31f, 0.45f, 1.00f);
    style.Colors[ImGuiCol_TableBorderLight] = ImVec4(0.26f, 0.26f, 0.28f, 1.00f);
    style.Colors[ImGuiCol_TableRowBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.88f);
    style.Colors[ImGuiCol_TableRowBgAlt] = ImVec4(1.00f, 1.00f, 1.00f, 0.07f);

    style.Colors[ImGuiCol_TextSelectedBg] = ImVec4(0.851f, 0.612f, 0.027f, 0.80f);
    style.Colors[ImGuiCol_DragDropTarget] = ImVec4(1.00f, 1.00f, 0.00f, 0.90f);
    style.Colors[ImGuiCol_NavHighlight] = ImVec4(0.60f, 0.03f, 0.54f, 1.00f);

    style.Colors[ImGuiCol_NavWindowingHighlight] = ImVec4(1.00f, 1.00f, 1.00f, 0.70f);
    style.Colors[ImGuiCol_NavWindowingDimBg] = ImVec4(0.80f, 0.80f, 0.80f, 0.20f);

    style.Colors[ImGuiCol_ModalWindowDimBg] = ImVec4(0.20f, 0.20f, 0.20f, 0.35f);

    // Popup & Dropdown
    style.Colors[ImGuiCol_PopupBg] = ImVec4(0.01f, 0.05f, 0.06f, 0.79f);

    // Main
    style.WindowPadding = ImVec2(16.00f, 18.00f);
    style.FramePadding = ImVec2(12.00f, 8.00f);
    style.ItemSpacing = ImVec2(19.00f, 10.00f);
    style.ItemInnerSpacing = ImVec2(19.00f, 0.00f);
    style.TouchExtraPadding = ImVec2(0.00f, 0.00f);
    style.IndentSpacing = 20.00f;
    style.ScrollbarSize = 14.00f;
    style.GrabMinSize = 20.00f;

    // Borders
    style.WindowBorderSize = 1.5f;
    style.ChildBorderSize = 1.50f;
    style.PopupBorderSize = 1.50f;
    style.FrameBorderSize = 0.00f;
    style.TabBorderSize = 0.00f;

    // Rounding
    style.WindowRounding = 8.00f;
    style.ChildRounding = 6.00f;
    style.FrameRounding = 3.50f;
    style.PopupRounding = 6.00f;
    style.ScrollbarRounding = 6.00f;
    style.GrabRounding = 3.50f;
    style.TabRounding = 6.00f;

    // Alignment
    style.WindowTitleAlign = ImVec2(0.00f, 0.51f);
    style.WindowMenuButtonPosition = ImGuiDir_None;
    style.ColorButtonPosition = ImGuiDir_Right;
    style.ButtonTextAlign = ImVec2(0.50f, 0.50f);
    style.SelectableTextAlign = ImVec2(0.00f, 0.00f);

    // Safe Area Padding
    style.DisplaySafeAreaPadding = ImVec2(3.00f, 3.00f);

    ImGui_ImplDX11_NewFrame();
    ImGui_ImplWin32_NewFrame();
    ImGui::NewFrame();

    for (Window* ui : Renderer::pUiInstances)
    {
        if (ui->IsEnabled())
        {
            if (!g_mainWindow->IsEnabled())
                ImGui::SetNextWindowBgAlpha(0.5f);
            ui->Draw();
        }
    }

    ImGui::SetNextWindowBgAlpha(1);

    ImGui::Render();
    g_renderer->m_currentContext->OMSetRenderTargets(1, &g_renderer->m_currentView, NULL);
    ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());

    return trampoline(pInstance, syncInterval, flags);
}

HRESULT ResizeBuffersHk(IDXGISwapChain* pInstance, UINT BufferCount, UINT Width, UINT Height, DXGI_FORMAT NewFormat, UINT SwapChainFlags)
{
    static const auto trampoline = HookManager::Call(ResizeBuffersHk);
    for (Window* ui : Renderer::pUiInstances)
    {
        ui->Resize();
    }

    if (ImGui::GetIO().BackendRendererUserData != NULL)
    {
        ImGui_ImplDX11_Shutdown();

        g_renderer->m_currentView->Release();
        g_renderer->m_currentContext->Release();
        g_renderer->m_currentDevice->Release();

        g_renderer->m_currentDevice = nullptr;
    }

    return trampoline(pInstance, BufferCount, Width, Height, NewFormat, SwapChainFlags);
}

Renderer::Renderer()
{
    if (g_renderer)
    {
        ErrorUtils::ThrowException("Renderer is already initialized.");
    }

    KYBER_LOG(LogLevel::Debug, "Initializing Renderer");

    g_mainWindow = new MainWindow();

    IDXGISwapChain* pSwapChain;
    ID3D11Device* pDevice;
    ID3D11DeviceContext* pContext;

    auto featureLevel = D3D_FEATURE_LEVEL_11_0;

    DXGI_SWAP_CHAIN_DESC desc = {};

    desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = 1;

    KYBER_LOG(LogLevel::Debug, "Attempting to find Battlefront window");

    hWnd = FindWindow("Frostbite", "STAR WARS Battlefront II");

    if (!hWnd)
    {
        ErrorUtils::ThrowException("Failed to find Battlefront window.");
    }

    desc.OutputWindow = hWnd;
    desc.Windowed = true;

    desc.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;

    if (FAILED(D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_HARDWARE, 0, 0, &featureLevel, 1, D3D11_SDK_VERSION, &desc,
            &pSwapChain, &pDevice, nullptr, &pContext)))
    {
        ErrorUtils::ThrowException("Failed to create device and swap chain.");
    }

    auto pTable = *reinterpret_cast<PVOID**>(pSwapChain);

    auto pPresent = pTable[8];
    auto pResizeBuffers = pTable[13];

    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    
    ImFontConfig font_cfg;
    font_cfg.FontDataOwnedByAtlas = false;
    io.Fonts->AddFontFromMemoryTTF(const_cast<uint8_t*>(s_BattlefrontUI_Regular_ttf), sizeof(s_BattlefrontUI_Regular_ttf), 17.f, &font_cfg);

    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    pSwapChain->Release();
    pDevice->Release();
    pContext->Release();

    HookManager::CreateHook(pPresent, PresentHk);
    HookManager::CreateHook(pResizeBuffers, ResizeBuffersHk);
    HookManager::CreateHook(
        reinterpret_cast<void*>((IsWindowUnicode(hWnd) ? GetWindowLongPtrW : GetWindowLongPtrA)(hWnd, GWLP_WNDPROC)), WndProcHk);
    Hook::ApplyQueuedActions();
}

Renderer::~Renderer()
{
    g_renderer = nullptr;
}
} // namespace Kyber