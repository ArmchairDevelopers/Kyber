// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Core/DebugHooks.h>
#include <SDK/TypeInfo.h>
#include <SDK/Types.h>
#include <Network/SocketManager.h>
#include <ModLoader/CustomAssetHandler.h>
#include <ModLoader/BundleMerger.h>
#include <ModLoader/ManifestMerger.h>
#include <ModLoader/LiveEditManager.h>
#include <ModLoader/ResourceMerger.h>
#include <RPC/API/ServerBrowser.h>

#include <frosty_mod.h>

#include <EASTL/hash_map.h>

#include <string>
#include <set>

namespace eastl
{
// Helper definition so hash_map just works with the defaults
template<>
struct hash<Kyber::Guid>
{
    size_t operator()(const Kyber::Guid& s) const
    {
        return size_t(s.data1 + s.data2 + s.data3);
    }
};
} // namespace eastl

namespace Kyber
{
struct PendingChunk
{
    __int64 handle;
    const void* src;
    uint32_t srcSize;
    const void* dst;
    uint32_t dstSize;
    uint32_t dstOffset;
};

struct ModifiedChunk
{
    Guid guid;
    const void* data;
    uint32_t size;
};

struct ContainerCreationInfo
{
    void* runtimeDatabaseDomain;
    uint32_t compartment;
    DataContainer* container;
    eastl::string name;
    bool referencesResolved;
    bool dupedWithHandler;
};

struct SuperBundleEntry
{
    uint64_t file;
    void* buffer;
    const char* name;
};

class CasFileMap
{
public:
    char pad_0000[128]; // 0x0000
    void* map2;         // 0x0080
    void* map;          // 0x0088
};                      // Size: 0x0090

TL_DECLARE_FUNC(0x1454D8360, void, CasFileMap_addEntry, void* map, SuperBundleEntry*& entry, __int64 a3, uint64_t* file);

class FileSuperBundleManager
{
public:
    char pad_0000[448];   // 0x0000
    CasFileMap* casFiles; // 0x01C0
    char pad_01C8[704];   // 0x01C8
};                        // Size: 0x0488

struct ModData
{
    std::string basePath;
    std::vector<std::string> modPaths;
    std::vector<kyber_common::ServerMod> serverMods;
    std::vector<kyber_common::ServerMod> explodedMods;
};

class ModLoader : RenderListener
{
public:
    ModLoader(FileSuperBundleManager* superBundleManager, ModData modData);

    void LoadMod(const eastl::string& fileName, const eastl::string& relativeFileName);
    void Render() override;

    void LoadFile(uint64_t file, const char* fileName);

    int32_t GetNextModFile() const;

    bool IsBundleLoaded(const std::string& bundleName) const;
    bool IsBundleLoading(const std::string& bundleName) const;
    bool AnyBundlesLoading() const;

    FileSuperBundleManager* m_superBundleManager;

    eastl::vector<KyberMod> m_mods;
    eastl::unordered_map<eastl::string, ModResource> m_dupedWithHandlerResources;

    bool m_secretModEnabled = false;

    BundleMerger m_bundleMerger;
    ManifestMerger m_manifestMerger;
    ResourceMerger m_resourceMerger;

    LiveEditManager* m_liveEditManager;

    eastl::unordered_map<uint32_t, CustomAssetHandler*> m_handlers;
    eastl::unordered_map<uint32_t, eastl::string> m_dupedHandlerSources;

    std::vector<ContainerCreationInfo> m_deferredContainerCreationQueue;

    std::set<uint32_t> m_addedBundles;
    std::set<int32_t> m_requiredFiles;

    eastl::vector<ModResource> m_modResources;
    eastl::unordered_map<eastl::string, KyberHandledModResource> m_handlerResources;

    eastl::unordered_map<void*, std::map<Guid, DatabasePartition*>> m_domainLoadedPartitions;
    eastl::map<uint32_t, std::vector<ModResource>> m_bundleResources;

    eastl::map<ResourceCompartment, uint32_t> m_compartmentToBundleId;

    const std::set<int32_t>& GetRequiredFiles() const
    {
        return m_requiredFiles;
    }

    static void ReadChunkSync(const Guid& guid, const void* dstBuffer, uint32_t size);
    static void ModifyChunk(const Guid& guid, const void* data, uint32_t size);

private:
    void FinalizeModLoads();
};

extern ModLoader* g_modLoader;
} // namespace Kyber
