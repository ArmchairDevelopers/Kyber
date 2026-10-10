// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/LiveEditManager.h>

#include <Base/Pch.h>

#include <EASTL/unordered_map.h>

namespace Kyber
{
TL_DECLARE_FUNC(
    0x1470B4750, EntityOwner*, SimpleEntityOwner_ctor, EntityOwner* inst, EntityOwner* parent, NativeEntity* owner, uintptr_t flags);
TL_DECLARE_FUNC(0x1474D4AB0, void*, EntityOwner_addRef, EntityOwner* inst);
TL_DECLARE_FUNC(0x1474DDA00, void*, EntityOwner_release, EntityOwner* inst);

TL_DECLARE_FUNC(0x14116F610, bool, Entity_init, NativeEntity* inst, EntityInitInfo* info);
TL_DECLARE_FUNC(0x1469DAF40, EntityInitInfo*, EntityInitInfo_ctor, EntityInitInfo* inst, Realm realm, void* context);

class KyberLiveEditEntityOwnerLifetimeEntityData : public EntityData
{
public:
    uint64_t Arena;
    uint64_t ParentOwner;
};

KB_IMPLEMENT_TYPE(KyberLiveEditEntityOwnerLifetimeEntityData)
{
    KyberTypeInfo info("KyberLiveEditEntityOwnerLifetimeEntityData", "EntityData");
    info.AddField("Uint64", "Arena");
    info.AddField("Uint64", "ParentOwner");
    return info;
}

class KyberLiveEditEntityOwnerLifetimeEntity : public KyberEntity<KyberLiveEditEntityOwnerLifetimeEntityData>
{
public:
    KyberLiveEditEntityOwnerLifetimeEntity(
        EntityManager* entityManager, NativeEntity* entity, KyberLiveEditEntityOwnerLifetimeEntityData* data)
        : KyberEntity(entity, data)
    {
        //KYBER_LOG(Info, "Constructed live edit entity owner lifetime entity");

        MemoryArena* arena = reinterpret_cast<MemoryArena*>(data->Arena);

        m_childOwner = reinterpret_cast<EntityOwner*>(FB_GLOBAL_ARENA->alloc(0x58));
        if (m_childOwner == nullptr)
        {
            KYBER_LOG(Error, "Failed to allocate new entity owner");
        }

        EntityOwner* parentOwner = reinterpret_cast<EntityOwner*>(data->ParentOwner);
        SimpleEntityOwner_ctor(m_childOwner, parentOwner, entity, parentOwner->m_prevSibling);

        // EntityOwner_addRef(owner);
        EntityOwner_addRef(m_childOwner);
    }

    void OnDestroy() override
    {
        Realm realm = m_nativeEntity->GetRealm();
        printf("Destroyed live edit entity owner lifetime entity %d\n", realm);

        if (g_entityWorld[realm] == nullptr)
        {
            KYBER_LOG(Warning, "Live edit entity owner lifetime entity destroyed with invalid entity world!");
            return;
        }

        m_childOwner->DestroyOwnedEntities(realm);

        KyberEntityBase::OnDestroy();
        //EntityOwner_release(m_childOwner);
    }

    void Deinit(void* info) override
    {
        //KYBER_LOG(Info, "Deinited live edit entity owner lifetime entity");

        m_childOwner->DeinitOwnedEntities(info);

        KyberEntityBase::Deinit(info);
    }

    void MarkDestruction()
    {
        m_nativeEntity->m_entityBus->m_owner->DestroyEntity(m_nativeEntity);
    }

    EntityOwner* GetChildOwner() const
    {
        return m_childOwner;
    }

private:
    EntityOwner* m_childOwner = nullptr;
};

KB_IMPLEMENT_ENTITY(KyberLiveEditEntityOwnerLifetimeEntity, KyberLiveEditEntityOwnerLifetimeEntityData);

struct EntityBusParams
{
    EntityBus* inst;
    MemoryArena* arena;
    EntityOwner* owner;
    EntityBus* parentBus;
    void* parentRep;
    EntityBusData* busData;
    void* exposedData;
    bool isSubLevel;
    bool usingCustomOwner;

    KyberLiveEditEntityOwnerLifetimeEntity* lifetimeEntity;
};

enum
{
    kCustomEntityOwnerFlag = 1 << 10
};

//static const char* kPrefabName = "UI/Frontend/Prefabs/ScreenLogic/PF_UI_KyberTest";
//static const char* kPrefabName = "UI/Frontend/Prefabs/ScreenLogic/PF_UI_PlayScreen";
static const char* kPrefabName = "UI/Frontend/Prefabs/ScreenLogic/PF_UI_CharacterScreen";

static eastl::unordered_map<EntityBus*, EntityBusParams> entityBusMap;

static EntityBus* FullEntityBusCtorHk(EntityBus* inst, MemoryArena* arena, EntityOwner* owner, EntityBus* parentBus, void* parentRep,
    EntityBusData* busData, void* exposedData, bool isSubLevel)
{
    static auto trampoline = HookManager::Call(FullEntityBusCtorHk);

    bool customOwner = false;
    EntityOwner* newOwner = owner;

    KyberLiveEditEntityOwnerLifetimeEntity* kyberLifetimeEntity = nullptr;

    // if ((owner->m_prevSibling & kCustomEntityOwnerFlag) != kCustomEntityOwnerFlag)
    if (false && busData->getType()->isKindOf(reinterpret_cast<const TypeInfo*>(0x144580560)))
    {
        if (!isSubLevel && parentBus != nullptr && parentRep != nullptr)
        // if (strcmp(busData->Name, kPrefabName) == 0)
        {
            auto* data = g_program->m_entityManager->CreateContainer<KyberLiveEditEntityOwnerLifetimeEntityData>("KyberLiveEditEntityOwnerLifetimeEntityData");

            data->Arena = reinterpret_cast<uint64_t>(arena);
            data->ParentOwner = reinterpret_cast<uint64_t>(owner);

            LinearTransform transform;
            NativeEntity* lifetimeEntity = g_program->m_entityManager->CreateEntity(parentBus, data, transform, Realm_Server);
            if (lifetimeEntity == nullptr)
            {
                KYBER_LOG(Error, "Failed to create entity owner lifetime entity!");
                return nullptr;
            }

            EntityInitInfo info;
            EntityInitInfo_ctor(&info, parentBus->GetRealm(), nullptr);
            Entity_init(lifetimeEntity, &info);

            KyberEntityBase* kyberEntity = g_program->m_entityManager->GetKyberEntity(lifetimeEntity);
            kyberLifetimeEntity = reinterpret_cast<KyberLiveEditEntityOwnerLifetimeEntity*>(kyberEntity);
            if (kyberLifetimeEntity == nullptr)
            {
                KYBER_LOG(Error, "Custom lifetime entity was null for " << busData->Name);
                newOwner = owner;
            }

            newOwner = kyberLifetimeEntity->GetChildOwner();
            if (newOwner == nullptr)
            {
                KYBER_LOG(Error, "Custom owner was null for " << busData->Name);
                newOwner = owner;
            }

            // newOwner = reinterpret_cast<EntityOwner*>(arena->alloc(0x58));
            // if (newOwner == nullptr)
            // {
            //     KYBER_LOG(Error, "Failed to allocate new entity owner");
            // }

            // SimpleEntityOwner_ctor(newOwner, owner, nullptr, kCustomEntityOwnerFlag);

            // // EntityOwner_addRef(owner);
            // EntityOwner_addRef(newOwner);

            KYBER_LOG(Info, "Using custom owner for " << busData->Name << " " << std::hex << newOwner << " Realm: " << std::dec << parentBus->GetRealm());

            // KYBER_LOG(Info, "Parent rep: " << parentRep);
            // KYBER_LOG(Info, "Exposed data: " << exposedData);
            // KYBER_LOG(Info, "Sub level: " << isSubLevel);
            // KYBER_LOG(Info, "Owner: " << owner);
            // KYBER_LOG(Info, "Parent: " << parentBus);

            customOwner = true;
        }
    }

    EntityBus* result = trampoline(inst, arena, newOwner, parentBus, parentRep, busData, exposedData, isSubLevel);
    if (busData->GetInstanceGuid() != nullptr)
    {
        KYBER_LOG(Debug, "Creating entity bus with owner " << std::hex << owner << " " << isSubLevel << " for " << busData->Name << " ("
                                                           << busData->GetInstanceGuid()->ToString() << ") " << parentBus << ": "
                                                           << result);
    }
    else
    {
        KYBER_LOG(Info, "Creating entity bus for " << busData->Name << " " << std::hex << parentBus << ": " << result);
    }

    entityBusMap[result] = { inst, arena, owner, parentBus, parentRep, busData, exposedData, isSubLevel, customOwner, kyberLifetimeEntity };
    return result;
}

static void* FullEntityBusDtorHk(EntityBus* inst)
{
    static auto trampoline = HookManager::Call(FullEntityBusDtorHk);
    KYBER_LOG(Debug, "Destroying entity bus " << std::hex << inst);

    EntityOwner* releaseOwner = nullptr;

    if (entityBusMap.count(inst))
    {
        const EntityBusParams& params = entityBusMap[inst];
        if (strcmp(params.busData->Name, kPrefabName) == 0)
        {
            KYBER_LOG(Info, "Deleting KyberTest bus " << std::hex << inst);
        }

        if (params.usingCustomOwner)
        {
            releaseOwner = inst->m_owner;
        }
    }

    entityBusMap.erase(inst);
    void* result = trampoline(inst);

    if (releaseOwner)
    {
        // EntityOwner_release(inst->owner);
    }

    return result;
}

void* ProxyEntityBusCtorHk(__int64 inst, __int64 owner, __int64 parent, __int64 a4, __int64 a5)
{
    static auto trampoline = HookManager::Call(ProxyEntityBusCtorHk);
    void* result = trampoline(inst, owner, parent, a4, a5);
    KYBER_LOG(Info, "Creating proxy entity bus: " << result);
    return result;
}

static bool EntityDeinitHk(NativeEntity* inst)
{
    static auto trampoline = HookManager::Call(EntityDeinitHk);
    KYBER_LOG(Debug, "Deinitializing entity " << inst->getType()->getName());
    return trampoline(inst);
}

void ReloadBusCommand(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Attempting blueprint reload, " << entityBusMap.size() << " currently loaded blueprints");

    auto copiedMap = entityBusMap;
    for (const auto& entry : copiedMap)
    {
        const EntityBusParams& params = entry.second;

        if (strcmp(params.busData->Name, kPrefabName) != 0)
        {
            continue;
        }

        if (!params.usingCustomOwner)
        {
            KYBER_LOG(Warning, "Couldn't reload blueprint, no custom owner");
            //continue;
        }

        Realm realm = params.inst->GetRealm();

        KYBER_LOG(Info, "Beginning blueprint reload for bus " << std::hex << params.inst << " realm " << std::dec << realm);

        int refCount = params.inst->m_refCount;

        bool hasEntities = false;

        for (const auto& entity : params.inst->m_owner->GetOwnedEntities())
        {
            if (entity->m_entityBus != params.inst)
            {
                continue;
            }

            // Some entity busses don't contain entities, and are just used to pass events
            // These are marked by a Client/Server-PlaceHolderEntity
            if (strstr(entity->getType()->getName(), "PlaceHolderEntity") != nullptr)
            {
                continue;
            }

            if (strcmp(entity->m_data->getType()->getName(), "KyberLiveEditEntityOwnerLifetimeEntityData") == 0)
            {
                continue;
            }

            KYBER_LOG(Info, "Entity: " << entity->getType()->getName() << " " << entity->m_data->getType()->getName());
            hasEntities = true;
        }

        if (!hasEntities)
        {
            KYBER_LOG(Info, "Skipping, no entities or placeholder found");
            continue;
        }

        //params.lifetimeEntity->MarkDestruction();

        // params.owner->DestroyOwnedEntitiesRecursively(realm);
        //params.inst->owner->DestroyOwnedEntitiesRecursively(realm);
        // params.owner->m_prevSibling &= ~1;

        auto childBusses = params.inst->GetAllChildBusses();

        eastl::unordered_set<EntityBus*> relevantBusSet(childBusses.begin(), childBusses.end());
        relevantBusSet.insert(params.inst);

        auto ownedEntities = params.owner->GetOwnedEntitiesRecursively();

        KYBER_LOG(Info, "Entity owner has " << ownedEntities.size() << " total entities");

        int entityCount = 0;
        for (const auto& entity : ownedEntities)
        {
            if (!relevantBusSet.count(entity->m_entityBus))
            {
                continue;
            }

            KYBER_LOG(Info, "Destroying entity " << entity->m_data->getType()->getName());
            params.owner->DestroyEntity(entity);
            ++entityCount;
        }

        for (const auto& bus : params.inst->GetAllChildBusses())
        {
            KYBER_LOG(Info, "Found child bus " << std::hex << bus);
        }

        static auto trampoline = HookManager::Call(FullEntityBusDtorHk);
        trampoline(params.inst);

        FullEntityBusCtorHk(params.inst, params.arena, params.owner, params.parentBus, params.parentRep, params.busData, params.exposedData,
            params.isSubLevel);

        params.inst->m_refCount = refCount;

        Blueprint* bp = reinterpret_cast<Blueprint*>(params.busData);

        // ReferenceObjectData* ref = reinterpret_cast<ReferenceObjectData*>(params.parentRep);
        // KYBER_LOG(Info, "Ref: " << ref->getType()->getName());
        
        // NativeEntity* entity = g_program->m_entityManager->CreateEntity(params.inst, ref);
        // if (entity == nullptr)
        // {
        //     KYBER_LOG(Error, "Failed to create reference entity");
        //     continue;
        // }

        eastl::vector<NativeEntity*> entities;
        entities.reserve(bp->Objects.size());

        for (const auto& data : bp->Objects)
        {
            LinearTransform transform;
            NativeEntity* entity = g_program->m_entityManager->CreateEntity(params.inst, data, transform, Realm_Server);
            if (entity == nullptr)
            {
                continue;
            }

            entities.push_back(entity);
        }

        for (const auto& entity : entities)
        {
            EntityInitInfo info;
            EntityInitInfo_ctor(&info, realm, nullptr);
            Entity_init(entity, &info);

            KYBER_LOG(Info, "Initialized entity, flags " << entity->m_flags);
        }

        KYBER_LOG(Info, "Reloaded bus " << params.busData->Name << " ref count " << refCount);

        std::string str = std::to_string(relevantBusSet.size());
        cc << "Reloaded '" << kPrefabName << "', " << entityCount << " entities over " << str << " busses";
    }
}

LiveEditManager::LiveEditManager()
{
    // clang-format off
    HookTemplate hookOffsets[] = {
        { HOOK_OFFSET(0x141146FC0), FullEntityBusCtorHk },
        { HOOK_OFFSET(0x141148600), FullEntityBusDtorHk },
        { HOOK_OFFSET(0x1474B6390), EntityDeinitHk },
        //{ HOOK_OFFSET(0x141147990), ProxyEntityBusCtorHk },
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }
    Hook::ApplyQueuedActions();

    g_program->m_consoleRegistrationCallbacks.push_back([&]() { RegisterConsoleCommand(&ReloadBusCommand, "ReloadBus"); });
}
}; // namespace Kyber