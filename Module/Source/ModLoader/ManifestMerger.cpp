// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Base/Pch.h>

#include <Core/Program.h>
#include <ModLoader/ManifestMerger.h>
#include <ModLoader/BundleMerger.h>

#include <ByteBuffer/ByteBuffer.hpp>

#include <string>
#include <util.h>

#include <cstring>

#include <EASTL/sort.h>

namespace Kyber
{
ManifestMerger* g_manifestMerger;

#pragma pack(push, 1)
struct NativeBundleInfo
{
    uint32_t hash;
    int32_t startIndex;
    int32_t count;
    int32_t unk1;
    int32_t unk2;
};

struct NativeChunkInfo
{
    Guid guid;
    int32_t fileIndex;
};

struct NativeLayoutManifest
{
    int32_t fileCount;
    int32_t bundleCount;
    int32_t chunksCount;
    LayoutManifest::FileInfo fileInfo[1097786];
    NativeBundleInfo bundleInfo[4777];
    NativeChunkInfo chunkInfo[180913];
};
#pragma pack(pop)

void LayoutManifest::Load(uint8_t* data, uint32_t size)
{
    NativeLayoutManifest* native = reinterpret_cast<NativeLayoutManifest*>(data);

    uint32_t fileCount = native->fileCount;
    uint32_t bundleCount = native->bundleCount;
    uint32_t chunksCount = native->chunksCount;

    m_fileInfo.reserve(fileCount);
    for (int i = 0; i < fileCount; i++)
    {
        m_fileInfo.push_back(native->fileInfo[i]);
    }

    for (int i = 0; i < bundleCount; i++)
    {
        NativeBundleInfo& nativeBundle = native->bundleInfo[i];

        BundleInfo info;
        info.hash = nativeBundle.hash;

        int32_t startIndex = nativeBundle.startIndex;
        int32_t count = nativeBundle.count;

        auto& vanillaBundleEntry = g_bundleMerger->GetBundleEntries()[info.hash];
        info.files.reserve(vanillaBundleEntry.files.size());

        for (const auto& file : vanillaBundleEntry.files)
        {
            info.files.push_back(file);
        }

        info.unk1 = 0;
        info.unk2 = 0;
        m_bundleInfo[info.hash] = info;
    }

    for (int i = 0; i < chunksCount; i++)
    {
        NativeChunkInfo& nativeChunk = native->chunkInfo[i];

        ChunkInfo info;
        info.guid = nativeChunk.guid;
        info.fileIndex = nativeChunk.fileIndex;
        info.file = m_fileInfo[info.fileIndex];

        m_chunkGuids[info.guid] = info;
    }

    KYBER_LOG(Info, "[ModLoader] Loaded layout manifest " << fileCount << " " << bundleCount << " " << chunksCount);
}

int GetCatalogIndex(int value)
{
    return (value >> 12) - 1;
}

std::vector<uint8_t> LayoutManifest::Save()
{
    bb::ByteBuffer buf;

    eastl::unordered_set<eastl::string> processedFiles;
    eastl::vector<FileInfo> files;

    uint32_t totalFileCount = m_chunkGuids.size();
    for (const auto& bundleInfo : m_bundleInfo)
    {
        totalFileCount += bundleInfo.second.files.size();
    }

    files.reserve(totalFileCount);

    eastl::vector<ChunkInfo> chunkInfo;
    chunkInfo.reserve(m_chunkGuids.size());

    for (const auto& info : m_chunkGuids)
    {
        chunkInfo.push_back(info.second);
    }

    eastl::map<int32_t, uint32_t> fileIndices;
    for (const auto& bundleInfo : m_bundleInfo)
    {
        fileIndices[bundleInfo.first] = files.size();
        for (const auto& fileInfo : bundleInfo.second.files)
        {
            files.push_back(fileInfo);
        }
    }

    for (auto& chunkInfo : chunkInfo)
    {
        files.push_back(chunkInfo.file);
        chunkInfo.fileIndex = files.size() - 1;
    }

    buf.putInt(files.size());
    buf.putInt(m_bundleInfo.size());
    buf.putInt(chunkInfo.size());

    for (const auto& info : files)
    {
        buf.putInt(info.file);
        buf.putInt(info.offset);
        buf.putLong(info.size);
    }

    for (const auto& info : m_bundleInfo)
    {
        buf.putInt(info.first);

        if (!fileIndices.count(info.first))
        {
            KYBER_LOG(Error, "Failed to find file " << info.second.files[0].ToString() << " while building layout manifest");
            continue;
        }

        buf.putInt(fileIndices[info.first]);
        buf.putInt(info.second.files.size());
        buf.putInt(0);
        buf.putInt(0);
    }

    for (auto& info : chunkInfo)
    {
        uint8_t guidBuf[16];
        info.guid.ToFrostyLE(guidBuf);
        buf.putBytes(guidBuf, 16);

        buf.putInt(info.fileIndex);
    }

    return buf.getBuf();
}

void LayoutManifest::AddFileToBundle(uint32_t bundleHash, FileInfo fileInfo, AssetType assetType)
{
    auto it = m_bundleInfo.find(bundleHash);
    if (it == m_bundleInfo.end())
    {
        return;
    }

    BundleInfo& bundleInfo = it->second;
    if (bundleInfo.hash != bundleHash)
    {
        KYBER_LOG(Error, "Hash discrepancy with bundle " << bundleInfo.hash << ", should be " << bundleHash);
        return;
    }

    bool customBundle = g_modLoader->m_addedBundles.count(bundleHash);

    auto& vanillaBundleEntry = g_bundleMerger->GetBundleEntries()[bundleInfo.hash];
    if (!customBundle && vanillaBundleEntry.hash != bundleInfo.hash)
    {
        KYBER_LOG(Error, "Hash discrepancy with vanilla bundle " << vanillaBundleEntry.hash << ", should be " << bundleInfo.hash);
        return;
    }

    if (!customBundle)
    {
        if (vanillaBundleEntry.ebxCount > 200'000)
        {
            KYBER_LOG(Error, "Vanilla bundle " << bundleInfo.hash << " has too many EBX entries: " << vanillaBundleEntry.ebxCount);
            return;
        }

        if (vanillaBundleEntry.resCount > 2'000'000)
        {
            KYBER_LOG(Error, "Vanilla bundle " << bundleInfo.hash << " has too many RES entries: " << vanillaBundleEntry.resCount);
            return;
        }

        if (vanillaBundleEntry.chunkCount > 2'000'000)
        {
            KYBER_LOG(Error, "Vanilla bundle " << bundleInfo.hash << " has too many chunk entries: " << vanillaBundleEntry.chunkCount);
            return;
        }
    }

    auto offset = bundleInfo.files.begin() + 1;
    offset += vanillaBundleEntry.ebxCount;
    if (assetType == Ebx)
    {
        vanillaBundleEntry.ebxCount++;
    }
    else if (assetType == Res)
    {
        offset += vanillaBundleEntry.resCount++;
    }
    else if (assetType == Chunk)
    {
        offset += vanillaBundleEntry.resCount;
        offset += vanillaBundleEntry.chunkCount++;
    }

    bundleInfo.files.insert(offset, fileInfo);
}

void LayoutManifest::SetFileInfo(uint32_t bundleHash, int index, FileInfo fileInfo)
{
    auto it = m_bundleInfo.find(bundleHash);
    if (it == m_bundleInfo.end())
    {
        return;
    }

    it->second.files[index] = fileInfo;
}

LayoutManifest::FileInfo* LayoutManifest::GetChunk(const Guid& guid)
{
    if (!m_chunkGuids.count(guid))
    {
        return nullptr;
    }

    return &m_chunkGuids[guid].file;
}

void LayoutManifest::AddChunk(const Guid& guid, FileInfo fileInfo)
{
    m_chunkGuids[guid] = { guid, 0, fileInfo };
}

void LayoutManifest::AddBundle(uint32_t hash)
{
    if (m_bundleInfo.count(hash))
    {
        return;
    }

    BundleInfo info;
    info.hash = hash;
    info.files.push_back(m_bundleInfo.begin()->second.files[0]);
    info.unk1 = 0;
    info.unk2 = 0;
    m_bundleInfo[hash] = info;
}

void LayoutManifest::PushAudit(uint32_t bundleHash, const eastl::string& log)
{
    m_auditLog[bundleHash].push_back(log);
}

void LayoutManifest::PrintAudit(uint32_t bundleHash)
{
    if (m_auditLog[bundleHash].empty())
    {
        return;
    }

    KYBER_LOG(Info, "[ModLoader] --- BEGIN LAYOUT BUNDLE AUDIT LOG - " + std::to_string(bundleHash) + " ---");
    for (const auto& entry : m_auditLog[bundleHash])
    {
        KYBER_LOG(Info, "[ModLoader] " << entry.c_str());
    }
    KYBER_LOG(Info, "[ModLoader] --- END LAYOUT BUNDLE AUDIT LOG ---");
}

void ProcessManifestHk(CasFileMap* fileMap, uint8_t* manifestBuf)
{
    static auto trampoline = HookManager::Call(ProcessManifestHk);
    if (!g_manifestMerger->HasMerger())
    {
        trampoline(fileMap, manifestBuf);
        return;
    }

    uint8_t** data = reinterpret_cast<uint8_t**>(manifestBuf + 0x28);
    uint32_t* size = reinterpret_cast<uint32_t*>(manifestBuf + 0x30);

    KYBER_LOG(Info, "[ModLoader] Loading layout manifest size " << size);

    LayoutManifest* manifest = new LayoutManifest();
    manifest->Load(*data, *size);
    g_manifestMerger->Merge(*manifest);
    std::vector<uint8_t> modified = manifest->Save();
    
    // Don't delete the manifest. I'm not sure why, but it causes
    // everything to crash and burn.

    uint8_t* modifiedBuffer = (uint8_t*)FB_STATIC_ARENA->alloc(modified.size());
    memcpy(modifiedBuffer, modified.data(), modified.size());

    uint8_t* originalData = *data;
    uint32_t originalSize = *size;

    *data = modifiedBuffer;
    *size = modified.size();

    trampoline(fileMap, manifestBuf);

    *data = originalData;
    *size = originalSize;

    KYBER_LOG(Info, "[ModLoader] Loaded modified layout manifest size " << modified.size());
}

void LoadCatEntriesHk(CasFileMap* fileMap, __int64 a2)
{
    static auto trampoline = HookManager::Call(LoadCatEntriesHk);
    for (const auto& file : g_modLoader->GetRequiredFiles())
    {
        int32_t catalogIndex = (file >> 12) - 1;
        bool isInPatch = (file & 0x100) != 0;
        int32_t casIndex = (file & 0xFF) + 1;

        std::ostringstream filePath;
        filePath << "/native_data/" << (isInPatch ? "Patch/" : "Data/");
        filePath << g_modLoader->m_bundleMerger.GetCatalog(catalogIndex).c_str() << "/cas_";
        filePath << std::setw(2) << std::setfill('0') << casIndex << ".cas";

        g_modLoader->LoadFile(file, filePath.str().c_str());
    }

    for (const auto& mod : g_modLoader->m_mods)
    {
        g_modLoader->LoadFile(mod.fbFile, mod.path.c_str());
    }

    trampoline(fileMap, a2);
}

ManifestMerger::ManifestMerger()
    : m_merger(nullptr)
    , m_lastManifest(nullptr)
{
    g_manifestMerger = this;

    // clang-format off
    HookTemplate hookOffsets[] = {
        { HOOK_OFFSET(0x1454DB6D0), ProcessManifestHk },
        { HOOK_OFFSET(0x1402491B0), LoadCatEntriesHk }
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }
    Hook::ApplyQueuedActions();
}

void ManifestMerger::SetMerger(ManifestMergeFunc func)
{
    m_merger = func;
}

void ManifestMerger::Merge(LayoutManifest& manifest)
{
    m_merger(manifest);
    m_lastManifest = &manifest;
}
} // namespace Kyber