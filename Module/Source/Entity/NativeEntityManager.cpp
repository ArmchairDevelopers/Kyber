// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#define _WINSOCKAPI_
#include <Entity/NativeEntityManager.h>

#include <Base/Pch.h>
#include <Hook/HookManager.h>
#include <Base/Log.h>
#include <Utilities/StringUtils.h>
#include <SDK/TypeInfo.h>
#include <SDK/Funcs.h>
#include <Core/Program.h>
#include <Utilities/MemoryUtils.h>
#include <Utilities/PlatformUtils.h>
#include <Core/Memory.h>
#include <Script/LuaDataContainer.h>

#include <EASTL/fixed_map.h>

#include <iostream>

#define EASTL_USER_DEFINED_ALLOCATOR

using namespace fastdelegate;

namespace Kyber
{
class EntityCreationInfo
{
public:
    void* vfptr;
    void* unknown;
    char _buf[0x30];
    LinearTransform transform;
    char _buf2[0x70];
    void* data;
    char _buf3[0x120];
};

TL_DECLARE_FUNC(0x1469FB4E0, EntityCreationInfo*, EntityCreationInfo_ctorClient, EntityCreationInfo* inst, GameObjectData* data,
    EntityBus* bus, const LinearTransform& transform);
TL_DECLARE_FUNC(0x14692B350, EntityCreationInfo*, EntityCreationInfo_ctorServer, EntityCreationInfo* inst, GameObjectData* data,
    EntityBus* bus, const LinearTransform& transform);

TL_DECLARE_FUNC(0x145425C10, __int64, TypeBuilderCtorHk, __int64 a1, void* a2, void* a3, int a4, char a5);
TL_DECLARE_FUNC(0x1401CD020, TypeInfo*, TypeBuilderBuildHk, void* inst, const ClassInfoAsset* asset);
TL_DECLARE_FUNC(0x14543CE20, TypeInfo*, TypeBuilderInternalBuildClassStubHk, __int64* a1, __int64 context, const ClassInfoAsset& asset);
TL_DECLARE_FUNC(0x14543AD40, void*, PropertyReaderBaseGetHk, const PropertyReaderBase* inst);
TL_DECLARE_FUNC(0x14114C290, void, FullEntityBusInternalFireEventHk, void* inst, const DataContainer* data, const EntityEvent* entityEvent);
TL_DECLARE_FUNC(0x1467C9550, NativeEntity*, EntityCreator_createConsoleCommandEntity, void* entityCreator, void* createInfo);

TL_DECLARE_FUNC(
    0x1474DA700, NativeEntity*, EntityFactory_internalCreateEntity, const EntityCreationInfo& info, const DataContext& dataContext);

KyberTypeInfo::KyberTypeInfo(const char* name, const char* parent)
{
    m_name = name;

    m_hasParent = parent != nullptr;
    if (m_hasParent)
    {
        // EntityData doesn't have a default instance, but dummyData does
        if (strcmp(parent, "EntityData") == 0)
        {
            parent = "dummyData";
        }

        m_parentName = parent;
    }
}

void KyberTypeInfo::AddField(const char* typeName, const char* name, bool isArray)
{
    m_fields.push_back({ typeName, name, isArray });
}

KyberEntityBase::KyberEntityBase(NativeEntity* entity, DataContainer* data)
    : m_nativeEntity(entity)
    , m_data(data)
    , m_isSpatialEntity(false)
    , m_isInitialized(true)
    , m_wantUpdates(false)
{}

KyberEntityBase::~KyberEntityBase()
{
    if (m_origDtorFn == nullptr)
    {
        return;
    }

    m_origDtorFn(m_nativeEntity);
}

void* ArrayTypeInfoCtorHk(void* inst, ArrayTypeInfoData* typeInfoData, bool registerType)
{
    static auto trampoline = HookManager::Call(ArrayTypeInfoCtorHk);
    return trampoline(inst, typeInfoData, true);
}

TypeInfo* TypeBuilderInternalBuildHk(__int64* a1, __int64 context, const ClassInfoAsset& asset)
{
    static auto trampoline = HookManager::Call(TypeBuilderInternalBuildHk);

    if (g_program->m_entityManager->IsGuidUsed(*asset.GetInstanceGuid()))
    {
        KYBER_LOG(Trace, "Building class stub for " << asset.TypeName);
        TypeInfo* type = TypeBuilderInternalBuildClassStubHk(a1, context, asset);
        g_program->m_entityManager->AddBuiltType(*asset.GetInstanceGuid(), type);
        return type;
    }

    return trampoline(a1, context, asset);
}

TypeInfoFieldData* CreateFieldData(const char* name, TypeInfoAsset* typeAsset, TypeInfo* type, bool isArray)
{
    TypeInfoFieldData* data = new TypeInfoFieldData();
    if (data == nullptr)
    {
        KYBER_LOG(Error, "Failed to create field data!");
        return nullptr;
    }

    data->TypeRef.Asset = typeAsset;
    data->TypeRef.TypeInfo.m_typeInfo = type;

    data->Name = name;
    data->ProtectionLevel = ProtectionLevel_Private;
    data->MemorySortIndex = 0;
    data->AccessType = AccessType_Member;
    data->IsArray = isArray;
    data->IsMeta = false;
    data->IsExposed = false;
    data->AlwaysPersist = false;

    return data;
}

void* CreateTypeBuilder()
{
    __int64* typeBuilder = (__int64*)FB_STATIC_ARENA->alloc(24 * sizeof(__int64));
    TypeBuilderCtorHk((__int64)typeBuilder, FB_STATIC_ARENA, (void*)0x143AF5160, 0, 1);
    return typeBuilder;
}

TypeInfo* RegisterType(void* typeBuilder, ClassInfoAsset* asset)
{
    TypeInfo* type = g_program->m_entityManager->GetBuiltType(*asset->GetInstanceGuid());
    if (type != nullptr)
    {
        return type;
    }

    TypeInfo* result = TypeBuilderBuildHk(typeBuilder, asset);
    KYBER_LOG(Trace, "Built type: " << result);
    return result;
}

const TypeInfo* TypeBuilderInternalFindTypeHk(void* a1, const Guid& guid)
{
    const TypeInfo* type = g_program->m_entityManager->GetNativeTypeByGuid(guid);
    if (type != nullptr)
    {
        return type;
    }

    type = g_program->m_entityManager->GetCreatedType(guid);
    if (type != nullptr)
    {
        return type;
    }

    if (g_program->m_entityManager->CreatedTypeExists(guid))
    {
        ClassInfoAsset* asset = g_program->m_entityManager->GetClassInfoAsset(guid);
        KYBER_LOG(Trace, "Prematurely creating " << asset->TypeName);
        return RegisterType(g_program->m_entityManager->GetTypeBuilder(), asset);
    }

    static auto trampoline = HookManager::Call(TypeBuilderInternalFindTypeHk);
    return trampoline(a1, guid);
}

void EntityManager::RegisterNativeTypeInfo()
{
    TypeInfo* firstTypeInfo = (TypeInfo*)0x144742650;
    for (TypeInfo* info = firstTypeInfo; info; info = info->next)
    {
        m_nativeTypeInfo[info->getName()] = info;
    }
}

void EntityManager::RegisterTypes()
{
    RegisterNativeTypeInfo();

    for (const auto& info : EntityManagerStaticData::Get().GetTypeInfo())
    {
        ClassInfoAsset* asset = CreateClassInfoAsset(info);
        m_classInfoAssets.push_back(asset);
    }

    // Post-Process non-native parent types
    for (const auto& pending : m_classesPendingParentAssignment)
    {
        for (const auto& candidateAsset : m_classInfoAssets)
        {
            if (strcmp(candidateAsset->TypeName, pending.ref) != 0)
            {
                continue;
            }

            pending.data->SuperClassRef.Asset = candidateAsset;
            KYBER_LOG(Trace, "Assigned super ref for " << pending.data->TypeName);
        }
    }

    // Post-Process non-native field types
    for (const auto& pending : m_fieldsPendingTypeAssignment)
    {
        for (const auto& candidateAsset : m_classInfoAssets)
        {
            if (strcmp(candidateAsset->TypeName, pending.ref) != 0)
            {
                continue;
            }

            pending.data->TypeRef.Asset = candidateAsset;
            KYBER_LOG(Trace, "Assigned field ref for " << pending.data->Name);
        }
    }

    m_typeBuilder = CreateTypeBuilder();
    for (const auto& asset : m_classInfoAssets)
    {
        TypeInfo* type = RegisterType(m_typeBuilder, asset);

        m_createdTypeInfo.push_back(type);
        m_createdTypeInfoByName[asset->TypeName] = type;
        m_createdTypeInfoByGuid[*asset->GetInstanceGuid()] = type;

        KyberTypeRegistrationCallback callback = EntityManagerStaticData::Get().GetRegistrationCallback(asset->TypeName);
        if (callback == nullptr)
        {
            continue;
        }

        callback(type);
    }

    KYBER_LOG(Info, "[Entity] Built and registered " << m_classInfoAssets.size() << " custom types");
}

bool EntityManager::IsGuidUsed(const Guid& guid)
{
    return std::count(m_guids.begin(), m_guids.end(), guid);
}

bool EntityManager::HasCustomType(const char* name)
{
    for (const auto& asset : m_classInfoAssets)
    {
        if (strcmp(asset->TypeName, name) == 0)
        {
            continue;
        }

        return true;
    }

    return false;
}

void* NativeTypeRegistryInitHk(void* a1)
{
    static const auto trampoline = HookManager::Call(NativeTypeRegistryInitHk);
    KYBER_LOG(Debug, "Initializing type registry");

    g_program->m_entityManager->RegisterTypes();
    void* result = trampoline(a1);

    KYBER_LOG(Debug, "Initialized type registry");
    return result;
}

void PropertyReaderBaseSetFromDataBusPeerHk(PropertyReaderBase* inst, const DataContext* dc, const DataBusPeer* data, int fieldNameHash,
    const TypeInfo* typeInfo, const void* defaultValue)
{
    static auto trampoline = HookManager::Call(PropertyReaderBaseSetFromDataBusPeerHk);
    trampoline(inst, dc, data, fieldNameHash, typeInfo, defaultValue);
}

ClassInfoAsset* EntityManager::CreateClassInfoAsset(const KyberTypeInfo& info)
{
    size_t size = sizeof(DataContainer::GuidEntry) + sizeof(ClassInfoAsset);
    void* mem = ((uint8_t*)malloc(size)) + sizeof(DataContainer::GuidEntry);
    if (mem == nullptr)
    {
        KYBER_LOG(Info, "[Entity] Class info data null!");
        return nullptr;
    }

    ClassInfoAsset* asset = new (mem) ClassInfoAsset();
    asset->m_dcType = asset->getType();

    asset->m_dcFlags = 0;

    Guid instanceGuid = Guid::Generate();
    m_guids.push_back(instanceGuid);
    asset->SetInstanceGuid(instanceGuid);

    KYBER_LOG(Trace, "Guid for " << info.GetName() << " is " << instanceGuid.ToString());

    asset->Name = (char*)"test";
    asset->ModuleName = StringUtils::CopyWithArena("Kyber");
    asset->TypeName = StringUtils::CopyWithArena(info.GetName());
    asset->IsMeta = false;
    asset->IsNative = false;

    KYBER_LOG(Debug, "Registering " << asset->TypeName);

    std::vector<TypeInfoFieldData*> fields;

    void* iter = nullptr;
    for (const auto& field : info.GetFields())
    {
        const char* typeName = field.typeName.c_str();
        const char* fieldName = field.name.c_str();

        bool isArray = field.isArray;

        KYBER_LOG(Trace, "Name: " << typeName << " " << isArray);

        TypeInfo* typeInfo = nullptr;
        if (m_nativeTypeInfo.count(typeName) > 0)
        {
            typeInfo = m_nativeTypeInfo[typeName];
        }

        KYBER_LOG(Trace, "TypeInfo: " << fieldName << "/" << std::hex << typeInfo);
        TypeInfoFieldData* data = CreateFieldData(StringUtils::CopyWithArena(fieldName), nullptr, typeInfo, isArray);
        fields.push_back(data);

        if (typeInfo == nullptr)
        {
            m_fieldsPendingTypeAssignment.push_back({ typeName, data });
        }
    }

    TypeInfoFieldCollection* collection = new TypeInfoFieldCollection();
    collection->Fields.init(fields.size());
    for (int i = 0; i < fields.size(); i++)
    {
        collection->Fields.m_data[i] = fields[i];
    }

    TypeInfoFieldCollectionRef ref{};
    ref.Collection = collection;

    asset->FieldCollections.init(1);
    asset->FieldCollections.m_data[0] = ref;

    TypeInfo* parentType = nullptr;
    if (info.GetParentName().has_value())
    {
        const char* parentName = StringUtils::CopyWithArena(*info.GetParentName());
        if (m_nativeTypeInfo.count(parentName) > 0)
        {
            parentType = m_nativeTypeInfo[parentName];
        }
        else
        {
            m_classesPendingParentAssignment.push_back({ parentName, asset });
        }
    }

    asset->Alignment = 0;
    asset->SuperClassRef.Asset = nullptr;
    asset->SuperClassRef.TypeInfo.m_typeInfo = parentType;
    asset->IsAbstract = 0;
    asset->IsSealed = 1;

    return asset;
}

void KyberEntityBase::FireEvent(EventId entityEvent)
{
    EntityEvent event = entityEvent;
    FullEntityBusInternalFireEventHk(m_nativeEntity->m_entityBus, reinterpret_cast<const DataContainer*>(m_data), &event);
}

void KyberEntityBase::FireEvent(const char* event)
{
    KYBER_LOG(Debug, "Firing event " << event);

    FireEvent(StringUtils::HashQuick(event));
}

void EntityManagerOnDestroyHk(NativeEntity* entity)
{
    if (g_program->m_entityManager == nullptr)
    {
        return;
    }

    KyberEntityBase* kyberEntity = g_program->m_entityManager->GetKyberEntity(entity);
    if (kyberEntity == nullptr)
    {
        return;
    }

    kyberEntity->OnDestroy();

    g_program->m_entityManager->RemoveEntity(entity);
    delete kyberEntity;
}

void EntityManagerEventHk(NativeEntity* entity, EntityEvent* entityEvent)
{
    if (g_program->m_entityManager == nullptr)
    {
        return;
    }

    KyberEntityBase* kyberEntity = g_program->m_entityManager->GetKyberEntity(entity);
    if (kyberEntity == nullptr)
    {
        return;
    }

    kyberEntity->Event(entityEvent);
}

void EntityManagerDeinitHk(NativeEntity* entity, void* info)
{
    if (g_program->m_entityManager == nullptr)
    {
        return;
    }

    KyberEntityBase* kyberEntity = g_program->m_entityManager->GetKyberEntity(entity);
    if (kyberEntity == nullptr)
    {
        return;
    }

    kyberEntity->Deinit(info);
}

void EntityManagerPropertyChangedHk(NativeEntity* entity, PropertyModification* modification)
{
    if (g_program->m_entityManager == nullptr)
    {
        return;
    }

    KyberEntityBase* kyberEntity = g_program->m_entityManager->GetKyberEntity(entity);
    if (kyberEntity == nullptr)
    {
        return;
    }

    kyberEntity->PropertyChanged(modification);
}

// I don't know
bool ValidateEntityBus(const void* entityBus)
{
    return (*reinterpret_cast<const __int64*>(reinterpret_cast<const __int64>(entityBus) + 0x20)) != 0;
}

const void* PropertyReaderBase::Get() const
{
    return PropertyReaderBaseGetHk(this);
}

void* KyberEntityBase::ReadField(const char* fieldName)
{
    // FieldInfoData* fieldInfo = nullptr;

    // ClassInfoData* infoData = (ClassInfoData*)m_data->m_dcType->typeInfoData;
    // for (int i = 0; i < infoData->fieldCount; i++)
    // {
    //     FieldInfoData& field = infoData->fields[i];
    //     if (strcmp(field.name, fieldName) != 0)
    //     {
    //         continue;
    //     }

    //     fieldInfo = &field;
    // }

    // if (fieldInfo == nullptr)
    // {
    //     KYBER_LOG(Error, "Field is null");
    //     return nullptr;
    // }

    int fieldHash = StringUtils::HashQuick(fieldName);

    DataContext dc;
    DataContext_ctor(m_nativeEntity->m_entityBus, &dc);

    if (!ValidateEntityBus(dc.bus))
    {
        return nullptr;
    }

    PropertyReaderBase reader;
    PropertyReaderBase_set(&reader, &dc, m_data, fieldHash, nullptr, nullptr);

    return PropertyReaderBaseGetHk(&reader);
}

void KyberEntityBase::WriteField(const char* fieldName)
{
    FieldInfoData* fieldInfo = nullptr;

    ClassInfoData* infoData = (ClassInfoData*)m_data->m_dcType->typeInfoData;
    KYBER_LOG(Debug, "Info data: " << infoData->name << " " << infoData->fieldCount);
    for (int i = 0; i < infoData->fieldCount; i++)
    {
        FieldInfoData& field = infoData->fields[i];
        if (strcmp(field.name, fieldName) != 0)
        {
            continue;
        }

        fieldInfo = &field;
        break;
    }

    if (fieldInfo == nullptr)
    {
        KYBER_LOG(Error, "Failed to find field to create a property writer");
        return;
    }

    int fieldHash = StringUtils::HashQuick(fieldInfo->name);

    DataContext dc;
    DataContext_ctor(m_nativeEntity->m_entityBus, &dc);

    void* fieldData = (uint8_t*)m_data + fieldInfo->fieldOffset;

    // if (fieldInfo->fieldTypePtr->getBasicType() == kTypeCode_Class)
    {
        fieldData = *(void**)fieldData;
    }

    PropertyWriterBase writer;
    PropertyWriterBase_init(&writer, &dc, m_data, fieldHash, fieldInfo->fieldTypePtr, fieldData, true);

    KYBER_LOG(Info,
        "Wrote " << fieldInfo->name << " (" << fieldInfo->fieldTypePtr->getName() << ") to writer (at: " << std::hex << fieldData << ")");
}

void KyberEntityBase::WriteField(const char* fieldName, const TypeInfo* type, void* data)
{
    int fieldHash = StringUtils::HashQuick(fieldName);

    DataContext dc;
    DataContext_ctor(m_nativeEntity->m_entityBus, &dc);

    PropertyWriterBase writer;
    PropertyWriterBase_init(&writer, &dc, m_data, fieldHash, type, data, true);
}

bool isKindOf(const ClassInfo* typeInfo, const char* name)
{
    if (strcmp(typeInfo->getName(), name) == 0)
    {
        return true;
    }

    ClassInfo* superClass = typeInfo->typeInfoData->superClass;
    if (superClass != nullptr && superClass != typeInfo)
    {
        return isKindOf(superClass, name);
    }

    return false;
}

void EntityManager::UpdateEntities(Realm realm, const UpdateParameters& params)
{
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    for (const auto& binding : m_bindings)
    {
        if (!binding.kyber->m_wantUpdates || !binding.kyber->m_isInitialized)
        {
            continue;
        }

        if (binding.native->GetRealm() != realm)
        {
            continue;
        }

        binding.kyber->Update(params);
    }
}

NativeEntity* EntityManager::CreateEntity(EntityBus* bus, GameObjectData* data, const LinearTransform& transform, Realm realm)
{
    EntityCreationInfo info;

    if (realm == Realm_Client)
    {
        EntityCreationInfo_ctorClient(&info, data, bus, transform);
    }
    else if (realm == Realm_Server)
    {
        EntityCreationInfo_ctorServer(&info, data, bus, transform);
    }
    else
    {
        KYBER_LOG(Error, "Invalid realm " << realm << " while creating entity " << data->getType()->getName());
        return nullptr;
    }

    DataContext dc;
    DataContext_ctor(bus, &dc);

    NativeEntity* entity = EntityFactory_internalCreateEntity(info, dc);
    if (entity == nullptr)
    {
        KYBER_LOG(Error, "Failed to create entity from " << data->getType()->getName());
        return nullptr;
    }

    KYBER_LOG(Debug, "Created entity " << data->getType()->getName());
    return entity;
}

TypeObject* EntityManager::CreateEntity(void* params, DataContainer* data)
{
    const TypeInfo* typeInfo = data->getType();
    if (typeInfo == nullptr)
    {
        return nullptr;
    }

    const char* name = typeInfo->getName();
    // KYBER_LOG(Trace, "Creating entity for " << name);

    if (g_program->m_scriptManager != nullptr)
    {
        g_program->m_scriptManager->GetEventManager().Fire(std::string("EntityFactory:Create:") + name, data);
    }

    bool isOverrideCreator = EntityManagerStaticData::Get().IsOverrideCreator(typeInfo->getName());
    if (!isOverrideCreator && !std::count(m_createdTypeInfo.begin(), m_createdTypeInfo.end(), typeInfo))
    {
        return nullptr;
    }

    NativeEntity* entity = EntityCreator_createConsoleCommandEntity(nullptr, params);
    if (entity == nullptr)
    {
        KYBER_LOG(Warning, "Failed to create entity for " << name);
        return nullptr;
    }
    PlatformUtils::DuplicateVTable(entity, 106);

    KyberEntityBase* kyberEntity = EntityManagerStaticData::Get().GetCreator(typeInfo->getName())(this, entity, data);

    kyberEntity->m_isSpatialEntity = isKindOf(reinterpret_cast<const ClassInfo*>(typeInfo), "SpatialEntityData");

    void* origPropertyChangedFn = PlatformUtils::HookVTableFunction(entity, EntityManagerPropertyChangedHk, 5);
    void* origOnDestroyFn = PlatformUtils::HookVTableFunction(entity, EntityManagerOnDestroyHk, 9);
    void* origEventFn = PlatformUtils::HookVTableFunction(entity, EntityManagerEventHk, 7);
    void* origDeinitFn = PlatformUtils::HookVTableFunction(entity, EntityManagerDeinitHk, 20);
    // void* origDtorFn = PlatformUtils::HookVTableFunction(entity, EntityManagerDtorHk, 1);

    if (!isOverrideCreator)
    {
        kyberEntity->m_origPropertyChangedFn = reinterpret_cast<Entity_propertyChanged_t>(origPropertyChangedFn);
        kyberEntity->m_origOnDestroyFn = reinterpret_cast<Entity_onDestroy_t>(origOnDestroyFn);
        kyberEntity->m_origEventFn = reinterpret_cast<Entity_event_t>(origEventFn);
        kyberEntity->m_origDeinitFn = reinterpret_cast<Entity_deinit_t>(origDeinitFn);
        // kyberEntity->m_origDtorFn = reinterpret_cast<Entity_dtor_t>(origDtorFn);
    }
    else
    {
        // Since fully overriden entities don't have a base
        // entity, this prevents an infinite loop
        kyberEntity->m_origPropertyChangedFn = nullptr;
        kyberEntity->m_origOnDestroyFn = nullptr;
        kyberEntity->m_origEventFn = nullptr;
        kyberEntity->m_origDeinitFn = nullptr;
        kyberEntity->m_origDtorFn = nullptr;
    }

    KYBER_LOG(Trace, "Created custom entity for " << typeInfo->getName() << " with data at " << data);

    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_bindings.push_back({ entity, kyberEntity });
    return entity;
}

void EntityManager::OnEntityCreated(NativeEntity* entity)
{
    if (entity->IsComponent())
    {
        return;
    }

    const ClassInfo* typeInfo = reinterpret_cast<const ClassInfo*>(entity->getType());
    bool isSpatialEntity = entity->IsSpatial();

    uintptr_t entityPtr = reinterpret_cast<uintptr_t>(entity);
    const DataContainer* data = reinterpret_cast<NativeEntity*>(isSpatialEntity ? entityPtr + SpatialEntityOffset : entityPtr)->m_data;
    if (data == nullptr)
    {
        return;
    }

    TypeInfo* dataType = data->getType();
    if (std::count(m_createdTypeInfo.begin(), m_createdTypeInfo.end(), dataType))
    {
        return;
    }

    auto creator = EntityManagerStaticData::Get().GetCreator(dataType->getName());
    if (creator == nullptr)
    {
        return;
    }

    if (GetKyberEntity(entity) != nullptr)
    {
        return;
    }

    KyberEntityBase* kyberEntity = creator(this, entity, const_cast<DataContainer*>(data));

    // const size_t numVtableFuncs = isSpatialEntity ? 148 : 106;
    const size_t numVtableFuncs = 106;
    PlatformUtils::DuplicateVTable(entity, numVtableFuncs);
    //*reinterpret_cast<uintptr_t*>(entity) = reinterpret_cast<uintptr_t>(duplicatedVTable);

    void* origPropertyChangedFn = PlatformUtils::HookVTableFunction(entity, EntityManagerPropertyChangedHk, 5);
    void* origOnDestroyFn = PlatformUtils::HookVTableFunction(entity, EntityManagerOnDestroyHk, 9);
    void* origEventFn = PlatformUtils::HookVTableFunction(entity, EntityManagerEventHk, 7);
    void* origDeinitFn = PlatformUtils::HookVTableFunction(entity, EntityManagerDeinitHk, 20);
    // void* origDtorFn = PlatformUtils::HookVTableFunction(entity, EntityManagerDtorHk, 1);

    kyberEntity->m_origPropertyChangedFn = reinterpret_cast<Entity_propertyChanged_t>(origPropertyChangedFn);
    kyberEntity->m_origOnDestroyFn = reinterpret_cast<Entity_onDestroy_t>(origOnDestroyFn);
    kyberEntity->m_origEventFn = reinterpret_cast<Entity_event_t>(origEventFn);
    kyberEntity->m_origDeinitFn = reinterpret_cast<Entity_deinit_t>(origDeinitFn);
    // kyberEntity->m_origDtorFn = reinterpret_cast<Entity_dtor_t>(origDtorFn);

    KYBER_LOG(Debug, "Overrode entity " << dataType->getName() << " with custom variant, spatial: " << isSpatialEntity);

    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_bindings.push_back({ entity, kyberEntity });
}

KyberEntityBase* EntityManager::GetKyberEntity(NativeEntity* nativeEntity)
{
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    for (const auto& binding : m_bindings)
    {
        if (binding.native != nativeEntity)
        {
            continue;
        }

        return binding.kyber;
    }

    return nullptr;
}

void EntityManager::RemoveEntity(NativeEntity* entity)
{
    std::lock_guard<std::recursive_mutex> lock(m_mutex);
    m_bindings.erase(
        std::remove_if(m_bindings.begin(), m_bindings.end(), [&](KyberEntityBinding const& binding) { return binding.native == entity; }),
        m_bindings.end());
}

DataContainer* EntityManager::InternalCreateContainer(const std::string& name) const
{
    TypeInfo* type = nullptr;

    if (m_createdTypeInfoByName.count(name))
    {
        type = m_createdTypeInfoByName.at(name);
    }
    else if (m_nativeTypeInfo.count(name))
    {
        type = m_nativeTypeInfo.at(name);
    }
    else
    {
        KYBER_LOG(Error, "[Entity] Failed to find type " << name);
        return nullptr;
    }

    DataContainer* container = DataContainerClassInfo_createInstance(type, FB_GLOBAL_ARENA, true, true);
    container->m_dcType = type;
    return container;
}

EntityManager::EntityManager()
{
    KYBER_LOG(Info, "[Entity] Initializing Entity Manager");

    InitializeHooks();
}

void EntityManager::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x14543CD40), TypeBuilderInternalBuildHk);
    HookManager::CreateHook(HOOK_OFFSET(0x1453DA890), TypeBuilderInternalFindTypeHk);
    HookManager::CreateHook(HOOK_OFFSET(0x1454CF070), ArrayTypeInfoCtorHk);
    HookManager::CreateHook(HOOK_OFFSET(0x1453DB400), NativeTypeRegistryInitHk);
    HookManager::CreateHook(HOOK_OFFSET(0x145442740), PropertyReaderBaseSetFromDataBusPeerHk);

    BYTE ptch[] = { 0xEB };
    MemoryUtils::Patch(HOOK_OFFSET(0x1401D0D03), (void*)ptch, sizeof(ptch));
    MemoryUtils::Patch(HOOK_OFFSET(0x1401D0D5B), (void*)ptch, sizeof(ptch));
}
} // namespace Kyber
