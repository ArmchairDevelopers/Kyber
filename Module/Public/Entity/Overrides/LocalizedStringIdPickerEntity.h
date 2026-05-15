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

    static int32_t CalcStringHash(const std::string&);

    PropertyWriter<LocalizedStringId> m_localizedStringId;
};
} // namespace Kyber
