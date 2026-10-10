// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Entity/Overrides/PropertyDebugEntity.h>

#include <Entity/KyberSettings.h>
#include <Core/Program.h>
#include <cstdlib>

namespace Kyber
{
KB_IMPLEMENT_ENTITY_OVERRIDE(PropertyDebugEntity, PropertyDebugEntityData);

PropertyDebugEntity::PropertyDebugEntity(EntityManager* entityManager, NativeEntity* entity, PropertyDebugEntityData* data)
    : KyberEntity(entity, data)
    , m_visible(data->DefaultVisible)
{
    SetWantUpdates(std::getenv("KYBER_PROPERTY_DEBUG") != nullptr);
}

void PropertyDebugEntity::Event(EntityEvent* event)
{
    KYBER_LOG(Trace, "Property got event " << event->eventId);
    if (event->Is("Show"))
    {
        m_visible = true;
    }
    else if (event->Is("Hide"))
    {
        m_visible = false;
    }
}

void PropertyDebugEntity::Update(const UpdateParameters& params)
{
    KyberSettings* settings = Settings<KyberSettings>("Kyber");
    if (settings == nullptr || !settings->RenderPropertyDebug || !m_visible)
    {
        return;
    }

    const char* valuePrefix = GetData()->ValuePrefix;

    std::string str;

    PropertyReader<LinearTransform> transformValue = GetFieldReader<LinearTransform>("TransformValue");
    PropertyReader<Vec2> vec2Value = GetFieldReader<Vec2>("Vec2Value");
    PropertyReader<Vec3> vec3Value = GetFieldReader<Vec3>("Vec3Value");
    PropertyReader<Vec4> vec4Value = GetFieldReader<Vec4>("Vec4Value");
    PropertyReader<float> floatValue = GetFieldReader<float>("FloatValue");
    PropertyReader<int32_t> intValue = GetFieldReader<int32_t>("IntValue");
    PropertyReader<uint32_t> uintValue = GetFieldReader<uint32_t>("UintValue");
    PropertyReader<bool> boolValue = GetFieldReader<bool>("BoolValue");
    PropertyReader<char*> stringValue = GetFieldReader<char*>("StringValue");

    bool hasValue = false;
    std::string typeStr = "";

    if (transformValue.HasConnection())
    {
        hasValue = transformValue.HasConnectionValue();
        typeStr = "Transform";

        if (hasValue)
        {
            str = "Transform";
            // TODO
        }
    }
    else if (vec2Value.HasConnection())
    {
        hasValue = vec2Value.HasConnectionValue();
        typeStr = "Vec2";

        if (hasValue)
        {
            Vec2 v = vec2Value.Get();
            if (GetData()->Multiline)
            {
                str = StringUtils::Format("%s\n %.3f\n %.3f", valuePrefix, v.x, v.y);
            }
            else
            {
                str = StringUtils::Format("%s%.3f, %.3f", valuePrefix, v.x, v.y);
            }
        }
    }
    else if (vec3Value.HasConnection())
    {
        hasValue = vec3Value.HasConnectionValue();
        typeStr = "Vec3";

        if (hasValue)
        {
            Vec3 v = vec3Value.Get();
            if (GetData()->Multiline)
            {
                str = StringUtils::Format("%s\n %.3f\n %.3f\n %.3f", valuePrefix, v.x, v.y, v.z);
            }
            else
            {
                str = StringUtils::Format("%s%.3f, %.3f, %.3f", valuePrefix, v.x, v.y, v.z);
            }
        }
    }
    else if (vec4Value.HasConnection())
    {
        hasValue = vec4Value.HasConnectionValue();
        typeStr = "Vec4";

        if (hasValue)
        {
            Vec4 v = vec4Value.Get();
            if (GetData()->Multiline)
            {
                str = StringUtils::Format("%s\n %.3f\n %.3f\n %.3f\n %.3f\n", valuePrefix, v.x, v.y, v.z, v.w);
            }
            else
            {
                str = StringUtils::Format("%s%.3f, %.3f, %.3f %.3f", valuePrefix, v.x, v.y, v.z, v.w);
            }
        }
    }
    else if (floatValue.HasConnection())
    {
        hasValue = floatValue.HasConnectionValue();
        typeStr = "Float";

        if (hasValue)
        {
            str = StringUtils::Format("%s%.3f", valuePrefix, floatValue.Get());
        }
    }
    else if (intValue.HasConnection())
    {
        hasValue = intValue.HasConnectionValue();
        typeStr = "Int";

        if (hasValue)
        {
            str = StringUtils::Format("%s%i", valuePrefix, intValue.Get());
        }
    }
    else if (uintValue.HasConnection())
    {
        hasValue = uintValue.HasConnectionValue();
        typeStr = "Uint";

        if (hasValue)
        {
            str = StringUtils::Format("%s%u", valuePrefix, uintValue.Get());
        }
    }
    else if (boolValue.HasConnection())
    {
        hasValue = boolValue.HasConnectionValue();
        typeStr = "Bool";

        if (hasValue)
        {
            str = StringUtils::Format("%s%s", valuePrefix, boolValue.Get() ? "true" : "false");
        }
    }
    else if (stringValue.HasConnection())
    {
        hasValue = stringValue.HasConnectionValue();
        typeStr = "String";

        if (hasValue)
        {
            str = StringUtils::Format("%s%s", valuePrefix, stringValue.Get());
        }
    }
    else
    {
        hasValue = true;
        str = StringUtils::Format("%sNo connection", valuePrefix);
    }

    if (!hasValue)
    {
        str.clear();
        str = StringUtils::Format("%sNo value on %s", valuePrefix, typeStr);
    }

    m_str = str;

    if (m_str.empty())
    {
        return;
    }

    Vec2 pos = GetData()->ScreenPosition;
    Vec3 color = GetData()->TextColor;
    DebugRenderer_drawText(pos.x, pos.y, Color32(color.x * 255, color.y * 255, color.z * 255, 200), m_str, GetData()->TextScale);
}
} // namespace Kyber
