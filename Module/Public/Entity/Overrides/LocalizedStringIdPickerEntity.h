#pragma once

#include <Entity/NativeEntityManager.h>

#include <Core/DebugHooks.h>

namespace Kyber
{
class LocalizedStringIdPickerEntity : public KyberEntity<LocalizedStringIdPickerEntityData>
{
public:
    LocalizedStringIdPickerEntity(EntityManager* entityManager, NativeEntity* entity, LocalizedStringIdPickerEntityData* data);

    void PropertyChanged(PropertyModification* modification) override;

private:
    void GetLocalized();

    // Strings in Frostbite are referenced by a hash of a unique ID for each string
    // This calculates that hash for a given ID and returns it
    static constexpr int32_t CalcStringHash(const std::string& string)
    {
        int32_t result = 0xFFFFFFFF;
        for (int i = 0; i < string.length(); i++)
        {
            result = string[i] + 33 * result;
        }
        return result;
    }

    PropertyWriter<LocalizedStringId> m_localizedStringId;
};
} // namespace Kyber
