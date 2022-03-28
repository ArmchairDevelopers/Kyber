// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <Render/Windows/MainWindow.h>
#include <Render/Windows/Window.h>

#include <d3d11.h>
#include <dxgi1_2.h>

#include <list>
#include <queue>
#include <string>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

namespace Kyber
{
enum class IDXGISwapChainVMT
{
    QueryInterface,
    AddRef,
    Release,
    SetPrivateData,
    SetPrivateDataInterface,
    GetPrivateData,
    GetParent,
    GetDevice,
    Present,
    GetBuffer,
    SetFullscreenState,
    GetFullscreenState,
    GetDesc,
    ResizeBuffers,
    ResizeTarget,
    GetContainingOutput,
    GetFrameStatistics,
    GetLastPresentCount,
};

class Renderer
{
  public:
    static std::list<Window*> pUiInstances;

    IDXGISwapChain1* m_swapChain = nullptr;
    ID3D11Device* m_currentDevice = nullptr;
    ID3D11DeviceContext* m_currentContext = nullptr;
    ID3D11RenderTargetView* m_currentView = nullptr;
    bool m_initialized = false;
    bool m_shouldInitialize = false;

    Renderer();
    ~Renderer();

    void Initialize();

    static void RegisterWindow(Window* ui)
    {
        pUiInstances.push_back(ui);
    }
};
} // namespace Kyber

extern Kyber::Renderer* g_renderer;