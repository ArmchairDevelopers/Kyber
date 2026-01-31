// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Entity/Overrides/LocalizedStringIdPickerEntity.h>

#include <Entity/KyberSettings.h>
#include <Core/Program.h>
#include <cstdint>
#include <ios>

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

void LocalizedStringIdPickerEntity::GetLocalized()
{
    auto sidField = GetFieldReader<char*>("Sid");

    KYBER_LOG(Debug, "GetLocalized Triggered!");

    std::string id = sidField.HasConnection() && sidField.HasConnectionValue() ? sidField.Get() : GetData()->Sid;

    KYBER_LOG(Debug, "Attempting to hash " << id);

    //hash the id
    int32_t result = 0xFFFFFFFF; 
    for (int i = 0; i < id.length(); i++)
    {
        result = id[i] + 33 * result;
    }

    KYBER_LOG(Debug, "Hashed ID " << result);
    
    LocalizedStringId* container = g_program->m_entityManager->CreateContainer<LocalizedStringId>("LocalizedStringId");
    container->StringHash = result;

    KYBER_LOG(Debug, "Created container " << std::hex << container);

    m_localizedStringId = container;

    KYBER_LOG(Debug, "StringId " << m_localizedStringId.Get());
}

} // namespace Kyber
