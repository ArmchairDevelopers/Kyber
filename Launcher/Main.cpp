// Copyright BattleDash. All Rights Reserved.

#include <stdint.h>
#include <Render/Fonts/BattlefrontUIRegular.h>

#define _WINSOCKAPI_
#define CPPHTTPLIB_OPENSSL_SUPPORT
#include <Windows.h>

#include <imgui/imgui.h>
#include <imgui/imgui_impl_glfw.h>
#include <imgui/imgui_impl_opengl3.h>
#include <stdio.h>
#if defined(IMGUI_IMPL_OPENGL_ES2)
    #include <GLES2/gl2.h>
#endif
#include <GLFW/glfw3.h>

#include <cpp-httplib/httplib.h>
#include <experimental/thread_pool>

#include <filesystem>
#include <sstream>
#include <tlhelp32.h>

#if defined(_MSC_VER) && (_MSC_VER >= 1900) && !defined(IMGUI_DISABLE_WIN32_FUNCTIONS)
    #pragma comment(lib, "legacy_stdio_definitions")
#endif

static void GlfwErrorCallback(int error, const char* description)
{
    fprintf(stderr, "Glfw Error %d: %s\n", error, description);
}

httplib::SSLClient apiClient("kyber.gg");
std::experimental::thread_pool threadPool(4);
bool dllUpdating = false;

std::filesystem::path kyberDllPath;

void DownloadDLL()
{
    dllUpdating = true;
    std::experimental::post(threadPool, [&]() {
        auto response = apiClient.Get("/api/downloads/distributions/stable/dll");
        if (response && response->status == 200)
        {
            std::ofstream out(kyberDllPath, std::ios::binary);
            out.write(response->body.c_str(), response->body.size());
            out.close();
        }
        else
        {
            std::stringstream ss;
            ss << "Failed to download Kyber.dll: " << std::to_string(response->status);
            MessageBoxA(NULL, ss.str().c_str(), "Kyber Launcher", MB_OK);
        }
        dllUpdating = false;
    });
}

void InjectDLL()
{
    if (!std::filesystem::exists(kyberDllPath))
    {
        DownloadDLL();
        return;
    }

    DWORD pid = 0;
    HANDLE hProc = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32 pe = { 0 };
    pe.dwSize = sizeof(PROCESSENTRY32);
    if (Process32First(hProc, &pe))
    {
        do
        {
            if (strcmp(pe.szExeFile, "starwarsbattlefrontii.exe") == 0)
            {
                pid = pe.th32ProcessID;
                break;
            }
        } while (Process32Next(hProc, &pe));
    }

    // Open the process
    hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (hProc == NULL)
    {
        MessageBoxA(NULL, "Failed to open starwarsbattlefrontii.exe", "Kyber Launcher", MB_OK);
        return;
    }

    // Get the address of LoadLibraryA
    auto loadLibraryA = (LPVOID)GetProcAddress(GetModuleHandleA("kernel32.dll"), "LoadLibraryA");
    if (loadLibraryA == NULL)
    {
        MessageBoxA(NULL, "Failed to get address of LoadLibraryA", "Kyber Launcher", MB_OK);
        return;
    }

    LPVOID remoteDLL = VirtualAllocEx(hProc, NULL, file.string().size(), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    if (remoteDLL == NULL)
    {
        MessageBoxA(NULL, "Failed to allocate memory in starwarsbattlefrontii.exe", "Kyber Launcher", MB_OK);
        return;
    }

    if (!WriteProcessMemory(hProc, remoteDLL, file.string().c_str(), file.string().size(), NULL))
    {
        MessageBoxA(NULL, "Failed to write memory in starwarsbattlefrontii.exe", "Kyber Launcher", MB_OK);
        return;
    }

    LPVOID remoteThread = CreateRemoteThread(hProc, NULL, 0, (LPTHREAD_START_ROUTINE)loadLibraryA, remoteDLL, 0, NULL);
    if (remoteThread == NULL)
    {
        MessageBoxA(NULL, "Failed to create remote thread in starwarsbattlefrontii.exe", "Kyber Launcher", MB_OK);
        return;
    }

    WaitForSingleObject(remoteThread, INFINITE);
    VirtualFreeEx(hProc, remoteDLL, 0, MEM_RELEASE);
    CloseHandle(remoteThread);
}

int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd)
{
    glfwSetErrorCallback(GlfwErrorCallback);
    if (!glfwInit())
    {
        return 1;
    }

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);

    GLFWwindow* window = glfwCreateWindow(500, 400, "Kyber Launcher", NULL, NULL);
    if (window == NULL)
    {
        return 1;
    }

    glfwMakeContextCurrent(window);
    glfwSwapInterval(1); // Enable vsync

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = NULL;

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

    style.Colors[ImGuiCol_Separator] = ImVec4(0.42f, 0.42f, 0.42f, 1.00f);
    style.Colors[ImGuiCol_SeparatorHovered] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);
    style.Colors[ImGuiCol_SeparatorActive] = ImVec4(0.851f, 0.612f, 0.027f, 1.00f);

    style.Colors[ImGuiCol_ResizeGrip] = ImVec4(1.00f, 1.00f, 1.00f, 0.10f);
    style.Colors[ImGuiCol_ResizeGripHovered] = ImVec4(0.78f, 0.82f, 1.00f, 0.60f);
    style.Colors[ImGuiCol_ResizeGripActive] = ImVec4(0.78f, 0.82f, 1.00f, 0.90f);

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
    style.ItemSpacing = ImVec2(19.00f, 14.00f);
    style.ItemInnerSpacing = ImVec2(19.00f, 0.00f);
    style.TouchExtraPadding = ImVec2(0.00f, 0.00f);
    style.IndentSpacing = 20.00f;
    style.ScrollbarSize = 14.00f;
    style.GrabMinSize = 20.00f;

    // Borders
    style.WindowBorderSize = 0.0f;
    style.ChildBorderSize = 1.50f;
    style.PopupBorderSize = 1.50f;
    style.FrameBorderSize = 0.00f;
    style.TabBorderSize = 0.00f;

    // Rounding
    style.WindowRounding = 0.00f;
    style.ChildRounding = 6.00f;
    style.FrameRounding = 3.50f;
    style.PopupRounding = 6.00f;
    style.ScrollbarRounding = 6.00f;
    style.GrabRounding = 3.50f;
    style.TabRounding = 6.00f;

    // Alignment
    style.WindowTitleAlign = ImVec2(0.00f, 0.50f);
    style.WindowMenuButtonPosition = ImGuiDir_None;
    style.ColorButtonPosition = ImGuiDir_Right;
    style.ButtonTextAlign = ImVec2(0.50f, 0.50f);
    style.SelectableTextAlign = ImVec2(0.00f, 0.00f);

    // Safe Area Padding
    style.DisplaySafeAreaPadding = ImVec2(3.00f, 3.00f);

    ImFontConfig font_cfg;
    font_cfg.FontDataOwnedByAtlas = false;
    io.Fonts->AddFontFromMemoryTTF(const_cast<uint8_t*>(s_BattlefrontUI_Regular_ttf), sizeof(s_BattlefrontUI_Regular_ttf), 17.f, &font_cfg);

    ImGui_ImplGlfw_InitForOpenGL(window, true);
    ImGui_ImplOpenGL3_Init("#version 130");

    ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);

    //DownloadDLL();
    kyberDllPath = std::filesystem::temp_directory_path() / "Kyber" / "Kyber.dll";
    std::string kyberDllPathStr = kyberDllPath.u8string();

    while (!glfwWindowShouldClose(window))
    {
        glfwPollEvents();

        ImGui_ImplOpenGL3_NewFrame();
        ImGui_ImplGlfw_NewFrame();
        ImGui::NewFrame();

        if (static_cast<int>(glfwGetTime()) % 5 == 0)
        {
            //DownloadDLL();
        }

        ImGui::SetNextWindowSize(io.DisplaySize);
        ImGui::SetNextWindowPos(ImVec2(0, 0));
       
        ImGui::Begin("Hello, world!", NULL, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_AlwaysAutoResize);
        ImGui::Text("Kyber DLL Path: %s", kyberDllPathStr.c_str());

        ImGui::Text("This is some useful text.");

        if (ImGui::Button("Inject"))
        {
            InjectDLL();
        }

        ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
        ImGui::End();

        ImGui::Render();
        int display_w, display_h;
        glfwGetFramebufferSize(window, &display_w, &display_h);
        glViewport(0, 0, display_w, display_h);
        glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

        glfwSwapBuffers(window);
    }

    ImGui_ImplOpenGL3_Shutdown();
    ImGui_ImplGlfw_Shutdown();
    ImGui::DestroyContext();

    glfwDestroyWindow(window);
    glfwTerminate();

    return 0;
}