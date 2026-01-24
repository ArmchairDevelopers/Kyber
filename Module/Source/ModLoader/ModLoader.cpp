// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/ModLoader.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <SDK/SDK.h>
#include <Hook/HookManager.h>
#include <Utilities/MemoryUtils.h>
#include <Entity/KyberSettings.h>
#include <SDK/Funcs.h>

#include <ModLoader/Handlers/LocalizationHandler.h>
#include <ModLoader/Handlers/NetworkRegistryHandler.h>
#include <ModLoader/Handlers/MeshVariationHandler.h>
#include <ModLoader/Handlers/ProfileOptionsHandler.h>
#include <ModLoader/Handlers/UIMetaDataHandler.h>
#include <ModLoader/Handlers/WSTeamDataHandler.h>

#include <util.h>
#include <frosty_mod.h>
#include <parse_common.h>

#include <EASTL/unordered_set.h>
#include <EASTL/set.h>
#include <EASTL/sort.h>

#include <iostream>
#include <vector>
#include <map>

#define OFFSET_EBXPARTITIONREADER_PROCESS HOOK_OFFSET(0x14549B690)
#define OFFSET_RUNTIMEDATABASEDOMAIN_CTOR HOOK_OFFSET(0x140205180)
#define OFFSET_RUNTIMEDATABASEDOMAIN_READEBXPARTITIONFROMSTREAM HOOK_OFFSET(0x14020F070)
#define OFFSET_RUNTIMEDATABASEDOMAIN_FINDPARTITIONFROMGUIDINCLUDINGIMPORTS HOOK_OFFSET(0x140209310)
#define OFFSET_RUNTIMEDATABASEDOMAIN_FETCHNEWLYLOADEDPARTITIONS HOOK_OFFSET(0x140208CE0)
#define OFFSET_RESOURCEMANAGER_BEGINCHUNKREAD HOOK_OFFSET(0x1454B3F90)
#define OFFSET_RESOURCEMANAGER_BEGINCHUNKSCATTERREAD HOOK_OFFSET(0x14021F420)
#define OFFSET_RESOURCEMANAGER_BEGINCHUNKREADEX HOOK_OFFSET(0x14021F100)
#define OFFSET_RESOURCEMANAGER_ENDCHUNKREAD HOOK_OFFSET(0x1454B4CB0)
#define OFFSET_RESOURCEMANAGER_ENDCHUNKREADEX HOOK_OFFSET(0x14021FBE0)
#define OFFSET_RESOURCEMANAGER_POLLCHUNKOPERATION HOOK_OFFSET(0x140220790)
#define OFFSET_RESOURCEMANAGER_POLLCHUNKOPERATIONEX HOOK_OFFSET(0x140220890)
#define OFFSET_RESOURCEMANAGER_ADDLOADER HOOK_OFFSET(0x14021ED40)
#define OFFSET_RESOURCEMANAGER_BEGINLOADDATA HOOK_OFFSET(0x1454B41F0)
#define OFFSET_RESOURCEMANAGER_ENDLOADDATA HOOK_OFFSET(0x1454B4E20)
#define OFFSET_RESOURCEMANAGER_COMPARTMENT_ONBEGINBUNDLE HOOK_OFFSET(0x1454BC6B0)
#define OFFSET_RESOURCEMANAGER_LOOKUPDATACONTAINER HOOK_OFFSET(0x1454B82B0)
#define OFFSET_SHADERBLOCKDEPOT_FIXUPTURBOBULK HOOK_OFFSET(0x147C86050)
#define OFFSET_SHADER_HASH_CHECK HOOK_OFFSET(0x147CB7060)
#define OFFSET_ENTITYBUSPEER_ONCREATEHELPER HOOK_OFFSET(0x1473295D0)

// #define BUNDLE_AUDITS 1

#ifdef BUNDLE_AUDITS
    #define PUSH_MANIFEST_AUDIT(...) manifest.PushAudit(__VA_ARGS__)
#else
    #define PUSH_MANIFEST_AUDIT(...)
#endif

namespace Kyber
{
TL_DECLARE_FUNC(0x1454B5120, void, ResourceManager_forceUpdate);
TL_DECLARE_FUNC(0x145494CA0, void, HeartbeatMonitor_beat, const char* name);

ModLoader* g_modLoader;

class ResourceManager_Compartment
{
public:
    char pad_0000[96];                 // 0x0000
    ResourceCompartment m_compartment; // 0x0060
    ResourceCompartment m_parentCompartment;
    void* m_domain; // 0x0068
};

void* RuntimeDatabaseDomainCtorHk(
    void* inst, MemoryArena* arena, const char* name, const char* rootPath, __int16 compartment, void** imports)
{
    static auto trampoline = HookManager::Call(RuntimeDatabaseDomainCtorHk);
    KYBER_LOG(Info, "Created domain: " << name << " / " << rootPath);
    return trampoline(inst, arena, name, rootPath, compartment, imports);
}

// Debug settings
static bool logEbx = false;
static bool logChunks = false;
static std::string lastEbxLoad = "";

void LogLastEbxLoadCommand(ConsoleContext& cc)
{
    KYBER_LOG(Info, "Last EBX load: " << lastEbxLoad);
}

void EbxPartitionReaderProcessHk(EbxPartitionReader* inst, void* inBuffer, uint32_t inSize)
{
    static auto trampoline = HookManager::Call(EbxPartitionReaderProcessHk);
    trampoline(inst, inBuffer, inSize);

    if (inst->m_currentState != 7)
    {
        return;
    }

    if (!g_modLoader->m_dupedWithHandlerResources.count(inst->m_partitionName))
    {
        return;
    }

    ModResource& resource = g_modLoader->m_dupedWithHandlerResources[inst->m_partitionName];
    if (resource.handlerHash == 0)
    {
        KYBER_LOG(Error, "Duplicated asset with handler doesn't have a handler?");
        return;
    }

    KYBER_LOG(Debug, "Creating handler data " << resource.handlerHash);

    CustomAssetHandler* handler = g_modLoader->m_handlers[resource.handlerHash];
    CustomAssetHandlerData* data = handler->Create();

    bb::ByteBuffer buf(reinterpret_cast<uint8_t*>(const_cast<void*>(resource.data.buffer)), resource.data.size);
    KYBER_LOG(Debug, "Loading handler data " << buf.getNullTerminatedString());

    handler->Load(resource.modName, buf, data);
    handler->PreModify(*inst, data);
    KYBER_LOG(Debug, "Reading ebx " << inst << " " << inst->m_currentState);

    delete data;
}

bool RuntimeDatabaseDomainReadEbxPartitionFromStreamHk(void* inst, const char* name, const char* inBuffer, unsigned int inSize,
    int errorMsg, MemoryArena* fixupArena, DatabasePartition** partitionOut)
{
    static auto trampoline = HookManager::Call(RuntimeDatabaseDomainReadEbxPartitionFromStreamHk);
    if (logEbx)
    {
        KYBER_LOG(Info, "[ModLoader] Loading EBX asset: " << name << ", size: " << inSize);
    }

    if (!inBuffer || inSize == 0)
    {
        KYBER_LOG(Error, "[ModLoader] Failed to load EBX asset: " << name);
        return false;
    }

    DatabasePartition* partition = nullptr;
    bool result = trampoline(inst, name, inBuffer, inSize, errorMsg, fixupArena, &partition);
    if (partitionOut)
    {
        *partitionOut = partition;
    }

    auto it = g_modLoader->m_handlerResources.find(name);
    if (it == g_modLoader->m_handlerResources.end())
    {
        return result;
    }

    KyberHandledModResource& resource = it->second;
    if (!g_modLoader->m_handlers.count(resource.handlerHash))
    {
        KYBER_LOG(Info, "No handler for " << resource.handlerHash << " while loading " << name);
        return result;
    }

    KYBER_LOG(Debug, "Deferring EBX asset: " << name);
    DataContainer* container = partition->GetPrimaryInstance();
    g_modLoader->m_deferredContainerCreationQueue.push_back(ContainerCreationInfo{
        inst, *reinterpret_cast<uint32_t*>(reinterpret_cast<__int64>(inst) + 0x30), container, name, false, resource.dupedWithHandler });

    return result;
}

DataContainer* ResourceManagerLookupDataContainerHk(uint16_t compartment, const char* name)
{
    static auto trampoline = HookManager::Call(ResourceManagerLookupDataContainerHk);
    DataContainer* result = trampoline(compartment, name);
    // KYBER_LOG(Info, "Looking up data container '" << name << "' on compartment " << compartment << ": " << std::hex << result);

    // for (const auto& resource : g_modLoader->m_modResources)
    // {
    //     if (strcmp(resource.name, name) != 0)
    //     {
    //         continue;
    //     }

    //     KYBER_LOG(Info, resource.name << " is from " << resource.modName);
    //     //break;
    // }
    return result;
}

DatabasePartition* RuntimeDatabaseDomainFindPartitionFromGuidIncludingImportsHk(__int64 inst, const Guid& guid)
{
    static auto trampoline = HookManager::Call(RuntimeDatabaseDomainFindPartitionFromGuidIncludingImportsHk);
    DatabasePartition* partition = trampoline(inst, guid);
    return partition;
}


static std::map<__int64, PendingChunk> s_pendingChunksMap;
static std::map<Guid, ModifiedChunk> s_modifiedChunksMap;

uint64_t* ResourceManagerBeginChunkScatterReadHk(
    __int64* handleId, const Guid& guid, int a3, int a4, int a5, int readItemCount, void* readItems, int a8, int a9)
{
    static auto trampoline = HookManager::Call(ResourceManagerBeginChunkScatterReadHk);
    if (logChunks)
    {
        KYBER_LOG(Info, "Loading scatter chunk: " << guid.ToString());
    }

    return trampoline(handleId, guid, a3, a4, a5, readItemCount, readItems, a8, a9);
}

uint64_t* ResourceManagerBeginChunkReadHk(
    int* handleId, const Guid& guid, const void* buffer, int priority, int size, int bundleId, int a7)
{
    static auto trampoline = HookManager::Call(ResourceManagerBeginChunkReadHk);

    if (s_modifiedChunksMap.count(guid))
    {
        KYBER_LOG(Info, "[ModLoader] Loading custom overridden chunk: " << guid.ToString() << " Size: " << size << " Priority: " << priority
                                                            << " BundleId: " << bundleId << " a7: " << a7);
        ModifiedChunk& chunk = s_modifiedChunksMap[guid];
        PendingChunk pendingChunk{};
        *handleId = rand() % 100000;
        pendingChunk.handle = *handleId;
        pendingChunk.src = chunk.data;
        pendingChunk.srcSize = chunk.size;
        pendingChunk.dst = buffer;
        pendingChunk.dstSize = size;
        pendingChunk.dstOffset = 0;
        s_pendingChunksMap.emplace(*handleId, pendingChunk);
        return new uint64_t((uint64_t(2) << 56) | *handleId);
    }

    return trampoline(handleId, guid, buffer, priority, size, bundleId, a7);
}

bool ResourceManagerPollChunkOperationHk(uint64_t handle, bool* cancelled = 0)
{
    static auto trampoline = HookManager::Call(ResourceManagerPollChunkOperationHk);
    for (auto& pendingChunk : s_pendingChunksMap)
    {
        if (pendingChunk.first == handle)
        {
            KYBER_LOG(Debug, "[ModLoader] Polled chunk " << handle);
            return true;
        }
    }
    return trampoline(handle, cancelled);
}

bool ResourceManagerPollChunkOperationExHk(uint64_t handle, bool* cancelled = 0)
{
    static auto trampoline = HookManager::Call(ResourceManagerPollChunkOperationExHk);
    for (auto& pendingChunk : s_pendingChunksMap)
    {
        if (pendingChunk.first == handle)
        {
            KYBER_LOG(Debug, "[ModLoader] Polled chunk " << handle);
            return true;
        }
    }
    return trampoline(handle, cancelled);
}

bool ResourceManagerEndChunkReadHk(uint64_t handle)
{
    static auto trampoline = HookManager::Call(ResourceManagerEndChunkReadHk);
    for (auto& entry : s_pendingChunksMap)
    {
        if (entry.first == handle)
        {
            auto& pendingChunk = entry.second;
            MemoryUtils::Patch(const_cast<void*>(pendingChunk.dst), const_cast<void*>(pendingChunk.src),
                std::min(pendingChunk.dstSize, pendingChunk.srcSize));
            s_pendingChunksMap.erase(entry.first);
            return true;
        }
    }
    return trampoline(handle);
}

bool ResourceManagerEndChunkReadExHk(uint64_t handle)
{
    static auto trampoline = HookManager::Call(ResourceManagerEndChunkReadExHk);
    for (auto& entry : s_pendingChunksMap)
    {
        if (entry.first == handle)
        {
            auto& pendingChunk = entry.second;
            MemoryUtils::Patch(const_cast<void*>(pendingChunk.dst), const_cast<void*>(pendingChunk.src),
                std::min(pendingChunk.dstSize, pendingChunk.srcSize));
            s_pendingChunksMap.erase(entry.first);
            return true;
        }
    }
    return trampoline(handle);
}

void ResourceManagerAddLoaderHk(__int64 loader)
{
    static auto trampoline = HookManager::Call(ResourceManagerAddLoaderHk);
    return trampoline(loader);
}

void* ResourceManagerBeginLoadDataHk(void* handleOut, uint16_t compartment, const char* bundles[], int bundleCount,
    const uint32_t* chunkSet, int chunkSetCount, int priority)
{
    static auto trampoline = HookManager::Call(ResourceManagerBeginLoadDataHk);
    KYBER_LOG(Debug, "Loading " << bundleCount << " bundles:");
    for (int i = 0; i < bundleCount; i++)
    {
        KYBER_LOG(Debug, "Bundle: " << bundles[i]);
    }
    return trampoline(handleOut, compartment, bundles, bundleCount, chunkSet, chunkSetCount, priority);
}

bool ResourceManagerEndLoadDataHk(void* handle)
{
    static auto trampoline = HookManager::Call(ResourceManagerEndLoadDataHk);
    bool result = trampoline(handle);
    KYBER_LOG(Info, "[ModLoader] Ending bundle read: " << result);
    return result;
}

enum AsyncPriority
{
    AsyncPriority_Normal,
    AsyncPriority_Urgent
};

enum AsyncLoadType
{
    AsyncLoadType_StandAlone,
    AsyncLoadType_StandAloneCached,
    AsyncLoadType_FromBundle
};

void ResourceManagerStartUpdateThreadHk(uint32_t affinityMask)
{
    static auto trampoline = HookManager::Call(ResourceManagerStartUpdateThreadHk);
    KYBER_LOG(Info, "[ModLoader] Starting ResourceManager thread (AffinityMask: " << affinityMask << ")...");
    trampoline(affinityMask);
}

void MainLoopInitResourceManagerHk(void* inst)
{
    static auto trampoline = HookManager::Call(MainLoopInitResourceManagerHk);

    static bool done = false;
    if (!done)
    {
        KYBER_LOG(Info, "[ModLoader] Initializing ResourceManager");
        trampoline(inst);
    }
    else
    {
        KYBER_LOG(Warning, "[ModLoader] Tried to initialize ResourceManager again");
    }
}

void ModLoader::ReadChunkSync(const Guid& guid, const void* dstBuffer, uint32_t size)
{
    int handleId;
    uint64_t handle = *ResourceManagerBeginChunkReadHk(&handleId, guid, dstBuffer, 0, size, 0, 0);
    while (!ResourceManagerPollChunkOperationHk(handle))
    {
        KYBER_LOG(Info, "[ModLoader] Forcing a resource manager update");
        ResourceManager_forceUpdate();
        Sleep(5);
    }
    ResourceManagerEndChunkReadHk(handle);
}

void ModLoader::ModifyChunk(const Guid& guid, const void* data, uint32_t size)
{
    s_modifiedChunksMap[guid] = ModifiedChunk{ guid, data, size };
}

class DebugCompartment
{
public:
    struct Bundle
    {
        std::string name;
        bool loaded;
    };

    std::vector<Bundle> m_bundles;
};

static std::mutex loadingBundleLock;
static std::string loadingBundleName;
static std::map<void*, DebugCompartment> debugCompartments;

bool ResourceManagerCompartmentOnBeginBundleHk(ResourceManager_Compartment* inst, const char* bundleName, bool isReload)
{
    static auto trampoline = HookManager::Call(ResourceManagerCompartmentOnBeginBundleHk);

    static bool initialized = false;
    if (!initialized && strcmp(bundleName, "Systems/FrostbiteStartupData") == 0)
    {
        g_modLoader->m_resourceMerger.onResourceManagerInitialized();
        initialized = true;
    }

    std::lock_guard<std::mutex> lock(loadingBundleLock);
    loadingBundleName = bundleName;
    debugCompartments[inst].m_bundles.push_back({ bundleName, false });

    std::string platformBundleName = std::string("win32/") + bundleName;
    uint32_t bundleHash = StringUtils::HashQuickLower(platformBundleName.c_str());

    g_modLoader->m_compartmentToBundleId[inst->m_compartment] = bundleHash;

    KYBER_LOG(Info, "[ModLoader] Loading bundle " << bundleName << " (" << bundleHash << ") into compartment " << inst->m_compartment);
    return trampoline(inst, bundleName, isReload);
}

void RunHandler(ContainerCreationInfo& info, CustomAssetHandlerLoadStage loadStage)
{
    KYBER_LOG(Debug, "[ModLoader] Running deferred handler for " << info.name.c_str());

    eastl::vector<ModResource*> modResources;
    eastl::set<uint32_t> uniqueHandlers;

    for (auto& resource : g_modLoader->m_modResources)
    {
        if (resource.type != FrostyResourceType_Ebx || resource.name != info.name)
        {
            continue;
        }

        if (resource.handlerHash == 0)
        {
            continue;
        }

        if (g_modLoader->m_handlers[resource.handlerHash]->GetLoadStage() != loadStage)
        {
            continue;
        }

        modResources.push_back(&resource);
        uniqueHandlers.insert(resource.handlerHash);
    }

    if (modResources.empty() && uniqueHandlers.empty())
    {
        return;
    }

    std::map<uint32_t, CustomAssetHandlerData*> handlerData;
    for (const auto& handlerHash : uniqueHandlers)
    {
        KYBER_LOG(Debug, "Creating handler data");
        handlerData[handlerHash] = g_modLoader->m_handlers[handlerHash]->Create();
    }

    for (auto it = modResources.rbegin(); it != modResources.rend(); ++it)
    {
        auto resource = *it;

        bb::ByteBuffer buf(reinterpret_cast<uint8_t*>(const_cast<void*>(resource->data.buffer)), resource->data.size);
        KYBER_LOG(Debug, "Loading handler data " << buf.getNullTerminatedString());

        int32_t handlerHash = resource->handlerHash;
        g_modLoader->m_handlers[handlerHash]->Load(resource->modName, buf, handlerData[handlerHash]);
    }

    CustomAssetHandlerContext ctx;
    ctx.runtimeDatabaseDomain = info.runtimeDatabaseDomain;
    ctx.clearRequired = info.dupedWithHandler;

    for (const auto& handlerHash : uniqueHandlers)
    {
        KYBER_LOG(Debug, "Modifying handler data " << info.container->m_dcType->getName());
        while (!g_modLoader->m_handlers[handlerHash]->Modify(ctx, info.container, handlerData[handlerHash]))
        {
            KYBER_LOG(Warning, "Forcing resource manager update for handler modification");
            ResourceManager_forceUpdate();
            Sleep(5);
        }
    }

    for (const auto& data : handlerData)
    {
        delete data.second;
    }
}

void RuntimeDatabaseDomainFetchNewlyLoadedPartitionsHk(void* inst, eastl::vector<DatabasePartition*>& partitions)
{
    static auto trampoline = HookManager::Call(RuntimeDatabaseDomainFetchNewlyLoadedPartitionsHk);
    trampoline(inst, partitions);
    // KYBER_LOG(Info, "Loaded partitions: " << partitions.size());

    auto& vec = g_modLoader->m_domainLoadedPartitions[inst];
    for (const auto& partition : partitions)
    {
        vec[partition->GetPartitionGuid()] = partition;

        DataContainer* instance = partition->GetPrimaryInstance();

        if (g_program->m_scriptManager != nullptr)
        {
            g_program->m_scriptManager->GetEventManager().Fire("ResourceManager:PartitionLoaded", partition->GetName(), instance);
        }
    }

    KYBER_LOG(Debug, "Resolving references for compartment");

    auto& queue = g_modLoader->m_deferredContainerCreationQueue;
    for (auto it = queue.begin(); it != queue.end();)
    {
        ContainerCreationInfo& info = *it;
        bool found = false;
        for (const auto& partition : partitions)
        {
            if (partition->GetPrimaryInstance() != info.container)
            {
                continue;
            }

            found = true;
            break;
        }

        if (!found)
        {
            ++it;
            continue;
        }

        void* deferredDomain = info.runtimeDatabaseDomain;
        if (info.referencesResolved || inst != deferredDomain)
        {
            ++it;
            continue;
        }

        KYBER_LOG(Debug, "Running stage [ReferencesResolved] handlers");
        RunHandler(info, CustomAssetHandlerLoadStage_ReferencesResolved);

        info.referencesResolved = true;
        KYBER_LOG(Debug, "Setting references as resolved");
    }
}

void ResourceManagerCompartmentResolveReferencesHk(ResourceManager_Compartment* inst)
{
    static auto trampoline = HookManager::Call(ResourceManagerCompartmentResolveReferencesHk);
    trampoline(inst);

    for (auto& compartment : debugCompartments)
    {
        for (auto& bundle : compartment.second.m_bundles)
        {
            bundle.loaded = true;
        }
    }
}

void ResourceManagerCompartmentEndClearHk(ResourceManager_Compartment* inst)
{
    static auto trampoline = HookManager::Call(ResourceManagerCompartmentEndClearHk);
    trampoline(inst);

    debugCompartments.erase(inst);
    g_modLoader->m_domainLoadedPartitions.erase(inst->m_domain);

    KYBER_LOG(Debug, "Cleared resource compartment " << std::hex << inst);
}

void EntityBusPeerOnCreateHelperHk(__int64 inst, void* bus, const GameObjectData& data)
{
    static auto trampoline = HookManager::Call(EntityBusPeerOnCreateHelperHk);
    // KYBER_LOG(Info, "Registering entity bus peer for " << data.getType()->getName());
    return trampoline(inst, bus, data);
}

void ModLoader::Render()
{
    KyberSettings* settings = Settings<KyberSettings>("Kyber");
    if (settings == nullptr)
    {
        return;
    }

    // settings->RenderBundles = false;
    if (!settings->RenderBundles)
    {
        return;
    }

    // if (settings->RenderOnlyLoadingBundles)
    if (true)
    {
        bool hasLoadingBundles = false;
        for (const auto& entry : debugCompartments)
        {
            for (const auto& bundle : entry.second.m_bundles)
            {
                if (!bundle.loaded)
                {
                    hasLoadingBundles = true;
                }
            }
        }

        if (!hasLoadingBundles)
        {
            return;
        }
    }

    settings->BundleDebugFontSize = 1.f;

    int x = 30;
    int y = 50;

    std::lock_guard<std::mutex> lock(loadingBundleLock);
    // DebugRenderer_drawText(x, y, { 252, 186, 3, 255 }, "Bundles being loaded:", 1.25);
    // DebugRenderer_drawText(x, y, { 255, 255, 255, 255 }, "Bundles being loaded:", 0x3F800000);
    DebugRenderer_drawText(
        x, y, { 255, 255, 255, 255 }, "Loaded Bundles (" + std::to_string(debugCompartments.size()) + " compartments):", 1.0f);
    y += 20;

    for (const auto& entry : debugCompartments)
    {
        for (const auto& bundle : entry.second.m_bundles)
        {
            // Temporary
            if (bundle.loaded)
            {
                continue;
            }

            Color32 color = { 0, 255, 0, 255 };
            std::string text = bundle.name;

            if (!bundle.loaded)
            {
                color.r = 255;
                text += " (Loading)";
            }

            DebugRenderer_drawText(x + 5, y, color, text, settings->BundleDebugFontSize);
            y += 20;
        }
    }
}

void ResourceManagerUpdateResourcesHk(void* inst, bool newTick, bool forced)
{
    static auto trampoline = HookManager::Call(ResourceManagerUpdateResourcesHk);
    trampoline(inst, newTick, forced);

    static bool isRunningDeferredHandlers = false;
    if (isRunningDeferredHandlers)
    {
        return;
    }

    isRunningDeferredHandlers = true;

    auto& queue = g_modLoader->m_deferredContainerCreationQueue;
    for (auto it = queue.begin(); it != queue.end();)
    {
        ContainerCreationInfo& info = *it;
        if (!info.referencesResolved)
        {
            ++it;
            continue;
        }

        KYBER_LOG(Debug, "Running stage [PostLoad] handlers");
        RunHandler(info, CustomAssetHandlerLoadStage_PostLoad);
        queue.erase(it);
    }

    isRunningDeferredHandlers = false;
}

struct BundleLoadInfo
{
    const char* bundlePath;
};

__int64 BundleManagerLoadBundleHk(void* inst, const BundleLoadInfo& info)
{
    static auto trampoline = HookManager::Call(BundleManagerLoadBundleHk);
    KYBER_LOG(Debug, "Loading bundle " << info.bundlePath);
    return trampoline(inst, info);
}

auto compFileInfo = [](const LayoutManifest::FileInfo& lhs, const LayoutManifest::FileInfo& rhs) {
    if (lhs.file != rhs.file)
        return lhs.file < rhs.file;
    if (lhs.offset != rhs.offset)
        return lhs.offset < rhs.offset;
    return lhs.size < rhs.size;
};

static LayoutManifest::AuditLog s_layoutAuditLog;

void MergeBundleManifest(BundleManifest& manifest)
{
    std::lock_guard<std::mutex> lock(loadingBundleLock);
    std::string platformBundleName = std::string("win32/") + loadingBundleName;
    uint32_t bundleHash = StringUtils::HashQuickLower(platformBundleName.c_str());

    KYBER_LOG(Debug, "Loading bundle " << bundleHash);

    bool isCustomBundle = g_modLoader->m_addedBundles.count(bundleHash);
    if (isCustomBundle)
    {
        KYBER_LOG(Debug, "Loading custom bundle " << platformBundleName);
        manifest.Clear();
    }

    if (!isCustomBundle)
    {
        eastl::unordered_set<uint32_t> visited;
        for (auto& resource : g_modLoader->m_modResources)
        {
            if (resource.ContainsBundle(bundleHash))
            {
                continue;
            }

            if (resource.resourceIndex == -1 || resource.handlerHash != 0)
            {
                continue;
            }

            if (visited.count(resource.uniqueIdWithType))
            {
                continue;
            }

            visited.insert(resource.uniqueIdWithType);

            if (resource.type == FrostyResourceType_Ebx)
            {
                BundleMerger::VanillaEbxEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaEbxEntry(resource.name);
                if (originalEntry != nullptr)
                {
                    if (!originalEntry->bundleFileOffsets.count(bundleHash))
                    {
                        continue;
                    }

                    manifest.ModifyEbxEntry(resource.name, resource.data.originalSize);

                    int index = originalEntry->bundleFileOffsets[bundleHash];
                    PUSH_MANIFEST_AUDIT(eastl::string("[EBX] ") + resource.GetNameWithMod() +
                                        " modified (idx: " + eastl::string(std::to_string(index).c_str()) + ")");
                }
            }
            else if (resource.type == FrostyResourceType_Res)
            {
                BundleMerger::VanillaResEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaResEntry(resource.name);
                if (originalEntry != nullptr)
                {
                    if (!originalEntry->bundleFileOffsets.count(bundleHash))
                    {
                        continue;
                    }

                    uint32_t size = resource.data.originalSize;
                    BundleManifest::ResEntry entry;
                    entry.name = resource.name.c_str();
                    entry.originalSize = size;
                    entry.resType = resource.data.resType;
                    entry.resRid = resource.data.resRid;
                    memcpy(entry.resMeta, resource.data.resMeta, 0x10);
                    manifest.ModifyResEntry(entry);
                    PUSH_MANIFEST_AUDIT(eastl::string("[RES] ") + resource.GetNameWithMod() + " modified");
                }
            }
            else if (resource.type == FrostyResourceType_Chunk)
            {
                BundleMerger::VanillaChunkEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaChunkEntry(resource.name);
                if (originalEntry != nullptr)
                {
                    if (!originalEntry->bundleFileOffsets.count(bundleHash))
                    {
                        continue;
                    }

                    BundleManifest::ChunkEntry entry;
                    entry.guid = Guid::FromString(resource.name);
                    entry.logicalOffset = resource.data.logicalOffset;
                    entry.logicalSize = resource.data.logicalSize;
                    manifest.AddChunkEntry(entry, resource.data.h32, resource.data.firstMip, false);
                    PUSH_MANIFEST_AUDIT(eastl::string("[CHK] ") + resource.GetNameWithMod() + " modified");
                }
            }
        }
    }

    for (auto& resource : g_modLoader->m_bundleResources[bundleHash])
    {
        if (resource.handlerHash == 0 && resource.resourceIndex != -1)
        {
            if (resource.type == FrostyResourceType_Ebx)
            {
                uint32_t size = resource.data.originalSize;
                BundleManifest::Result result = manifest.AddEbxEntry(resource.name, size);

                if (result == BundleManifest::Rt_Added)
                {
                    PUSH_MANIFEST_AUDIT(eastl::string("[EBX] Added ") + resource.GetNameWithMod());
                }
                else if (result == BundleManifest::Rt_Modified)
                {
                    PUSH_MANIFEST_AUDIT(eastl::string("[EBX] Modified ") + resource.GetNameWithMod());
                }
            }
            else if (resource.type == FrostyResourceType_Res)
            {
                uint32_t size = resource.data.originalSize;
                BundleManifest::ResEntry entry;
                entry.name = resource.name.c_str();
                entry.originalSize = size;
                entry.resType = resource.data.resType;
                entry.resRid = resource.data.resRid;
                memcpy(entry.resMeta, resource.data.resMeta, 0x10);
                BundleManifest::Result result = manifest.AddResEntry(entry);

                if (result == BundleManifest::Rt_Added)
                {
                    PUSH_MANIFEST_AUDIT(eastl::string("[RES] Added ") + resource.GetNameWithMod());
                }
                else if (result == BundleManifest::Rt_Modified)
                {
                    PUSH_MANIFEST_AUDIT(eastl::string("[RES] Modified ") + resource.GetNameWithMod());
                }
            }
            else if (resource.type == FrostyResourceType_Chunk)
            {
                uint32_t size = resource.data.originalSize;
                BundleManifest::ChunkEntry entry;
                entry.guid = Guid::FromString(resource.name);
                entry.logicalOffset = resource.data.logicalOffset;
                entry.logicalSize = resource.data.logicalSize;
                BundleManifest::Result result = manifest.AddChunkEntry(entry, resource.data.h32, resource.data.firstMip);

                if (result == BundleManifest::Rt_Added)
                {
                    PUSH_MANIFEST_AUDIT(eastl::string("[CHK] Added ") + resource.GetNameWithMod());
                }
                else if (result == BundleManifest::Rt_Modified)
                {
                    PUSH_MANIFEST_AUDIT(eastl::string("[CHK] Modified ") + resource.GetNameWithMod());
                }
            }
            continue;
        }

        if (resource.type == FrostyResourceType_Ebx)
        {
            // Duped assets with handlers need to rely on a source asset
            eastl::string sourceName =
                !resource.dupedWithHandler ? resource.name : g_modLoader->m_dupedHandlerSources[resource.handlerHash];
            BundleMerger::VanillaEbxEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaEbxEntry(sourceName);
            int32_t originalSize = 0;
            if (!originalEntry)
            {
                // Warn and default to 1mb
                originalSize = 1000000;
                KYBER_LOG(
                    Warning, "Failed to find vanilla bundle entry size for EBX asset " << resource.name.c_str() << ", defaulting to 1mb");
            }
            else
            {
                originalSize = originalEntry->entry.originalSize;
            }

            manifest.AddEbxEntry(resource.name, originalSize, false);
            PUSH_MANIFEST_AUDIT(eastl::string("[EBX/No changes] Added ") + resource.GetNameWithMod());
        }
        else if (resource.type == FrostyResourceType_Res)
        {
            BundleMerger::VanillaResEntry* entry = g_modLoader->m_bundleMerger.GetVanillaResEntry(resource.name);
            if (!entry)
            {
                KYBER_LOG(Error, "Failed to find vanilla bundle entry for resource " << resource.name.c_str());
                continue;
            }

            manifest.AddResEntry(entry->entry, false);
            PUSH_MANIFEST_AUDIT(eastl::string("[RES/No changes] Added ") + resource.GetNameWithMod());
        }
        else if (resource.type == FrostyResourceType_Chunk)
        {
            BundleMerger::VanillaChunkEntry* entry = g_modLoader->m_bundleMerger.GetVanillaChunkEntry(resource.name);
            if (!entry)
            {
                continue;
            }

            BundleManifest::ChunkEntry chunkEntry;
            chunkEntry.guid = Guid::FromString(resource.name);
            chunkEntry.logicalOffset = entry->entry.logicalOffset;
            chunkEntry.logicalSize = entry->entry.logicalSize;
            BundleManifest::Result result = manifest.AddChunkEntry(chunkEntry, resource.data.h32, resource.data.firstMip, true, false);
            if (result != BundleManifest::Rt_Added)
            {
                PUSH_MANIFEST_AUDIT(eastl::string("[CHK] Error adding ") + resource.name);
            }

            PUSH_MANIFEST_AUDIT(eastl::string("[CHK/No changes] Added ") + resource.GetNameWithMod());
        }
    }

#ifdef BUNDLE_AUDITS
    const eastl::vector<eastl::string>& auditLog = manifest.GetAuditLog();
    if (!auditLog.empty())
    {
        const eastl::vector<eastl::string>& layoutAuditLog = s_layoutAuditLog[bundleHash];
        bool valid = auditLog.size() == layoutAuditLog.size();

        for (int i = 0; i < auditLog.size(); ++i)
        {
            const eastl::string& entry = auditLog[i];
            valid &= entry == layoutAuditLog[i];
        }

        // if (!valid)
        {
            if (!valid)
                KYBER_LOG(Error,
                    "[ModLoader] Bundle " << platformBundleName << " had an invalid mod mapping from layout->bundle manifest! This is very bad!");

            KYBER_LOG(Info, "[ModLoader] --- BEGIN BUNDLE AUDIT LOG - " + platformBundleName + " (" + std::to_string(bundleHash) + ") ---");
            for (int i = 0; i < auditLog.size(); ++i)
            {
                const eastl::string& entry = auditLog[i];
                KYBER_LOG(Info, entry.c_str());
            }
            KYBER_LOG(Info, "[ModLoader] --- END BUNDLE AUDIT LOG --- VALID: " << valid);

            KYBER_LOG(Info, "[ModLoader] --- BEGIN LAYOUT BUNDLE AUDIT LOG - " + std::to_string(bundleHash) + " ---");
            for (const auto& entry : s_layoutAuditLog[bundleHash])
            {
                KYBER_LOG(Info, "[ModLoader] " << entry.c_str());
            }
            KYBER_LOG(Info, "[ModLoader] --- END LAYOUT BUNDLE AUDIT LOG ---");
        }
    }
    else if (!s_layoutAuditLog[bundleHash].empty())
    {
        KYBER_LOG(Warning, platformBundleName << " has no bundle audit log, but a manifest audit log exists?");
    }
    else
    {
        KYBER_LOG(Warning, platformBundleName << " is completely empty?");
    }
#endif
}

void MergeLayoutManifest(LayoutManifest& manifest)
{
    KYBER_LOG(Info, "[ModLoader] Modifying layout manifest");

    eastl::unordered_set<eastl::string> modifiedChunks;

    for (auto& resource : g_modLoader->m_modResources)
    {
        if (resource.type == FrostyResourceType_Chunk)
        {
            if (resource.resourceIndex == -1)
            {
                continue;
            }

            if (modifiedChunks.count(resource.name))
            {
                continue;
            }

            uint32_t size = resource.data.size;
            LayoutManifest::FileInfo fileInfo = { resource.data.fbFile, static_cast<uint32_t>(resource.data.dataOffset), size };

            manifest.AddChunk(Guid::FromString(resource.name), fileInfo);
            modifiedChunks.insert(resource.name);
        }
        else if (resource.type == FrostyResourceType_Bundle)
        {
            uint32_t bundleHash = StringUtils::HashQuickLower(resource.name.c_str());
            manifest.AddBundle(bundleHash);
        }
    }

    KYBER_LOG(Info, "[ModLoader] Added new manifest chunks and bundles");

    eastl::unordered_set<uint32_t> modified;

    for (auto& resource : g_modLoader->m_modResources)
    {
        if (resource.resourceIndex == -1 || resource.handlerHash != 0)
        {
            continue; // Skip resources that don't meet the criteria
        }

        if (resource.type == FrostyResourceType_Ebx)
        {
            BundleMerger::VanillaEbxEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaEbxEntry(resource.name);
            if (originalEntry == nullptr)
            {
                continue;
            }

            for (const auto& entry : originalEntry->bundleFileOffsets)
            {
                if (resource.ContainsBundle(entry.first))
                {
                    continue;
                }

                uint32_t unique =
                    StringUtils::HashQuickLower((std::to_string(resource.uniqueIdWithType) + "_" + std::to_string(entry.first)).c_str());
                if (modified.count(unique))
                {
                    continue;
                }

                modified.insert(unique);

                uint32_t size = resource.data.size;
                LayoutManifest::FileInfo fileInfo = { resource.data.fbFile, static_cast<uint32_t>(resource.data.dataOffset), size };

                manifest.SetFileInfo(entry.first, entry.second, fileInfo);
                PUSH_MANIFEST_AUDIT(entry.first, eastl::string("[EBX] ") + resource.GetNameWithMod() +
                                                     " modified (idx: " + eastl::string(std::to_string(entry.second).c_str()) + ")");
            }
        }
        else if (resource.type == FrostyResourceType_Res)
        {
            BundleMerger::VanillaResEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaResEntry(resource.name);
            if (originalEntry == nullptr)
            {
                continue;
            }

            for (const auto& entry : originalEntry->bundleFileOffsets)
            {
                if (resource.ContainsBundle(entry.first))
                {
                    continue;
                }
                uint32_t unique =
                    StringUtils::HashQuickLower((std::to_string(resource.uniqueIdWithType) + "_" + std::to_string(entry.first)).c_str());
                if (modified.count(unique))
                {
                    continue;
                }

                modified.insert(unique);

                uint32_t size = resource.data.size;
                LayoutManifest::FileInfo fileInfo = { resource.data.fbFile, static_cast<uint32_t>(resource.data.dataOffset), size };

                manifest.SetFileInfo(entry.first, entry.second, fileInfo);
                PUSH_MANIFEST_AUDIT(entry.first, eastl::string("[RES] ") + resource.GetNameWithMod() + " modified");
            }
        }
        else if (resource.type == FrostyResourceType_Chunk)
        {
            BundleMerger::VanillaChunkEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaChunkEntry(resource.name);
            if (originalEntry == nullptr)
            {
                continue;
            }

            for (const auto& entry : originalEntry->bundleFileOffsets)
            {
                if (resource.ContainsBundle(entry.first))
                {
                    continue;
                }

                uint32_t unique =
                    StringUtils::HashQuickLower((std::to_string(resource.uniqueIdWithType) + "_" + std::to_string(entry.first)).c_str());
                if (modified.count(unique))
                {
                    continue;
                }

                modified.insert(unique);

                uint32_t size = resource.data.size;
                if (resource.data.rangeStart != 0)
                {
                    size = resource.data.rangeEnd - resource.data.rangeStart;
                }

                LayoutManifest::FileInfo fileInfo = { resource.data.fbFile,
                    static_cast<uint32_t>(resource.data.dataOffset) + resource.data.rangeStart, size };

                manifest.SetFileInfo(entry.first, entry.second, fileInfo);
                PUSH_MANIFEST_AUDIT(entry.first, eastl::string("[CHK] ") + resource.GetNameWithMod() + " modified");
            }
        }

        HeartbeatMonitor_beat("Main");
    }

    int bundleCount = g_modLoader->m_bundleResources.size();
    int stepSize = bundleCount / 10;
    int i = 0;

    for (auto& entry : g_modLoader->m_bundleResources)
    {
        // ----------------------------------------------------------------------------
        // We need to defer file additions because modifications use preset file offsets
        // from the vanilla bundle aggregation. If you add an EBX asset, then a RES modification
        // after that would use the incorrect offset
        struct DeferredBundleFileAdd
        {
            LayoutManifest::AssetType type;
            LayoutManifest::FileInfo file;
        };

        eastl::vector<DeferredBundleFileAdd> deferredFileAdds;
        // ----------------------------------------------------------------------------

        uint32_t bundleHash = entry.first;
        for (const auto& resource : entry.second)
        {
            // Process resources that are having their data added/replaced
            if (resource.handlerHash == 0 && resource.resourceIndex != -1)
            {
                if (resource.type == FrostyResourceType_Ebx)
                {
                    uint32_t size = resource.data.size;
                    LayoutManifest::FileInfo fileInfo = { resource.data.fbFile, static_cast<uint32_t>(resource.data.dataOffset), size };

                    BundleMerger::VanillaEbxEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaEbxEntry(resource.name);
                    if (originalEntry != nullptr)
                    {
                        auto it = originalEntry->bundleFileOffsets.find(bundleHash);
                        if (it == originalEntry->bundleFileOffsets.end())
                        {
                            deferredFileAdds.push_back({ LayoutManifest::Ebx, fileInfo });
                            PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[EBX] Added ") + resource.GetNameWithMod());
                        }
                        else
                        {
                            manifest.SetFileInfo(bundleHash, it->second, fileInfo);
                            PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[EBX] Modified ") + resource.GetNameWithMod());
                        }
                    }
                    else
                    {
                        deferredFileAdds.push_back({ LayoutManifest::Ebx, fileInfo });
                        PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[EBX] Added ") + resource.GetNameWithMod());
                    }
                }
                else if (resource.type == FrostyResourceType_Res)
                {
                    uint32_t size = resource.data.size;
                    LayoutManifest::FileInfo fileInfo = { resource.data.fbFile, static_cast<uint32_t>(resource.data.dataOffset), size };

                    BundleMerger::VanillaResEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaResEntry(resource.name);
                    if (originalEntry != nullptr)
                    {
                        auto it = originalEntry->bundleFileOffsets.find(bundleHash);
                        if (it == originalEntry->bundleFileOffsets.end())
                        {
                            deferredFileAdds.push_back({ LayoutManifest::Res, fileInfo });
                            PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[RES] Added ") + resource.GetNameWithMod());
                        }
                        else
                        {
                            manifest.SetFileInfo(bundleHash, it->second, fileInfo);
                            PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[RES] Modified ") + resource.GetNameWithMod());
                        }
                    }
                    else
                    {
                        deferredFileAdds.push_back({ LayoutManifest::Res, fileInfo });
                        PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[RES] Added ") + resource.GetNameWithMod());
                    }
                }
                else if (resource.type == FrostyResourceType_Chunk)
                {
                    Guid guid = Guid::FromString(resource.name);

                    uint32_t size = resource.data.size;
                    if (resource.data.rangeStart != 0)
                    {
                        size = resource.data.rangeEnd - resource.data.rangeStart;
                    }

                    LayoutManifest::FileInfo fileInfo = { resource.data.fbFile,
                        static_cast<uint32_t>(resource.data.dataOffset) + resource.data.rangeStart, size };

                    BundleMerger::VanillaChunkEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaChunkEntry(resource.name);
                    if (originalEntry != nullptr)
                    {
                        auto it = originalEntry->bundleFileOffsets.find(bundleHash);
                        if (it == originalEntry->bundleFileOffsets.end())
                        {
                            deferredFileAdds.push_back({ LayoutManifest::Chunk, fileInfo });
                            PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[CHK] Added ") + resource.GetNameWithMod());
                        }
                        else
                        {
                            manifest.SetFileInfo(bundleHash, it->second, fileInfo);
                            PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[CHK] Modified ") + resource.GetNameWithMod());
                        }
                    }
                    else
                    {
                        deferredFileAdds.push_back({ LayoutManifest::Chunk, fileInfo });
                        PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[CHK] Added ") + resource.GetNameWithMod());
                    }
                }
                continue;
            }

            // Process resources with no changes being added to this bundle
            if (resource.type == FrostyResourceType_Ebx)
            {
                // Duped assets with handlers need to rely on a source asset
                eastl::string sourceName =
                    !resource.dupedWithHandler ? resource.name : g_modLoader->m_dupedHandlerSources[resource.handlerHash];
                BundleMerger::VanillaEbxEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaEbxEntry(sourceName);
                int32_t originalSize = 0;
                if (!originalEntry)
                {
                    // Warn and default to 1mb
                    originalSize = 1000000;
                    KYBER_LOG(Warning,
                        "Failed to find vanilla bundle entry size for EBX asset " << resource.name.c_str() << ", defaulting to 1mb");
                }
                else
                {
                    originalSize = originalEntry->entry.originalSize;
                }

                deferredFileAdds.push_back({ LayoutManifest::Ebx, originalEntry->file });
                PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[EBX/No changes] Added ") + resource.GetNameWithMod());
            }
            else if (resource.type == FrostyResourceType_Res)
            {
                BundleMerger::VanillaResEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaResEntry(resource.name);
                int32_t originalSize = 0;
                if (!originalEntry)
                {
                    // Warn and default to 1mb
                    originalSize = 1000000;
                    KYBER_LOG(Warning,
                        "Failed to find vanilla bundle entry size for EBX asset " << resource.name.c_str() << ", defaulting to 1mb");
                }
                else
                {
                    originalSize = originalEntry->entry.originalSize;
                }

                deferredFileAdds.push_back({ LayoutManifest::Res, originalEntry->file });
                PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[RES/No changes] Added ") + resource.GetNameWithMod());
            }
            else if (resource.type == FrostyResourceType_Chunk)
            {
                LayoutManifest::FileInfo* file = nullptr;

                BundleMerger::VanillaChunkEntry* originalEntry = g_modLoader->m_bundleMerger.GetVanillaChunkEntry(resource.name);
                if (!originalEntry)
                {
                    continue;
                }

                file = &originalEntry->file;

                deferredFileAdds.push_back({ LayoutManifest::Chunk, *file });
                PUSH_MANIFEST_AUDIT(bundleHash, eastl::string("[CHK/No changes] Added ") + resource.GetNameWithMod());
            }
        }

        if (!deferredFileAdds.empty())
        {
            for (const auto& fileAdd : deferredFileAdds)
            {
                manifest.AddFileToBundle(bundleHash, fileAdd.file, fileAdd.type);
            }
        }

        if (bundleCount > 10 && i % stepSize == 0)
        {
            KYBER_LOG(Info, StringUtils::Format("[ModLoader] Processed %d/%d bundles", i, bundleCount));
        }

        ++i;
    }

    KYBER_LOG(Info, "[ModLoader] Modified layout manifest");

    s_layoutAuditLog = manifest.GetAuditLog();
}

ModLoader::ModLoader(FileSuperBundleManager* superBundleManager, ModData modData)
    : m_superBundleManager(superBundleManager)
    , m_liveEditManager(nullptr)
{
    g_modLoader = this;
    KYBER_LOG(Info, "[ModLoader] Initializing");

    KYBER_LOG(Info, "[ModLoader] Super bundle manager: " << std::hex << superBundleManager);

    m_manifestMerger.SetMerger(MergeLayoutManifest);

    m_bundleMerger.SetMerger(MergeBundleManifest);
    m_bundleMerger.LoadVanillaEntries();

    m_handlers[StringUtils::HashQuickLower("UITextDatabase")] = new LocalizationHandler();
    m_handlers[StringUtils::HashQuickLower("FsUITextDatabase")] = new LocalizationHandler();
    m_handlers[StringUtils::HashQuickLower("MeshVariationDatabase")] = new MeshVariationHandler();
    m_handlers[StringUtils::HashQuickLower("NetworkRegistryAsset")] = new NetworkRegistryHandler();
    m_handlers[StringUtils::HashQuickLower("ProfileOptionsAsset")] = new ProfileOptionsHandler();
    m_handlers[StringUtils::HashQuickLower("UIMetaDataAsset")] = new UIMetaDataHandler();
    m_handlers[StringUtils::HashQuickLower("WSTeamData")] = new WSTeamDataHandler();

    // These values don't matter, but smaller assets are better. They'll be cleared before use
    m_dupedHandlerSources[StringUtils::HashQuickLower("MeshVariationDatabase")] =
        "characters/dark/d_assault_newera/d_assault_newera_01/mpvur_d_assault_newera_01_bpb/meshvariationdb_win32";
    m_dupedHandlerSources[StringUtils::HashQuickLower("NetworkRegistryAsset")] =
        "gameplay/bundles/sp/buddy/sp_buddy_paldora/blueprintbundle_sp_buddy_paldora_networkregistry_win32";
    m_dupedHandlerSources[StringUtils::HashQuickLower("WSTeamData")] = "gameplay/teams/mp/team_neutral";

    MemoryUtils::Nop(HOOK_OFFSET(0x1402487AC), 11);

    void* backend = FB_STATIC_ARENA->alloc(0x98);
    Win32FileSystem_ctor(backend, StringUtils::CopyWithArena(modData.basePath.c_str()));

    void* vfs = ExecutionContext_getVirtualFileSystem();
    VirtualFileSystem_mount(vfs, backend, "/kyber_mods");

    KYBER_LOG(Info, "[ModLoader] Starting load of " << modData.modPaths.size() << " mods");

    RT_SetLogEnabled(ExecutionContext_getOptionValue("modLoaderDebugLogs", nullptr, nullptr) != nullptr);

    std::filesystem::path basePath = modData.basePath;
    for (const auto& modPath : modData.modPaths)
    {
        LoadMod((basePath / modPath).string().c_str(), ("/kyber_mods/" + modPath).c_str());
    }

    KYBER_LOG(Info, "[ModLoader] Loaded " << m_mods.size() << " mods");

    FinalizeModLoads();

    RegisterRenderListener(this);

    g_program->m_consoleRegistrationCallbacks.push_back([&]() { RegisterConsoleCommand(&LogLastEbxLoadCommand, "LogLastEbxLoad"); });

    // clang-format off
    HookTemplate hookOffsets[] = {
        //{ OFFSET_RUNTIMEDATABASEDOMAIN_CTOR, RuntimeDatabaseDomainCtorHk },
        { OFFSET_EBXPARTITIONREADER_PROCESS, EbxPartitionReaderProcessHk },
        { OFFSET_RUNTIMEDATABASEDOMAIN_READEBXPARTITIONFROMSTREAM, RuntimeDatabaseDomainReadEbxPartitionFromStreamHk },
        { OFFSET_RUNTIMEDATABASEDOMAIN_FINDPARTITIONFROMGUIDINCLUDINGIMPORTS, RuntimeDatabaseDomainFindPartitionFromGuidIncludingImportsHk },
        { OFFSET_RESOURCEMANAGER_BEGINCHUNKREAD, ResourceManagerBeginChunkReadHk },
        { OFFSET_RESOURCEMANAGER_BEGINCHUNKSCATTERREAD, ResourceManagerBeginChunkScatterReadHk },
        { OFFSET_RESOURCEMANAGER_ENDCHUNKREAD, ResourceManagerEndChunkReadHk },
        { OFFSET_RESOURCEMANAGER_ENDCHUNKREADEX, ResourceManagerEndChunkReadExHk },
        { OFFSET_RESOURCEMANAGER_POLLCHUNKOPERATION, ResourceManagerPollChunkOperationHk },
        { OFFSET_RESOURCEMANAGER_POLLCHUNKOPERATIONEX, ResourceManagerPollChunkOperationExHk },
        { OFFSET_RESOURCEMANAGER_COMPARTMENT_ONBEGINBUNDLE, ResourceManagerCompartmentOnBeginBundleHk },
        { OFFSET_RESOURCEMANAGER_LOOKUPDATACONTAINER, ResourceManagerLookupDataContainerHk },
        { HOOK_OFFSET(0x140223AF0), ResourceManagerCompartmentEndClearHk },
        { OFFSET_RESOURCEMANAGER_BEGINLOADDATA, ResourceManagerBeginLoadDataHk },
        { OFFSET_RESOURCEMANAGER_ENDLOADDATA, ResourceManagerEndLoadDataHk },
        { OFFSET_ENTITYBUSPEER_ONCREATEHELPER, EntityBusPeerOnCreateHelperHk },
        { HOOK_OFFSET(0x140220EF0), ResourceManagerStartUpdateThreadHk },
        { HOOK_OFFSET(0x140188E00), MainLoopInitResourceManagerHk },
        { HOOK_OFFSET(0x14022C230), ResourceManagerUpdateResourcesHk },
        { HOOK_OFFSET(0x140222830), ResourceManagerCompartmentResolveReferencesHk },
        { HOOK_OFFSET(0x14114D8E0), BundleManagerLoadBundleHk },
        { OFFSET_RUNTIMEDATABASEDOMAIN_FETCHNEWLYLOADEDPARTITIONS, RuntimeDatabaseDomainFetchNewlyLoadedPartitionsHk },
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }
    Hook::ApplyQueuedActions();
}

void ModLoader::LoadMod(const eastl::string& fileName, const eastl::string& relativeFileName)
{
    FILE* fp = fopen(fileName.c_str(), "rb");
    if (fp == nullptr)
    {
        KYBER_LOG(Error, "[ModLoader] Failed to read mod file: '" << fileName.c_str() << "': " << errno);
        return;
    }

    RTFrostyModT* mod;
    RTErrorT rtError = RT_FrostyLoadMod(fp, &mod);
    if (rtError != RT_SUCCESS)
    {
        KYBER_LOG(Error, "[ModLoader] Failed to load mod '" << fileName.c_str() << "': " << rtError);
        return;
    }

    int32_t fbFile = GetNextModFile();
    KyberMod kmod{ relativeFileName, fbFile };

    size_t resourceCount = RT_ArrayGetSize(mod->resources);
    for (int i = 0; i < resourceCount; ++i)
    {
        RTFrostyResourceT* resource = (RTFrostyResourceT*)RT_ArrayGetElement(mod->resources, i);
        int64_t offset = 0;
        int64_t dataSize = 0;

        if (resource->resourceIndex != -1)
        {
            offset = mod->dataOffset + (resource->resourceIndex * 16);

            fseek(mod->fp, offset, SEEK_SET);

            int64_t dataOffset = 0;
            RT_READ_FP(dataOffset, int64_t, mod->fp);
            RT_READ_FP(dataSize, int64_t, mod->fp);

            offset = mod->dataOffset + (mod->dataCount * 16) + dataOffset;
        }

        char* buffer = nullptr;
        size_t resourceSize = 0;

        if (resource->resourceIndex != -1 && resource->handlerHash != 0)
        {
            rtError = RT_FrostyReadModResource(mod, resource, &buffer, &resourceSize);
            if (rtError != RT_SUCCESS)
            {
                KYBER_LOG(Warning, "[ModLoader] Skipping Resource Name: " << resource->name << " Type: " << resource->type << " Error: " << rtError
                                                                  << " Handler: " << resource->handlerHash << " Offset: " << offset
                                                                  << " Size: " << resource->size);
                continue;
            }
        }

        size_t bundleCount = RT_ArrayGetSize(resource->addedBundles);

        eastl::vector<uint32_t> bundles;
        bundles.reserve(bundleCount);

        for (int i = 0; i < bundleCount; i++)
        {
            uintptr_t bundleHash = (uintptr_t)RT_ArrayGetElement(resource->addedBundles, i);
            bundles.push_back(bundleHash);
        }

        if (resource->type != FrostyResourceType_Bundle && resource->resourceIndex == -1 && bundles.empty())
        {
            KYBER_LOG(Trace, "[ModLoader] Skipping resource (2) Name: " << resource->name << " Type: " << resource->type << " (No data & No bundles)");
            continue;
        }

        ModResource modResource{};
        modResource.type = resource->type;
        modResource.name = resource->name;
        modResource.bundles = bundles;

        modResource.data.size = dataSize;
        modResource.data.originalSize = resource->size;
        modResource.data.buffer = buffer;
        modResource.data.fbFile = fbFile;

        modResource.handlerHash = resource->handlerHash;
        modResource.resourceIndex = resource->resourceIndex;
        modResource.dupedWithHandler =
            resource->handlerHash != 0 && !bundles.empty() && m_bundleMerger.GetVanillaEbxEntry(resource->name) == nullptr;

        modResource.modName = mod->details.title;
        modResource.modIndex = m_mods.size();

        // Res Data
        modResource.data.resType = resource->resType;
        modResource.data.resRid = resource->resRid;

        if (resource->type == FrostyResourceType_Res)
        {
            memcpy(modResource.data.resMeta, resource->resMeta, 0x10);
        }

        modResource.data.dataOffset = static_cast<uint32_t>(offset & 0xFFFFFFFF);

        // Chunk Data
        modResource.data.rangeStart = resource->rangeStart;
        modResource.data.rangeEnd = resource->rangeEnd;
        modResource.data.logicalOffset = resource->logicalOffset;
        modResource.data.logicalSize = resource->logicalSize;
        modResource.data.h32 = resource->h32;
        modResource.data.firstMip = resource->firstMip;

        modResource.uniqueIdWithType =
            StringUtils::HashQuickLower((std::to_string(modResource.type) + "_" + modResource.name.c_str()).c_str());

#ifdef BUNDLE_AUDITS
        {
            eastl::string log;
            log += "Loaded resource: ";
            log += modResource.name;
            log += " From: ";
            log += mod->details.title;
            log += " Type: ";
            log += std::to_string((uint32_t)modResource.type).c_str();
            log += " Handler: ";
            log += std::to_string(modResource.handlerHash).c_str();
            KYBER_LOG(Info, log.c_str());
        }
#endif

        kmod.resources.push_back(modResource);

        if (resource->type == FrostyResourceType_Bundle)
        {
            m_addedBundles.insert(StringUtils::HashQuickLower(resource->name));
        }
        else if (modResource.resourceIndex == -1)
        {
            if (resource->type == FrostyResourceType_Ebx)
            {
                const BundleMerger::VanillaEbxEntry* entry = m_bundleMerger.GetVanillaEbxEntry(modResource.name);
                if (entry == nullptr)
                {
                    continue;
                }

                m_requiredFiles.insert(entry->file.file);
            }
            else if (resource->type == FrostyResourceType_Res)
            {
                const BundleMerger::VanillaResEntry* entry = m_bundleMerger.GetVanillaResEntry(modResource.name);
                if (entry == nullptr)
                {
                    continue;
                }

                m_requiredFiles.insert(entry->file.file);
            }
            else if (resource->type == FrostyResourceType_Chunk)
            {
                const BundleMerger::VanillaChunkEntry* entry = m_bundleMerger.GetVanillaChunkEntry(modResource.name);
                if (entry == nullptr)
                {
                    continue;
                }

                m_requiredFiles.insert(entry->file.file);
            }
        }
    }

    eastl::stable_sort(
        kmod.resources.begin(), kmod.resources.end(), [](const ModResource& a, const ModResource& b) { return a.type < b.type; });

    m_mods.push_back(kmod);

    RT_FrostyDestroyMod(mod);
}

void ModLoader::FinalizeModLoads()
{
    KYBER_LOG(Debug, "[ModLoader] Finalizing mod resources");
    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 1");

    m_modResources.clear();

    m_modResources.reserve(m_mods.size());
    for (int i = m_mods.size() - 1; i >= 0; --i)
    {
        for (const auto& resource : m_mods[i].resources)
        {
            m_modResources.push_back(resource);
        }
    }

    eastl::stable_sort(
        m_modResources.begin(), m_modResources.end(), [](const ModResource& a, const ModResource& b) { return a.type < b.type; });

    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 2");

    eastl::unordered_map<uint32_t, ModResourceData> sources;

    for (auto& resource : m_modResources)
    {
        if (resource.handlerHash != 0 || resource.resourceIndex == -1)
        {
            continue;
        }

        if (sources.find(resource.uniqueIdWithType) != sources.end())
        {
            continue;
        }

        sources[resource.uniqueIdWithType] = resource.data;
    }

    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 3");

    for (auto& resource : m_modResources)
    {
        if (resource.handlerHash != 0 || resource.resourceIndex != -1)
        {
            continue;
        }

        if (!sources.count(resource.uniqueIdWithType))
        {
            continue;
        }

        resource.resourceIndex = 0;
        resource.data = sources[resource.uniqueIdWithType];
    }

    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 4");

    eastl::set<uint32_t> visited;
    for (const auto& resource : m_modResources)
    {
        if (resource.type == FrostyResourceType_Ebx && resource.data.buffer != nullptr && resource.handlerHash != 0 &&
            !visited.count(resource.uniqueIdWithType))
        {
            m_handlerResources[resource.name] = { resource.handlerHash, resource.dupedWithHandler };
            visited.insert(resource.uniqueIdWithType);
        }
    }

    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 5");

    eastl::map<uint32_t, eastl::set<uint32_t>> visitedNamesSecondPass;
    eastl::map<uint32_t, uint32_t> bundleResourceCounts;
    for (const auto& resource : m_modResources)
    {
        if (resource.handlerHash != 0 && !resource.dupedWithHandler)
        {
            continue;
        }

        for (const auto& bundleHash : resource.bundles)
        {
            eastl::set<uint32_t>& visitedBundleNames = visitedNamesSecondPass[bundleHash];
            if (visitedBundleNames.count(resource.uniqueIdWithType))
            {
                continue;
            }

            ++bundleResourceCounts[bundleHash];
            visitedBundleNames.insert(resource.uniqueIdWithType);
        }
    }

    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 6");

    for (const auto& entry : bundleResourceCounts)
    {
        m_bundleResources[entry.first].reserve(entry.second);
    }

    KYBER_LOG(Debug, "[ModLoader] Finalizing: Stage 7");

    eastl::map<uint32_t, const ModResource*> globalOverrides;

    eastl::map<uint32_t, eastl::set<uint32_t>> visitedNames;
    for (const auto& resource : m_modResources)
    {
        if (resource.handlerHash != 0 && !resource.dupedWithHandler)
        {
            continue;
        }

        const ModResource* assignableResource = &resource;

        if (resource.bundles.empty())
        {
            globalOverrides[resource.uniqueIdWithType] = assignableResource;
        }
        else
        {
            auto it = globalOverrides.find(assignableResource->uniqueIdWithType);
            if (it != globalOverrides.end())
            {
                assignableResource = it->second;
            }
        }

        for (const auto& bundleHash : resource.bundles)
        {
            eastl::set<uint32_t>& visitedBundleNames = visitedNames[bundleHash];
            if (visitedBundleNames.count(resource.uniqueIdWithType))
            {
                continue;
            }

            visitedBundleNames.insert(resource.uniqueIdWithType);
            m_bundleResources[bundleHash].push_back(*assignableResource);
        }
    }

    KYBER_LOG(Info, "[ModLoader] Finalized mod resources");
}

#pragma runtime_checks("s", off)
void ModLoader::LoadFile(uint64_t file, const char* fileName)
{
    SuperBundleEntry* entry = nullptr;
    CasFileMap_addEntry(reinterpret_cast<void*>(reinterpret_cast<__int64>(m_superBundleManager->casFiles) + 0x80), entry, 0, &file);
    if (entry == nullptr)
    {
        KYBER_LOG(Error, "Failed to load file: " << fileName);
        return;
    }

    entry->buffer = nullptr;
    entry->name = StringUtils::CopyWithArena(fileName);
}
#pragma runtime_checks("s", restore)

// This function limits the number of possible mods to 247. It should be possible
// to increase this, if necessary, by incrementing catalogIndex. initialexperience
// has 10 files, hence the 10 + m_mods.size() in the casIndex calculation. If a
// different catalog has more than 10 files, they will need to be accounted for
int32_t ModLoader::GetNextModFile() const
{
    int catalogIndex = 0; // initialexperience
    bool inPatch = false;
    int casIndex = 10 + m_mods.size();
    return ((catalogIndex + 1) << 12) | (inPatch ? 0x100 : 0x00) | ((casIndex - 1) & 0xFF);
}

bool ModLoader::IsBundleLoaded(const std::string& bundleName) const
{
    for (const auto& [key, compartment] : debugCompartments)
    {
        for (const auto& bundle : compartment.m_bundles)
        {
            if (bundle.name == bundleName)
            {
                return bundle.loaded;
            }
        }
    }

    return false;
}

bool ModLoader::IsBundleLoading(const std::string& bundleName) const
{
    for (const auto& [key, compartment] : debugCompartments)
    {
        for (const auto& bundle : compartment.m_bundles)
        {
            if (bundle.name == bundleName)
            {
                return true;
            }
        }
    }

    return false;
}

bool ModLoader::AnyBundlesLoading() const
{
    for (const auto& [key, compartment] : debugCompartments)
    {
        for (const auto& bundle : compartment.m_bundles)
        {
            if (!bundle.loaded)
            {
                return true;
            }
        }
    }

    return false;
}
} // namespace Kyber
