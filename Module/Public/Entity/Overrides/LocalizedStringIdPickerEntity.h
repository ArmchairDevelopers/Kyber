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
    PropertyWriter<LocalizedStringId> m_localizedStringId;
    void GetLocalized();
};
} // namespace Kyber
