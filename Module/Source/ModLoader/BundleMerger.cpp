// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Base/Pch.h>

#include <ModLoader/BundleMerger.h>

#include <ByteBuffer/ByteBuffer.hpp>

#include <EASTL/map.h>

#include <memory>
#include <util.h>

#include <cstring>

namespace Kyber
{
BundleMerger* g_bundleMerger;

static uint32_t _SwapEndiannessU32(uint32_t val)
{
    return ((val >> 24) & 0xff) | ((val << 8) & 0xff0000) | ((val >> 8) & 0xff00) | ((val << 24) & 0xff000000);
}

static uint64_t _SwapEndiannessU64(uint64_t x)
{
    x = (x & 0x00000000FFFFFFFF) << 32 | (x & 0xFFFFFFFF00000000) >> 32;
    x = (x & 0x0000FFFF0000FFFF) << 16 | (x & 0xFFFF0000FFFF0000) >> 16;
    x = (x & 0x00FF00FF00FF00FF) << 8 | (x & 0xFF00FF00FF00FF00) >> 8;
    return x;
}

void BundleManifest::Load(uint8_t* data, uint32_t size)
{
    bb::ByteBuffer buf(data, size);

    uint32_t magic = _SwapEndiannessU32(buf.readUnsafe<uint32_t>()) ^ 0x7065636D;
    if (magic != 0xED1CEDB8)
    {
        KYBER_LOG(Error, "Failed to load bundle manifest: invalid magic value 0x" << std::hex << magic);
        return;
    }

    m_totalCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    m_ebxCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    m_resCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    m_chunkCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    m_stringsOffset = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    m_metaOffset = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    m_metaSize = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());

    for (int i = 0; i < m_totalCount; i++)
    {
        // Simulate reading Sha1
        buf.setReadPos(buf.getReadPos() + 20);
    }

    for (int i = 0; i < m_ebxCount; i++)
    {
        uint32_t nameOffset = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        uint32_t originalSize = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());

        uint32_t currentPos = buf.getReadPos();
        buf.setReadPos(m_stringsOffset + nameOffset);

        std::string name = buf.getNullTerminatedString();
        m_ebxEntries.push_back({ name, originalSize });

        buf.setReadPos(currentPos);

        // KYBER_LOG(Info, "Loaded manifest ebx entry " << name << " (" << m_stringsOffset << ", " << nameOffset << ")");
    }

    for (int i = 0; i < m_resCount; i++)
    {
        uint32_t nameOffset = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        uint32_t originalSize = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());

        uint32_t currentPos = buf.getReadPos();
        buf.setReadPos(m_stringsOffset + nameOffset);

        std::string name = buf.getNullTerminatedString();
        m_resEntries.push_back({ name, originalSize });

        buf.setReadPos(currentPos);

        // KYBER_LOG(Info, "Loaded manifest res entry " << name << " (" << m_stringsOffset << ", " << nameOffset << ")");
    }

    for (auto& entry : m_resEntries)
    {
        entry.resType = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    }

    for (auto& entry : m_resEntries)
    {
        buf.getBytes(entry.resMeta, 0x10);
    }

    for (auto& entry : m_resEntries)
    {
        entry.resRid = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
    }

    for (int i = 0; i < m_chunkCount; i++)
    {
        Guid guid = Guid::FromFrostyBE(buf);
        uint32_t logicalOffset = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        uint32_t logicalSize = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        m_chunkEntries.push_back({ guid, logicalOffset, logicalSize });
    }

    if (m_metaSize > 0)
    {
        buf.setReadPos(m_metaOffset);

        std::vector<uint8_t> metaData(m_metaSize);
        buf.getBytes(metaData.data(), m_metaSize);

        KYBER_LOG(Trace, "Chunk meta size: " << m_metaSize);
        bb::ByteBuffer buf(metaData.data(), m_metaSize);

        std::string name;
        m_meta = DbObject::Load(buf, name);
        //KYBER_LOG(Trace, "Object '" << name << "': " << m_meta->ToString() << " (Out of " << m_chunkCount << " chunks)");
    }

    KYBER_LOG(Debug, "Loaded manifest " << m_ebxCount << " " << m_chunkCount << " " << m_metaSize << " " << m_metaOffset);
}

std::vector<uint8_t> BundleManifest::Save()
{
    bb::ByteBuffer buf;
    buf.putInt(_SwapEndiannessU32(0x9D798ED5));

    uint32_t totalCount = m_ebxEntries.size() + m_resEntries.size() + m_chunkEntries.size();

    buf.putInt(_SwapEndiannessU32(totalCount));
    buf.putInt(_SwapEndiannessU32(m_ebxEntries.size()));
    buf.putInt(_SwapEndiannessU32(m_resEntries.size()));
    buf.putInt(_SwapEndiannessU32(m_chunkEntries.size()));

    uint32_t offsetsPos = buf.getWritePos();
    buf.putInt(_SwapEndiannessU32(0)); // stringsOffset
    buf.putInt(_SwapEndiannessU32(0)); // metaOffset
    buf.putInt(_SwapEndiannessU32(0)); // metaSize

    for (int i = 0; i < totalCount; i++)
    {
        // Simulate writing Sha1
        buf.setWritePos(buf.getWritePos() + 20);
    }

    uint32_t nameOffset = 0;
    eastl::map<uint32_t, uint32_t> stringOffsets;
    eastl::vector<eastl::string> strings;

    for (const auto& entry : m_ebxEntries)
    {
        uint32_t hash = StringUtils::HashQuick(entry.name.c_str());
        if (!stringOffsets.count(hash))
        {
            strings.push_back(entry.name.c_str());
            stringOffsets[hash] = nameOffset;
            nameOffset += entry.name.size() + 1;
        }

        buf.putInt(_SwapEndiannessU32(stringOffsets[hash]));
        buf.putInt(_SwapEndiannessU32(entry.originalSize));
    }

    for (const auto& entry : m_resEntries)
    {
        uint32_t hash = StringUtils::HashQuick(entry.name.c_str());
        if (!stringOffsets.count(hash))
        {
            strings.push_back(entry.name.c_str());
            stringOffsets[hash] = nameOffset;
            nameOffset += entry.name.size() + 1;
        }

        buf.putInt(_SwapEndiannessU32(stringOffsets[hash]));
        buf.putInt(_SwapEndiannessU32(entry.originalSize));
    }

    for (const auto& entry : m_resEntries)
    {
        buf.putInt(_SwapEndiannessU32(entry.resType));
    }

    for (auto& entry : m_resEntries)
    {
        buf.putBytes(entry.resMeta, 0x10);
    }

    for (const auto& entry : m_resEntries)
    {
        buf.putLong(_SwapEndiannessU64(entry.resRid));
    }

    for (const auto& entry : m_chunkEntries)
    {
        uint8_t guidBuf[16];
        entry.guid.ToFrostyBE(guidBuf);
        buf.putBytes(guidBuf, 16);

        buf.putInt(_SwapEndiannessU32(entry.logicalOffset));
        buf.putInt(_SwapEndiannessU32(entry.logicalSize));
    }

    uint32_t metaOffset = 0;
    uint32_t metaSize = 0;

    if (m_meta)
    {
        std::vector<uint8_t> data = m_meta->Save("chunkMeta");
        metaOffset = buf.getWritePos();
        metaSize = data.size();
        buf.putBytes(data.data(), metaSize);
    }

    uint32_t stringsOffset = buf.getWritePos();
    for (const auto& str : strings)
    {
        buf.putNullTerminatedString(str.c_str());
    }

    while (buf.getWritePos() % 16 != 0)
    {
        buf.putChar(0x00);
    }

    buf.setWritePos(offsetsPos);
    buf.putInt(_SwapEndiannessU32(stringsOffset));
    buf.putInt(_SwapEndiannessU32(metaOffset));
    buf.putInt(_SwapEndiannessU32(metaSize));

    return buf.getBuf();
}

void BundleManifest::Clear()
{
    m_ebxEntries.clear();
    m_resEntries.clear();
    m_chunkEntries.clear();
    m_meta = std::make_shared<DbObject>(DbList());
}

void BundleManifest::ModifyEbxEntry(const eastl::string& name, uint32_t originalSize)
{
    int i = 1;
    for (auto& entry : m_ebxEntries)
    {
        if (entry.name != name.c_str())
        {
            ++i;
            continue;
        }

        // m_auditLog.push_back("[EBX] " + entry.name + " originalSize changed from " + std::to_string(entry.originalSize) + " to " +
        //                      std::to_string(originalSize) + "(idx: " + std::to_string(i++) + ")");
        entry.originalSize = originalSize;
        return;
    }

    // m_auditLog.push_back("[EBX] Failed to modify " + name);
}

void BundleManifest::ModifyResEntry(const ResEntry& entry)
{
    for (auto& e : m_resEntries)
    {
        if (e.name != entry.name)
        {
            continue;
        }

        // memcpy(&e, &entry, sizeof(entry));
        e = entry;
        // m_auditLog.push_back("[RES] " + entry.name + " originalSize changed to " + std::to_string(entry.originalSize));
        break;
    }
}

BundleManifest::Result BundleManifest::AddEbxEntry(eastl::string name, uint32_t originalSize, bool allowModify)
{
    if (allowModify)
    {
        for (auto& entry : m_ebxEntries)
        {
            if (entry.name != name.c_str())
            {
                continue;
            }

            entry.originalSize = originalSize;
            // m_auditLog.push_back("[EBX] " + entry.name + " originalSize changed to " + std::to_string(originalSize));
            return Rt_Modified;
        }
    }

    m_ebxEntries.push_back({ name.c_str(), originalSize });
    // m_auditLog.push_back("[EBX] Added " + name + ", originalSize " + std::to_string(originalSize));
    return Rt_Added;
}

BundleManifest::Result BundleManifest::AddResEntry(ResEntry entry, bool allowModify)
{
    if (allowModify)
    {
        for (auto& e : m_resEntries)
        {
            if (e.resRid != entry.resRid)
            {
                continue;
            }

            // m_auditLog.push_back("[RES] Modified " + entry.name + " (oName: " + e.name + ", rid: " + std::to_string(entry.resRid) +
            //                      ", oRid: " + std::to_string(e.resRid) + ") originalSize " + std::to_string(e.originalSize) + "->" +
            //                      std::to_string(entry.originalSize));
            e = entry;
            return Rt_Modified;
        }
    }

    m_resEntries.push_back(entry);
    // m_auditLog.push_back("[RES] Added " + entry.name + ", originalSize " + std::to_string(entry.originalSize));
    return Rt_Added;
}

BundleManifest::Result BundleManifest::AddChunkEntry(ChunkEntry entry, int32_t h32, int32_t firstMip, bool allowNew, bool allowModify)
{
    int existingIndex = -1;
    if (allowModify)
    {
        int i = 0;
        for (auto& e : m_chunkEntries)
        {
            if (!e.guid.Equals(entry.guid))
            {
                i++;
                continue;
            }

            existingIndex = i;
            break;
        }
    }

    if (!allowNew && existingIndex == -1)
    {
        return Rt_Nop;
    }

    if (existingIndex != -1)
    {
        m_chunkEntries[existingIndex] = entry;
        // m_auditLog.push_back(
        //     "[CHK] " + entry.guid.ToString() + " modified at index " + std::to_string(existingIndex) + ", h32 " + std::to_string(h32));
    }
    else
    {
        m_chunkEntries.push_back(entry);
        // m_auditLog.push_back("[CHK] " + entry.guid.ToString() + " added, h32 " + std::to_string(h32));
    }

    if (h32 != 0)
    {
        if (!m_meta)
        {
            // m_auditLog.push_back("[CHK] " + entry.guid.ToString() + " warning, bundle has no meta");
            m_meta = std::make_shared<DbObject>(DbList());
            // return true;
        }

        auto mapObj = std::make_shared<DbObject>(DbMap());
        DbMap& map = *mapObj->Get<DbMap>();
        map["h32"] = std::make_shared<DbObject>(static_cast<uint32_t>(h32));

        auto metaObj = std::make_shared<DbObject>(DbMap());
        if (firstMip != -1)
        {
            DbMap& meta = *metaObj->Get<DbMap>();
            meta["firstMip"] = std::make_shared<DbObject>(static_cast<uint32_t>(firstMip));
        }

        map["meta"] = metaObj;

        DbList& list = *m_meta->Get<DbList>();
        if (existingIndex != -1)
        {
            int32_t metaIndex = GetMetaIndex(h32);
            if (metaIndex != -1)
            {
                list[metaIndex] = mapObj;
            }
            else
            {
                PushAudit("No existing meta index for H32 " + eastl::string(std::to_string(h32).c_str()));
            }
        }
        else
        {
            list.push_back(mapObj);
        }
    }

    return existingIndex != -1 ? Rt_Modified : Rt_Added;
}

int32_t BundleManifest::GetMetaIndex(int32_t h32) const
{
    if (!m_meta)
    {
        return -1;
    }

    DbList& list = *m_meta->Get<DbList>();
    for (int i = 0; i < list.size(); ++i)
    {
        DbMap& map = *list[i]->Get<DbMap>();
        if (*map["h32"]->Get<uint32_t>() != h32)
        {
            continue;
        }

        return i;
    }

    return -1;
}

void BundleManifest::PushAudit(const eastl::string& log)
{
    m_auditLog.push_back(log);
}

char BundleManifestLoadHk(void* inst, uint8_t* buffer, uint64_t manifestSize, int magicSalt)
{
    static auto trampoline = HookManager::Call(BundleManifestLoadHk);
    if (!g_bundleMerger->HasMerger())
    {
        return trampoline(inst, buffer, manifestSize, magicSalt);
    }

    KYBER_LOG(Debug, "Loading bundle manifest size " << manifestSize);

    BundleManifest* manifest = new (FB_STATIC_ARENA) BundleManifest();
    manifest->Load(buffer, manifestSize);
    g_bundleMerger->Merge(*manifest);

    std::vector<uint8_t> modified = manifest->Save();
    manifestSize = modified.size();

    uint8_t* modifiedBuffer = (uint8_t*)FB_STATIC_ARENA->alloc(manifestSize);
    memcpy(modifiedBuffer, modified.data(), manifestSize);

    buffer = modifiedBuffer;

    FB_STATIC_ARENA->del(manifest);

    KYBER_LOG(Debug, "Loading modified bundle manifest size " << manifestSize);
    return trampoline(inst, buffer, manifestSize, magicSalt);
}

BundleMerger::BundleMerger()
    : m_merger(nullptr)
{
    g_bundleMerger = this;

    // clang-format off
    HookTemplate hookOffsets[] = {
        { HOOK_OFFSET(0x1454B2C60), BundleManifestLoadHk }
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }
    Hook::ApplyQueuedActions();
}

void BundleMerger::SetMerger(BundleMergeFunc func)
{
    m_merger = func;
}

void BundleMerger::Merge(BundleManifest& manifest)
{
    m_merger(manifest);
}

std::unordered_map<uint32_t, BundleMerger::BundleEntry>& BundleMerger::GetBundleEntries()
{
    return m_bundleEntries;
}

void BundleMerger::LoadVanillaEntries()
{
    auto path = PlatformUtils::GetModulePath() / "VanillaBundleAggregation.kb";

    KYBER_LOG(Info, "[ModLoader] Loading bundle aggregation file");

    char* data = nullptr;
    size_t size;
    RTErrorT rtError = RT_LoadFile(path.string().c_str(), &data, &size);
    if (rtError != RT_SUCCESS)
    {
        KYBER_LOG(Error, "[ModLoader] Failed to open bundle aggregation file '" << path << "', mod loading might not work!");
        return;
    }

    KYBER_LOG(Info, "[ModLoader] Loaded file");

    bb::ByteBuffer buf(reinterpret_cast<uint8_t*>(data), size);

    uint32_t magic = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    if (magic != 0x77778888)
    {
        KYBER_LOG(Error, "[ModLoader] Bundle aggregation file had invalid magic 0x" << std::hex << magic << ", mod loading might not work!");
        return;
    }

    uint32_t catalogCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());

    m_catalogs.reserve(catalogCount);
    for (int i = 0; i < catalogCount; ++i)
    {
        m_catalogs.push_back(eastl::string(buf.getNullTerminatedString().c_str()));
    }

    KYBER_LOG(Info, "[ModLoader] Loaded " << catalogCount << " catalogs");

    uint32_t bundleEntryCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    for (int i = 0; i < bundleEntryCount; ++i)
    {
        BundleEntry entry;
        entry.hash = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        entry.ebxCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        entry.resCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        entry.chunkCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());

        int fileCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        entry.files.reserve(fileCount);

        for (int j = 0; j < fileCount; j++)
        {
            LayoutManifest::FileInfo fileInfo;
            fileInfo.file = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
            fileInfo.offset = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
            fileInfo.size = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
            entry.files.push_back(fileInfo);
        }

        m_bundleEntries[entry.hash] = entry;
    }

    KYBER_LOG(Info, "[ModLoader] Loaded bundles");

    uint32_t ebxEntryCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    for (int i = 0; i < ebxEntryCount; ++i)
    {
        std::string name = buf.getNullTerminatedString();
        uint32_t originalSize = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileRef = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileOffset = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileSize = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());

        VanillaEbxEntry vanillaEntry;
        vanillaEntry.entry = { name, originalSize };
        vanillaEntry.file = { static_cast<int32_t>(fileRef), fileOffset, fileSize };

        uint32_t bundleFileOffsetCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        for (int i = 0; i < bundleFileOffsetCount; i++)
        {
            uint32_t bundleHash = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
            uint32_t fileIndex = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
            vanillaEntry.bundleFileOffsets[bundleHash] = fileIndex;
        }

        m_vanillaEbxEntries[name] = vanillaEntry;
    }

    KYBER_LOG(Info, "[ModLoader] Loaded ebx entries");

    uint32_t resEntryCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    for (int i = 0; i < resEntryCount; ++i)
    {
        BundleManifest::ResEntry entry;
        entry.name = buf.getNullTerminatedString();
        entry.originalSize = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        entry.resType = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        buf.getBytes(entry.resMeta, 0x10);
        entry.resRid = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());

        uint32_t fileRef = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileOffset = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileSize = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());

        VanillaResEntry vanillaEntry;
        vanillaEntry.entry = entry;
        vanillaEntry.file = { static_cast<int32_t>(fileRef), fileOffset, fileSize };

        uint32_t bundleFileOffsetCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        for (int i = 0; i < bundleFileOffsetCount; i++)
        {
            uint32_t bundleHash = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
            uint32_t fileIndex = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
            vanillaEntry.bundleFileOffsets[bundleHash] = fileIndex;
        }

        m_vanillaResEntries[entry.name.c_str()] = vanillaEntry;
    }

    KYBER_LOG(Info, "[ModLoader] Loaded res entries");

    uint32_t chunkEntryCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
    for (int i = 0; i < chunkEntryCount; ++i)
    {
        BundleManifest::ChunkEntry entry;
        std::string name = buf.getNullTerminatedString();
        entry.guid = Guid::FromString(name);

        uint32_t fileRef = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileOffset = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        uint32_t fileSize = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());

        entry.logicalOffset = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        entry.logicalSize = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());
        buf.readUnsafe<uint64_t>(); // Original size

        VanillaChunkEntry vanillaEntry;
        vanillaEntry.entry = entry;
        vanillaEntry.file = { static_cast<int32_t>(fileRef), fileOffset, fileSize };
        vanillaEntry.h32 = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        vanillaEntry.firstMip = _SwapEndiannessU64(buf.readUnsafe<uint64_t>());

        uint32_t bundleFileOffsetCount = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
        for (int i = 0; i < bundleFileOffsetCount; i++)
        {
            uint32_t bundleHash = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
            uint32_t fileIndex = _SwapEndiannessU32(buf.readUnsafe<uint32_t>());
            vanillaEntry.bundleFileOffsets[bundleHash] = fileIndex;
        }

        m_vanillaChunkEntries[name] = vanillaEntry;
    }

    KYBER_LOG(Info, "[ModLoader] Loaded chunk entries");

    KYBER_LOG(Info, "[ModLoader] Loaded vanilla bundle aggregation, " << bundleEntryCount << " " << ebxEntryCount << " " << resEntryCount << " "
                                                          << chunkEntryCount);
}

BundleMerger::VanillaEbxEntry* BundleMerger::GetVanillaEbxEntry(const eastl::string& name)
{
    auto it = m_vanillaEbxEntries.find(name.c_str());
    if (it == m_vanillaEbxEntries.end())
    {
        return nullptr;
    }

    return &it->second;
}

BundleMerger::VanillaResEntry* BundleMerger::GetVanillaResEntry(const eastl::string& name)
{
    auto it = m_vanillaResEntries.find(name.c_str());
    if (it == m_vanillaResEntries.end())
    {
        return nullptr;
    }

    return &it->second;
}

BundleMerger::VanillaChunkEntry* BundleMerger::GetVanillaChunkEntry(const eastl::string& name)
{
    auto it = m_vanillaChunkEntries.find(name.c_str());
    if (it == m_vanillaChunkEntries.end())
    {
        return nullptr;
    }

    return &it->second;
}
} // namespace Kyber