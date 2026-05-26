#pragma once

#include <SDK/SDK.h>
#include <SDK/TypeInfo.h>
#include <SDK/Types.h>

#include <Utilities/StringUtils.h>

#include <cstdint>
#include <optional>
#include <unordered_set>

namespace Kyber
{
struct DataContext
{
    const void* bus;
    const void* data;
    const void* exposed;

    DataContext(const void* bus = 0, const void* data = 0, const void* exposed = 0)
        : bus(bus)
        , data(data)
        , exposed(exposed)
    {}
};

TL_DECLARE_FUNC(0x1471DF800, void, DataContext_ctor, void* entityBus, DataContext* dcOut);

#pragma pack(push, 1)
class CacheData
{
public:
    char pad_0000[56];         // 0x0000
    void* value;               // 0x0038
    class TypeInfo* valueType; // 0x0040
    uint32_t flags;            // 0x0048
};                             // Size: 0x0088

enum CacheDataFlags
{
    CacheDataFlags_IsValueSetFlag = 1 << 5,
    CacheDataFlags_IsValueWrittenFlag = 1 << 6,
};

struct PropertyWriterBase
{

    CacheData* m_cache = nullptr;

    bool HasConnection() const
    {
        return m_cache != nullptr;
    }

    bool HasConnectionValue() const
    {
        return m_cache != nullptr ? (m_cache->flags & (CacheDataFlags_IsValueSetFlag | CacheDataFlags_IsValueWrittenFlag)) != 0 : false;
        //return m_cache != nullptr ? (m_cache->flags & kIsValueWrittenFlag) != 0 : false;
    }
};

struct PropertyReaderBase
{
    CacheData* m_cache = nullptr;
    void* m_defaultValue = nullptr;

    bool HasConnection() const
    {
        return m_cache != nullptr;
    }

    bool HasConnectionValue() const
    {
        return m_cache != nullptr ? (m_cache->flags & CacheDataFlags_IsValueWrittenFlag) != 0 : false;
    }

    const void* Get() const;
};

TL_DECLARE_FUNC(0x145442490, void, PropertyReaderBase_set, PropertyReaderBase* inst, const DataContext* dc, const DataContainer* data, int fieldNameHash,
    const TypeInfo* typeInfo, const void* defaultValue);
TL_DECLARE_FUNC(0x14543AD40, void*, PropertyReaderBase_get, const PropertyReaderBase* inst);

template<typename T>
struct PropertyReader : PropertyReaderBase
{
    const T Get() const
    {
        return *reinterpret_cast<const T*>(PropertyReaderBase::Get());
    }
};

TL_DECLARE_FUNC(0x14543C580, void, PropertyWriterBase_init, PropertyWriterBase* inst, const DataContext* dc, const DataContainer* data,
    int fieldNameHash, const TypeInfo* typeInfo, const void* defaultValue, bool writeValue);
TL_DECLARE_FUNC(0x14543DC00, void*, PropertyWriterBase_get, const PropertyWriterBase* inst);
TL_DECLARE_FUNC(0x14543E700, void*, PropertyWriterBase_set, const PropertyWriterBase* inst, const void* value, bool callListeners);
#pragma pack(pop)

template<typename T>
struct PropertyWriter : PropertyWriterBase
{
    const T* Get() const
    {
        return reinterpret_cast<const T*>(PropertyWriterBase_get(this));
    }

    void init(const DataContext* dc, const DataContainer* data, int fieldNameHash, const TypeInfo* typeInfo, const void* defaultValue,
        bool writeValue)
    {
        PropertyWriterBase_init(this, dc, data, fieldNameHash, typeInfo, defaultValue, writeValue);
    }

    void Set(T* value) const
    {
        PropertyWriterBase_set(this, value, true);
    }

    void operator=(T* value) const
    {
        Set(value);
    }

    void operator=(T& value) const
    {
        Set(&value);
    }
};

struct PropertyModification
{
    uint32_t nameHash;
    void* value;
    TypeInfo* valueType;

    bool Is(const char* name)
    {
        return StringUtils::HashQuick(name) == nameHash;
    }
};

template<typename T>
struct PendingAssignment
{
    const char* ref;
    T* data;
};

typedef void(__fastcall* Entity_propertyChanged_t)(void* entity, PropertyModification* modification);
typedef void(__fastcall* Entity_onDestroy_t)(void* entity);
typedef void(__fastcall* Entity_event_t)(void* entity, EntityEvent* event);
typedef void(__fastcall* Entity_deinit_t)(void* entity, void* info);
typedef void(__fastcall* Entity_dtor_t)(void* entity);

const int SpatialEntityOffset = 0x10;

class KyberEntityBase
{
    friend class EntityManager;

public:
    KyberEntityBase(NativeEntity* entity, DataContainer* data);
    virtual ~KyberEntityBase();

    void FireEvent(EventId entityEvent);
    void FireEvent(const char* event);

    template<typename T>
    PropertyWriter<T> CreateFieldOverride(const char* fieldName, const TypeInfo* type, const void* defaultValue)
    {
        int fieldHash = StringUtils::HashQuick(fieldName);

        DataContext dc;
        DataContext_ctor(m_nativeEntity->m_entityBus, &dc);

        PropertyWriter<T> writer;
        writer.init(&dc, m_data, fieldHash, type, defaultValue, defaultValue != nullptr);
        return writer;
    }

    template<typename T>
    PropertyWriter<T> CreateFieldOverride(const char* fieldName, const TypeInfo* type)
    {
        return CreateFieldOverride<T>(fieldName, type, nullptr);
    }

    void* ReadField(const char* fieldName);
    void WriteField(const char* fieldName);
    void WriteField(const char* fieldName, const TypeInfo* type, void* data);

    template<typename T>
    PropertyReader<T> GetFieldReader(const char* fieldName) const
    {
        int fieldHash = StringUtils::HashQuick(fieldName);

        DataContext dc;
        DataContext_ctor(m_nativeEntity->m_entityBus, &dc);

        PropertyReader<T> reader;
        PropertyReaderBase_set(&reader, &dc, m_data, fieldHash, nullptr, nullptr);
        return reader;
    }

    template<typename T>
    T* ReadField(const char* fieldName)
    {
        return reinterpret_cast<T*>(ReadField(fieldName));
    }

    virtual void OnDestroy()
    {
        m_isInitialized = false;

        if (m_origOnDestroyFn == nullptr)
        {
            return;
        }

        m_origOnDestroyFn(m_nativeEntity);
    }

    virtual void Event(EntityEvent* event)
    {
        if (m_origEventFn == nullptr)
        {
            return;
        }

        m_origEventFn(m_nativeEntity, event);
    }

    virtual void PropertyChanged(PropertyModification* modification)
    {
        if (m_origPropertyChangedFn == nullptr)
        {
            return;
        }

        m_origPropertyChangedFn(m_nativeEntity, modification);
    }

    virtual void Deinit(void* info)
    {
        m_isInitialized = false;

        if (m_origDeinitFn == nullptr)
        {
            return;
        }

        m_origDeinitFn(m_nativeEntity, info);
    }

    virtual void Update(const UpdateParameters& params){};

    const DataContainer* GetData() const
    {
        return m_data;
    }

    Entity_propertyChanged_t m_origPropertyChangedFn = nullptr;

    Entity_onDestroy_t m_origOnDestroyFn = nullptr;
    Entity_event_t m_origEventFn = nullptr;

protected:
    NativeEntity* m_nativeEntity;
    const DataContainer* m_data;

    void SetWantUpdates(bool wantUpdates)
    {
        m_wantUpdates = wantUpdates;
    }

private:
    bool m_isSpatialEntity;
    bool m_isInitialized;
    bool m_wantUpdates;

    Entity_deinit_t m_origDeinitFn = nullptr;
    Entity_dtor_t m_origDtorFn = nullptr;
};

template<typename T>
class KyberEntity : public KyberEntityBase
{
public:
    KyberEntity(NativeEntity* entity, T* data)
        : KyberEntityBase(entity, data)
    {}

    const T* GetData() const
    {
        return static_cast<const T*>(m_data);
    }
};

struct KyberEntityBinding
{
    NativeEntity* native;
    KyberEntityBase* kyber;
};

using KyberEntityCreator = std::function<KyberEntityBase*(class EntityManager*, NativeEntity*, DataContainer*)>;
using KyberTypeRegistrationCallback = std::function<void(TypeInfo*)>;

struct KyberTypeInfoFieldData
{
    std::string typeName;
    std::string name;
    bool isArray;
};

class KyberTypeInfo
{
public:
    KyberTypeInfo(const char* name, const char* parent = nullptr);

    void AddField(const char* typeName, const char* name, bool isArray = false);

    std::string GetName() const
    {
        return m_name;
    }

    std::optional<std::string> GetParentName() const
    {
        return m_hasParent ? std::make_optional(m_parentName) : std::nullopt;
    }

    const std::vector<KyberTypeInfoFieldData>& GetFields() const
    {
        return m_fields;
    }

private:
    std::string m_name;
    std::string m_parentName;

    bool m_hasParent;

    std::vector<KyberTypeInfoFieldData> m_fields;
};

class EntityManagerStaticData
{
public:
    static EntityManagerStaticData& Get()
    {
        static EntityManagerStaticData instance;
        return instance;
    }

    void RegisterType(const KyberTypeInfo& typeInfo)
    {
        m_registeredTypeInfo.push_back(typeInfo);
    }

    void RegisterEntity(const std::string& dataName, KyberEntityCreator creator, bool override = false)
    {
        m_creators[dataName] = creator;

        if (override)
        {
            m_overrideCreators.insert(dataName);
        }
    }

    void RegisterRegistrationCallback(const std::string& typeName, KyberTypeRegistrationCallback callback)
    {
        m_registrationCallbacks[typeName] = callback;
    }

    const std::vector<KyberTypeInfo>& GetTypeInfo() const
    {
        return m_registeredTypeInfo;
    }

    bool IsOverrideCreator(const std::string& dataName)
    {
        return m_overrideCreators.count(dataName);
    }

    KyberEntityCreator GetCreator(const std::string& dataName)
    {
        if (!m_creators.count(dataName))
        {
            return nullptr;
        }

        return m_creators[dataName];
    }

    KyberTypeRegistrationCallback GetRegistrationCallback(const std::string& typeName)
    {
        if (!m_registrationCallbacks.count(typeName))
        {
            return nullptr;
        }

        return m_registrationCallbacks[typeName];
    }

private:
    std::vector<KyberTypeInfo> m_registeredTypeInfo;

    // Creators for wrappers of existing entities and custom entities
    std::map<std::string, KyberEntityCreator> m_creators;

    // Marks a creator as without an Entity typeinfo, like PropertyDebugEntity;
    // there's typeinfo for PropertyDebugEntityData, but not for PropertyDebugEntity itself
    std::unordered_set<std::string> m_overrideCreators;

    std::map<std::string, KyberTypeRegistrationCallback> m_registrationCallbacks;
};

class EntityStaticRegistrar
{
public:
    EntityStaticRegistrar(const KyberTypeInfo& typeInfo)
    {
        EntityManagerStaticData& data = EntityManagerStaticData::Get();
        data.RegisterType(typeInfo);
    }

    EntityStaticRegistrar(const std::string& dataName, KyberEntityCreator creator, bool override)
    {
        EntityManagerStaticData& data = EntityManagerStaticData::Get();
        data.RegisterEntity(dataName, creator, override);
    }

    EntityStaticRegistrar(const std::string& typeName, KyberTypeRegistrationCallback callback)
    {
        EntityManagerStaticData& data = EntityManagerStaticData::Get();
        data.RegisterRegistrationCallback(typeName, callback);
    }
};

#define KB_IMPLEMENT_TYPE(name)                                                                                                            \
    KyberTypeInfo __entityTypeInfo__##name##Data();                                                                                        \
    EntityStaticRegistrar _typeRegistrar_##name(__entityTypeInfo__##name##Data());                                                         \
    KyberTypeInfo __entityTypeInfo__##name##Data()

#define KB_INTERNAL_IMPLEMENT_ENTITY(name, dataType, override)                                                                             \
    KyberEntityBase* __entityCreator__##name##_##dataType(EntityManager* entityManager, NativeEntity* entity, DataContainer* data)                      \
    {                                                                                                                                      \
        return new name(entityManager, entity, reinterpret_cast<dataType*>(data));                                                         \
    }                                                                                                                                      \
                                                                                                                                           \
    EntityStaticRegistrar _entityRegistrar_##name##_##dataType(#dataType, __entityCreator__##name##_##dataType, override)

#define KB_IMPLEMENT_ENTITY(name, dataType) KB_INTERNAL_IMPLEMENT_ENTITY(name, dataType, false)
#define KB_IMPLEMENT_ENTITY_OVERRIDE(name, dataType) KB_INTERNAL_IMPLEMENT_ENTITY(name, dataType, true)

#define KB_TYPE_REGISTRATION_CALLBACK(name)                                                                                                \
    void __typeInfoRegistrationCallback__##name(TypeInfo* typeInfo);                                                                       \
    EntityStaticRegistrar _entityRegistrar_##name(#name, __typeInfoRegistrationCallback__##name);                                          \
    void __typeInfoRegistrationCallback__##name(TypeInfo* typeInfo)

class EntityManager
{
public:
    EntityManager();

    ClassInfoAsset* CreateClassInfoAsset(const KyberTypeInfo& info);

    void InitializeHooks();
    void RegisterNativeTypeInfo();

    void RegisterTypes();
    bool IsGuidUsed(const Guid& guid);
    bool HasCustomType(const char* name);

    void UpdateEntities(Realm realm, const UpdateParameters& params);

    NativeEntity* CreateEntity(EntityBus* bus, GameObjectData* data, const LinearTransform& transform, Realm realm);

    TypeObject* CreateEntity(void* params, DataContainer* data);
    void OnEntityCreated(NativeEntity* entity);

    KyberEntityBase* GetKyberEntity(NativeEntity* nativeEntity);
    void RemoveEntity(NativeEntity* nativeEntity);

    template<class T>
    T* CreateContainer(const std::string& name) const
    {
        return static_cast<T*>(InternalCreateContainer(name));
    }
    template<class T>
    T* CreateContainer(const TypeInfo* typeInfo) const
    {
        return static_cast<T*>(InternalCreateContainer(typeInfo));
    }

    TypeInfo* GetBuiltType(const Guid& guid)
    {
        return m_builtTypes.count(guid) ? m_builtTypes[guid] : nullptr;
    }

    void AddBuiltType(const Guid& guid, TypeInfo* typeInfo)
    {
        m_builtTypes[guid] = typeInfo;
    }

    const TypeInfo* GetNativeType(const std::string& name)
    {
        return m_nativeTypeInfo.count(name) ? m_nativeTypeInfo[name] : nullptr;
    }

    const TypeInfo* GetNativeTypeByGuid(const Guid& guid)
    {
        return m_nativeTypeInfoGuidMap.count(guid) ? m_nativeTypeInfoGuidMap[guid] : nullptr;
    }

    bool CreatedTypeExists(const Guid& guid)
    {
        for (const auto& asset : m_classInfoAssets)
        {
            if (!asset->GetInstanceGuid()->Equals(guid))
            {
                continue;
            }

            return true;
        }

        return false;
    }

    const TypeInfo* GetCreatedType(const Guid& guid)
    {
        return m_createdTypeInfoByGuid.count(guid) ? m_createdTypeInfoByGuid[guid] : nullptr;
    }

    ClassInfoAsset* GetClassInfoAsset(const Guid& guid)
    {
        for (const auto& asset : m_classInfoAssets)
        {
            if (!asset->GetInstanceGuid()->Equals(guid))
            {
                continue;
            }

            return asset;
        }

        return nullptr;
    }

    void* GetTypeBuilder() const
    {
        return m_typeBuilder;
    }

private:
    // Create a fully initialized data container for a custom type
    DataContainer* InternalCreateContainer(const std::string& name) const;
    DataContainer* InternalCreateContainer(const TypeInfo* typeInfo) const;

    std::vector<Guid> m_guids;
    std::map<Guid, TypeInfo*> m_builtTypes;

    std::vector<ClassInfoAsset*> m_classInfoAssets;
    std::vector<TypeInfo*> m_createdTypeInfo;
    std::map<std::string, TypeInfo*> m_createdTypeInfoByName;
    std::map<Guid, TypeInfo*> m_createdTypeInfoByGuid;

    std::recursive_mutex m_mutex;
    std::vector<KyberEntityBinding> m_bindings;

    std::vector<PendingAssignment<ClassInfoAsset>> m_classesPendingParentAssignment;
    std::vector<PendingAssignment<TypeInfoFieldData>> m_fieldsPendingTypeAssignment;

    std::unordered_map<std::string, TypeInfo*> m_nativeTypeInfo;
    std::map<Guid, TypeInfo*> m_nativeTypeInfoGuidMap;

    void* m_typeBuilder;
};
} // namespace Kyber