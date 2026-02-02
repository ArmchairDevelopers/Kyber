// Copyright Armchair Developers. Licensed under GPLv3.

#include <Entity/Overrides/LocalizedStringIdPickerEntity.h>

#include <Entity/KyberSettings.h>
#include <Core/Program.h>

namespace Kyber
{
KB_IMPLEMENT_ENTITY_OVERRIDE(LocalizedStringIdPickerEntity, LocalizedStringIdPickerEntityData);

LocalizedStringIdPickerEntity::LocalizedStringIdPickerEntity(EntityManager* entityManager, NativeEntity* entity, LocalizedStringIdPickerEntityData* data)
    : KyberEntity(entity, data)
{
    m_localizedStringId = CreateFieldOverride<LocalizedStringId>("StringId", g_program->m_entityManager->GetNativeType("LocalizedStringId"));
    GetLocalized();
}

void LocalizedStringIdPickerEntity::PropertyChanged(PropertyModification* modification)
{
    GetLocalized();
}

// Gets the Sid input to the entity either from a connection or the entity data and creates a LocalizedStringId instance to output to StringId
void LocalizedStringIdPickerEntity::GetLocalized()
{
    auto sidField = GetFieldReader<char*>("Sid");
    std::string id = sidField.HasConnection() && sidField.HasConnectionValue() ? sidField.Get() : GetData()->Sid;
    int32_t stringHash = CalcStringHash(id);

    LocalizedStringId* container = g_program->m_entityManager->CreateContainer<LocalizedStringId>("LocalizedStringId");
    container->StringHash = stringHash;

    m_localizedStringId = container;
}

// Strings in Frostbite are referenced by a hash of a unique ID for each string, This calculates that hash for a given ID and returns it
int32_t LocalizedStringIdPickerEntity::CalcStringHash(const std::string& string)
{
    int32_t result = 0xFFFFFFFF; 
    for (int i = 0; i < string.length(); i++)
    {
        result = string[i] + 33 * result;
    }
    return result;
}
} // namespace Kyber
