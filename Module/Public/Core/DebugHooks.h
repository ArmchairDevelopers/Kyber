// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <ToolLib/Func.h>
#include <SDK/SDK.h>
#include <SDK/TypeInfo.h>
#include <SDK/Types.h>

#include <string>

#include <cstdint>

namespace Kyber
{
struct Color32
{
    uint8_t r;
    uint8_t g;
    uint8_t b;
    uint8_t a;

    constexpr Color32(uint8_t r, uint8_t g, uint8_t b, uint8_t a = 255)
        : r(r)
        , g(g)
        , b(b)
        , a(a)
    {}
};

class Colors
{
public:
    inline static constexpr Color32 RED = Color32(0xFF, 0x00, 0x00);
    inline static constexpr Color32 GREEN = Color32(0x00, 0xFF, 0x00);
    inline static constexpr Color32 BLUE = Color32(0x00, 0x00, 0xFF);
    inline static constexpr Color32 PURPLE = Color32(0xFF, 0x00, 0xFF);
    inline static constexpr Color32 YELLOW = Color32(0xFF, 0xFF, 0);
    inline static constexpr Color32 TEAL = Color32(0x00, 0xFF, 0xFF);
    inline static constexpr Color32 WHITE = Color32(0xFF, 0xFF, 0xFF);
    inline static constexpr Color32 BLACK = Color32(0x00, 0x00, 0x00);
};

TL_DECLARE_FUNC(0x1454863E0, void*, DebugRenderer_current);
TL_DECLARE_FUNC(0x1401FA020, void*, DebugRenderer2_current);
TL_DECLARE_FUNC(0x1414DE6D0, void, DebugRenderer_drawTextReal, void* inst, int x, int y, const char* text, Color32 color, float scale,
    int alignment, int rotationRad, Color32 mask);
TL_DECLARE_FUNC(0x145486E10, void, DebugRenderer_drawRect2d, void* inst, Vec2& minPos, Vec2& maxPos, Color32 color);
TL_DECLARE_FUNC(0x147C3D450, unsigned __int64, DebugRenderer_build3DText, __int64 inst, const char* text, __m128* position, float scale,
    float color, __m128* a6, unsigned int alignment);

inline void DebugRenderer_drawText(int x, int y, Color32 color, const std::string& text, float scale = 1.0f, int alignment = 0)
{
    DebugRenderer_drawTextReal(DebugRenderer_current(), x, y, text.c_str(), color, scale, alignment, 0, color);
}

inline Vec3 Multiply(const LinearTransform& lt, const Vec3& vec)
{
    float x = lt.right.x * vec.x + lt.up.x * vec.y + lt.forward.x * vec.z + lt.trans.x;
    float y = lt.right.y * vec.x + lt.up.y * vec.y + lt.forward.y * vec.z + lt.trans.y;
    float z = lt.right.z * vec.x + lt.up.z * vec.y + lt.forward.z * vec.z + lt.trans.z;

    return Vec3(x, y, z);
}

enum UpdateType
{
    UpdateType_Client_PreFrame,
    UpdateType_Client_PostFrame,
    UpdateType_Server_PreFrame,
};

class GenericUpdateListener
{
public:
    virtual ~GenericUpdateListener() = default;

    virtual void GameSimInit() {}
    virtual void Update(UpdateType type, const UpdateParameters& params) {}
};

class GenericUpdateManager
{
public:
    static GenericUpdateManager& Get()
    {
        static GenericUpdateManager instance;
        return instance;
    }

    void Register(UpdateType type, GenericUpdateListener* listener)
    {
        m_listeners[type].push_back(listener);
    }

    void GameSimInit();
    void Call(UpdateType type, const UpdateParameters& params);

private:
    std::unordered_map<UpdateType, std::vector<GenericUpdateListener*>> m_listeners;
};

class GenericUpdateListenerStaticRegistrar
{
public:
    GenericUpdateListenerStaticRegistrar(UpdateType type, GenericUpdateListener* listener)
    {
        GenericUpdateManager& data = GenericUpdateManager::Get();
        data.Register(type, listener);
    }
};

#define KB_REGISTER_GENERIC_UPDATE_LISTENER(name, type) \
    static GenericUpdateListenerStaticRegistrar _##name##_genericUpdateRegistrar(type, &name)

void InitializeDebugHooks();

class RenderListener
{
public:
    virtual ~RenderListener() = default;
    virtual void Render() = 0;
};

void RegisterRenderListener(RenderListener* listener);
void UnregisterRenderListener(RenderListener* listener);
} // namespace Kyber