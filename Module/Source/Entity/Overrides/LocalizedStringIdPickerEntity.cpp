// Copyright Armchair Developers. Licensed under GPLv3.

#include <Entity/Overrides/LocalizedStringIdPickerEntity.h>

#include <Entity/KyberSettings.h>
#include <Core/Program.h>
#include <SDK/Fb/UIIncubatorShared.h>

namespace Kyber
{
KB_IMPLEMENT_ENTITY_OVERRIDE(LocalizedStringIdPickerEntity, LocalizedStringIdPickerEntityData);

LocalizedStringIdPickerEntity::LocalizedStringIdPickerEntity(EntityManager* entityManager, NativeEntity* entity, LocalizedStringIdPickerEntityData* data)
    : KyberEntity(entity, data)
{
    LocalizedStringId* defaultValue = g_program->m_entityManager->CreateContainer<LocalizedStringId>(typeInfo_LocalizedStringId);
    defaultValue->StringHash = CalcStringHash("ID_DBG_LOREM_IPSUM");
    m_localizedStringId = CreateFieldOverride<LocalizedStringId>("StringId", typeInfo_LocalizedStringId, defaultValue);

    GetLocalized();
}

void LocalizedStringIdPickerEntity::PropertyChanged(PropertyModification* modification)
{
    GetLocalized();
}

// Gets the Sid input to the entity either from a connection or the entity data and creates a LocalizedStringId instance to output to StringId
void LocalizedStringIdPickerEntity::GetLocalized()
{
    if (!m_localizedStringId.HasConnection())
    {
        return;
    }

    auto sidField = GetFieldReader<char*>("Sid");
    std::string id = sidField.HasConnection() && sidField.HasConnectionValue() ? sidField.Get() : GetData()->Sid;
    int32_t stringHash = CalcStringHash(id);

    LocalizedStringId* container = g_program->m_entityManager->CreateContainer<LocalizedStringId>(typeInfo_LocalizedStringId);
    container->StringHash = stringHash;

    m_localizedStringId = container;
}
} // namespace Kyber
