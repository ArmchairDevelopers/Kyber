// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <Base/Pch.h>

#include <Core/Program.h>
#include <ModLoader/ResourceMerger.h>
#include <ModLoader/BundleMerger.h>

#include <ByteBuffer/ByteBuffer.hpp>

#include <EASTL/sort.h>
#include <cstdint>

namespace Kyber
{
enum ResourceType
{
    ResourceType_MeshSet = 0x49B156D4,
    ResourceType_AssetBank = 0x51A3C853,
    ResourceType_ShaderBlockDepot = 0xD8F5DAAF,
};

class ResourceLoader
{
public:
    virtual ~ResourceLoader() = 0;
    virtual void* getTypes(uint32_t& count) const = 0;
};

TL_DECLARE_FUNC(0x1454B6B10, ResourceLoader*, ResourceManager_getLoader, uint32_t nameHash, void* flags, uint32_t* rangeCountPerResource);

void ResourceManagerAddLoaderHk(ResourceLoader* loader)
{
    static const auto trampoline = HookManager::Call(ResourceManagerAddLoaderHk);
    KYBER_LOG(Trace, "ResourceManager::addLoader(" << std::hex << loader << ")");
    trampoline(loader);
}

struct TurboBulkData2
{
    void* arena;
    unsigned int resourceTypeHash;
    unsigned int count;
    const unsigned int* originalFileSizes;
    void* headers;
    const char** debugNames;
    void** reloadTargets;
};

uint64_t ShaderBlockDepotLoaderPrepareTurboBulkHk(void* inst, void* data, void* range, uint64_t rangeCount)
{
    // 147C949A0
    return 0;
}

class ShaderBlockResourceMeta
{
public:
    uint32_t N000012C9;       // 0x0000
    uint32_t fullSize;        // 0x0004
    uint32_t relocTableCount; // 0x0008
    uint32_t sbResourceCount; // 0x000C
};

struct TurboBulkData
{
    uint32_t compartment;
    MemoryArena* arena;
    MemoryArena* fixupArena;
};

struct TurboLoadData
{
    void* unk1;
    ShaderBlockResourceMeta* meta;
    const char* name;
};

struct TurboLoadRange2
{
    uint8_t* dstEa;
    char gap8[4];
    uint32_t fileOffset;
    uint32_t eaSize;
    char gap14[20];
    void* dstEa2;
    char gap30[4];
    uint32_t fileOffset2;
    uint32_t eaSize2;
};

static void WritePadding(bb::ByteBuffer& buffer, uint32_t alignment)
{
    while (buffer.getWritePos() % alignment != 0)
    {
        buffer.put((uint8_t)0x00);
    }
}

static void ReadPadding(bb::ByteBuffer& buffer, uint32_t alignment)
{
    while (buffer.getReadPos() % alignment != 0)
    {
        buffer.setReadPos(buffer.getReadPos() + 1);
    }
}

using RelocTable = eastl::vector<uint32_t>;
using ShaderBlockEntryList = eastl::vector<class ShaderBlockResource*>;

class ShaderBlockResource
{
public:
    virtual ~ShaderBlockResource() = default;

    virtual void Read(bb::ByteBuffer& buffer, ShaderBlockEntryList* entries)
    {
        m_hash = buffer.getLong();
    }

    virtual void Write(bb::ByteBuffer& buffer, RelocTable& table, uint64_t& startOffset)
    {
        startOffset = buffer.getWritePos();
        buffer.putLong(m_hash);
        table.push_back(buffer.getWritePos());
    }

    uint32_t m_index = 0;
    uint64_t m_hash = 0;
};

class ShaderStaticParamDbBlock : public ShaderBlockResource
{
public:
    virtual ~ShaderStaticParamDbBlock() = default;

    virtual void Read(bb::ByteBuffer& buffer, ShaderBlockEntryList* entries) override
    {
        ShaderBlockResource::Read(buffer, entries);

        uint64_t offset = buffer.getLong();
        uint64_t size = buffer.getLong();

        buffer.setReadPos(offset);

        for (uint32_t i = 0; i < size; i++)
        {
            int32_t index = buffer.getInt();
            m_resources.push_back((*entries)[index]);
        }
    }

    virtual void Write(bb::ByteBuffer& buffer, RelocTable& table, uint64_t& startOffset) override
    {
        uint64_t offset = buffer.getWritePos();

        for (ShaderBlockResource* resource : m_resources)
        {
            buffer.putInt(resource->m_index);
        }

        WritePadding(buffer, 0x08);

        ShaderBlockResource::Write(buffer, table, startOffset);

        buffer.putLong(offset);
        buffer.putLong(m_resources.size());
    }

private:
    eastl::vector<ShaderBlockResource*> m_resources;
};

class ShaderBlockEntry : public ShaderStaticParamDbBlock
{
public:
};

class ParameterEntry
{
public:
    ParameterEntry(bb::ByteBuffer& buffer)
    {
        m_parameterHash = buffer.getLong();
        m_typeHash = buffer.getInt();
        m_used = buffer.getShort();
        m_nameHash = (uint32_t)((uint32_t)buffer.getShort() << 16 | (((m_parameterHash >> 48) & 0xFFFF)));

        int32_t size = buffer.getInt();
        if (m_typeHash == 0xad0abfd3) // ITexture
        {
            size = 16;
        }

        m_value.resize(size);
        buffer.getBytes(m_value.data(), size);
    }

    void Write(bb::ByteBuffer& buffer)
    {
        buffer.putLong(m_parameterHash);
        buffer.putInt(m_typeHash);
        buffer.putShort(m_used);
        buffer.putShort((uint16_t)(m_nameHash >> 16));
        buffer.putInt((m_typeHash == 0xad0abfd3) ? 1 : m_value.size());
        buffer.putBytes(m_value.data(), m_value.size());
    }

private:
    uint32_t m_nameHash;
    uint32_t m_typeHash;
    uint16_t m_used;
    std::vector<uint8_t> m_value;
    uint64_t m_parameterHash;
};

class ShaderPersistentParamDbBlock : public ShaderBlockResource
{
public:
    virtual void Read(bb::ByteBuffer& buffer, ShaderBlockEntryList* entries) override
    {
        ShaderBlockResource::Read(buffer, entries);

        uint64_t offset = buffer.getLong();
        uint64_t size = buffer.getLong();

        buffer.setReadPos(offset);
        int32_t count = buffer.getInt();

        for (uint32_t i = 0; i < count; i++)
        {
            m_parameters.push_back(new ParameterEntry(buffer));
        }
    }

    virtual void Write(bb::ByteBuffer& buffer, RelocTable& table, uint64_t& startOffset) override
    {
        uint64_t offset = buffer.getWritePos();

        buffer.putInt(m_parameters.size());
        for (ParameterEntry* parameter : m_parameters)
        {
            parameter->Write(buffer);
        }

        uint64_t size = (buffer.getWritePos() - offset);
        WritePadding(buffer, 0x8);

        ShaderBlockResource::Write(buffer, table, startOffset);

        buffer.putLong(offset);
        buffer.putLong(size);
    }

private:
    std::vector<ParameterEntry*> m_parameters;
};

class MeshParamDbBlock : public ShaderBlockResource
{
public:
    virtual void Read(bb::ByteBuffer& buffer, ShaderBlockEntryList* entries) override
    {
        ShaderBlockResource::Read(buffer, entries);

        uint64_t offset = buffer.getLong();
        uint64_t size = buffer.getInt();
        m_lodIndex = buffer.getInt();
        buffer.getBytes(m_guid.data, 16);

        buffer.setReadPos(offset);

        int32_t count = buffer.getInt();
        for (uint32_t i = 0; i < count; i++)
        {
            m_parameters.push_back(new ParameterEntry(buffer));
        }
    }

    virtual void Write(bb::ByteBuffer& buffer, RelocTable& table, uint64_t& startOffset) override
    {
        uint64_t offset = buffer.getWritePos();

        buffer.putInt(m_parameters.size());
        for (ParameterEntry* parameter : m_parameters)
        {
            parameter->Write(buffer);
        }

        uint64_t size = (buffer.getWritePos() - offset);
        WritePadding(buffer, 0x08);

        ShaderBlockResource::Write(buffer, table, startOffset);

        buffer.putLong(offset);
        buffer.putInt(size);
        buffer.putInt(m_lodIndex);
        buffer.putBytes(m_guid.data, 16);
    }

private:
    Guid m_guid;
    int32_t m_lodIndex;
    eastl::vector<ParameterEntry*> m_parameters;
};

class ShaderBlockMeshVariationEntry : public ShaderBlockResource
{
public:
    virtual void Read(bb::ByteBuffer& buffer, ShaderBlockEntryList* entries) override
    {
        ShaderBlockResource::Read(buffer, entries);

        uint64_t offset = buffer.getLong();
        uint64_t count = buffer.getLong();

        buffer.setReadPos(offset);

        for (uint32_t i = 0; i < count; i++)
        {
            Guid guid;
            buffer.getBytes(guid.data, 16);
            m_rvmShaderRefGuids.push_back(guid);

            m_rvmShaderRefInts.push_back(buffer.getInt());
        }
    }

    virtual void Write(bb::ByteBuffer& buffer, RelocTable& table, uint64_t& startOffset) override
    {
        uint64_t offset = buffer.getWritePos();

        for (uint32_t i = 0; i < m_rvmShaderRefGuids.size(); i++)
        {
            buffer.putBytes(m_rvmShaderRefGuids[i].data, 16);
            buffer.putInt(m_rvmShaderRefInts[i]);
        }

        WritePadding(buffer, 0x8);

        ShaderBlockResource::Write(buffer, table, startOffset);

        buffer.putLong(offset);
        buffer.putLong(m_rvmShaderRefGuids.size());
    }

private:
    eastl::vector<Guid> m_rvmShaderRefGuids;
    eastl::vector<int32_t> m_rvmShaderRefInts;
};

class ModifiedShaderBlockDepot
{
public:
    ModifiedShaderBlockDepot(eastl::string resName)
        : m_resName(resName)
    {}

    ~ModifiedShaderBlockDepot()
    {
        for (ShaderBlockResource* resource : m_resources)
        {
            delete resource;
        }
    }

    void Load(bb::ByteBuffer& buf)
    {
        eastl::vector<uint64_t> offsets;
        eastl::vector<uint64_t> hashes;
        ShaderBlockEntryList resources;

        int count = buf.getInt();
        ReadPadding(buf, 0x10);

        for (uint32_t i = 0; i < count; i++)
        {
            offsets.push_back(buf.getLong());
            uint64_t type = buf.getLong();

            ShaderBlockResource* resource = nullptr;
            switch (type)
            {
            case 0:
                resource = new ShaderBlockEntry();
                break;
            case 1:
                resource = new ShaderPersistentParamDbBlock();
                break;
            case 2:
                resource = new ShaderStaticParamDbBlock();
                break;
            case 3:
                resource = new MeshParamDbBlock();
                break;
            case 4:
                resource = new ShaderBlockMeshVariationEntry();
                break;
            default:
                KYBER_LOG(Error, "Unknown resource type " << type);
                break;
            }

            resources.push_back(resource);
        }

        for (uint64_t i = 0; i < offsets.size(); ++i)
        {
            if (resources[i] == nullptr)
            {
                KYBER_LOG(Error, "Resource " << i << "/" << offsets.size() << " is null");
                __debugbreak();
                continue;
            }

            buf.setReadPos(offsets[i]);
            resources[i]->Read(buf, nullptr);
            hashes.push_back(resources[i]->m_hash);
        }

        // Replace entries that are modified
        for (int i = 0; i < m_hashes.size(); ++i)
        {
            size_t hashIndex = eastl::find(hashes.begin(), hashes.end(), m_hashes[i]) - hashes.begin();
            if (hashIndex != hashes.size())
            {
                m_resources[i] = resources[hashIndex];
            }
        }

        // Add entries that are not in the original asset
        for (int i = 0; i < hashes.size(); ++i)
        {
            if (!ContainsHash(hashes[i]))
            {
                AddResource(hashes[i], resources[i]);
            }
        }
    }

    bool ContainsHash(uint64_t hash)
    {
        return eastl::find(m_hashes.begin(), m_hashes.end(), hash) != m_hashes.end();
    }

    ShaderBlockResource* GetResource(uint64_t hash)
    {
        size_t indexOf = eastl::find(m_hashes.begin(), m_hashes.end(), hash) - m_hashes.begin();
        if (indexOf != m_hashes.size())
        {
            return m_resources[indexOf];
        }

        return nullptr;
    }

    void AddResource(uint64_t hash, ShaderBlockResource* resource)
    {
        size_t indexOf = eastl::find(m_hashes.begin(), m_hashes.end(), hash) - m_hashes.begin();
        if (indexOf == m_hashes.size())
        {
            m_hashes.push_back(hash);
            m_resources.push_back(nullptr);
        }

        m_resources[indexOf] = resource;
    }

    void Collect()
    {
        for (auto& resource : g_modLoader->m_modResources)
        {
            if (resource.type != FrostyResourceType_Res || resource.name != m_resName)
            {
                continue;
            }

            if (resource.handlerHash == 0)
            {
                continue;
            }

            bb::ByteBuffer buf(reinterpret_cast<uint8_t*>(const_cast<void*>(resource.data.buffer)), resource.data.size);

            std::string typeName = buf.getNullTerminatedString();
            KYBER_LOG(Debug, "Loading handler data " << typeName << " from " << resource.modName.c_str());

            bb::ByteBuffer buf2(
                reinterpret_cast<uint8_t*>(reinterpret_cast<uintptr_t>(const_cast<void*>(resource.data.buffer)) + typeName.size() + 1),
                resource.data.size - typeName.size() - 1);
            Load(buf2);
        }
    }

private:
    eastl::string m_resName;

    ShaderBlockEntryList m_resources;
    eastl::vector<uint64_t> m_hashes;
};

void* ShaderBlockDepotLoaderFixupTurboBulkHk(void* inst, TurboBulkData* bulk, TurboLoadData* data, TurboLoadRange2* ranges)
{
    static const auto trampoline = HookManager::Call(ShaderBlockDepotLoaderFixupTurboBulkHk);
    // KYBER_LOG(Trace, "ShaderBlockDepotLoader::fixupTurboBulk(" << data->name << ", " << data->meta->sbResourceCount << ", " << ranges->eaSize
    //                                                           << ", " << ranges->eaSize2 << ", " << data->meta->fullSize << ", " << std::hex
    //                                                           << data << ", " << ranges << ")");

    bb::ByteBuffer buffer(ranges->dstEa, ranges->eaSize);

    ModifiedShaderBlockDepot depot(data->name);
    depot.Collect();

    eastl::vector<uint64_t> offsets;
    eastl::vector<ShaderBlockResource*> resources;

    for (uint32_t i = 0; i < data->meta->sbResourceCount; i++)
    {
        offsets.push_back(buffer.getLong());
        uint64_t type = buffer.getLong();

        ShaderBlockResource* resource = nullptr;
        switch (type)
        {
        case 0:
            resource = new ShaderBlockEntry();
            break;
        case 1:
            resource = new ShaderPersistentParamDbBlock();
            break;
        case 2:
            resource = new ShaderStaticParamDbBlock();
            break;
        case 3:
            resource = new MeshParamDbBlock();
            break;
        case 4:
            resource = new ShaderBlockMeshVariationEntry();
            break;
        }

        resources.push_back(resource);
    }

    for (uint64_t i = 0; i < offsets.size(); ++i)
    {
        buffer.setReadPos(offsets[i]);
        resources[i]->Read(buffer, &resources);

        if (depot.ContainsHash(resources[i]->m_hash))
        {
            ShaderBlockResource* existing = depot.GetResource(resources[i]->m_hash);
            if (existing != nullptr)
            {
                delete resources[i];
                resources[i] = existing;
            }
            else
            {
                KYBER_LOG(Error, "Resource not found in depot");
            }
        }

        resources[i]->m_index = i;
    }

    bb::ByteBuffer writeBuffer;
    for (ShaderBlockResource* resource : resources)
    {
        writeBuffer.putLong(0);
        writeBuffer.putLong(0);
    }

    std::vector<uint64_t> writeOffsets;
    RelocTable relocTable;

    for (int i = 0; i < resources.size(); ++i)
    {
        uint32_t offset = writeBuffer.getWritePos();

        uint64_t startOffset = 0;
        resources[i]->Write(writeBuffer, relocTable, startOffset);
        writeOffsets.push_back(startOffset);

        relocTable.push_back(i * 0x10);
    }

    WritePadding(writeBuffer, 0x10);

    uint32_t fullSize = writeBuffer.getWritePos();

    writeBuffer.setWritePos(0);
    for (int i = 0; i < resources.size(); i++)
    {
        writeBuffer.putLong(writeOffsets[i]);

        ShaderBlockResource* resource = resources[i];
        if (dynamic_cast<ShaderBlockEntry*>(resource) != nullptr)
        {
            writeBuffer.putLong(0);
        }
        else if (dynamic_cast<ShaderPersistentParamDbBlock*>(resource) != nullptr)
        {
            writeBuffer.putLong(1);
        }
        else if (dynamic_cast<ShaderStaticParamDbBlock*>(resource) != nullptr)
        {
            writeBuffer.putLong(2);
        }
        else if (dynamic_cast<MeshParamDbBlock*>(resource) != nullptr)
        {
            writeBuffer.putLong(3);
        }
        else if (dynamic_cast<ShaderBlockMeshVariationEntry*>(resource) != nullptr)
        {
            writeBuffer.putLong(4);
        }
        else
        {
            KYBER_LOG(Error, "Unknown resource type " << typeid(resource).name());
        }
    }

    data->meta->fullSize = fullSize;
    data->meta->relocTableCount = relocTable.size() * 4;
    data->meta->sbResourceCount = resources.size();

    bb::ByteBuffer relocBuffer;
    for (uint32_t offset : relocTable)
    {
        relocBuffer.putInt(offset);
    }

    // if (ranges->eaSize != fullSize)
    // {
    //     KYBER_LOG(Error, "Mismatched sizes: " << fullSize << " " << ranges->eaSize);
    //     mismatch = true;
    // }

    // if (memcmp(ranges->dstEa, writeBuffer.getBuf().data(), fullSize) != 0)
    // {
    //     KYBER_LOG(Debug, "SBD mismatch! Probably because it was edited");
    //     mismatch = true;
    // }

    void* bufferFb = bulk->arena->alloc(fullSize);
    memcpy(bufferFb, writeBuffer.getBuf().data(), fullSize);

    ranges->dstEa = (uint8_t*)bufferFb;
    ranges->eaSize = fullSize;

    uint32_t relocSize = relocBuffer.getWritePos();
    void* relocBufferFb = bulk->fixupArena->alloc(relocSize);
    memcpy(relocBufferFb, relocBuffer.getBuf().data(), relocSize);

    // if (memcmp(ranges->dstEa2, relocBufferFb, relocSize) != 0)
    // {
    //     KYBER_LOG(Error, "Reloc mismatch!");
    //     mismatch = true;
    // }

    bulk->fixupArena->free(ranges->dstEa2);
    // if (relocSize != ranges->eaSize2)
    // {
    //     KYBER_LOG(Error, "Mismatched sizes " << relocSize << " " << ranges->eaSize2);
    //     mismatch = true;
    // }

    ranges->dstEa2 = (uint8_t*)relocBufferFb;
    ranges->eaSize2 = relocSize;
    return trampoline(inst, bulk, data, ranges);
}

ResourceMerger::ResourceMerger()
{
    // clang-format off
    HookTemplate hookOffsets[] = {
        { HOOK_OFFSET(0x14021ED40), ResourceManagerAddLoaderHk },
        { HOOK_OFFSET(0x147C86050), ShaderBlockDepotLoaderFixupTurboBulkHk },
    };
    // clang-format on

    for (HookTemplate& hook : hookOffsets)
    {
        HookManager::CreateHook(hook.offset, hook.hook);
    }
    Hook::ApplyQueuedActions();
}

void ResourceMerger::onResourceManagerInitialized()
{
    ResourceLoader* shaderBlockLoader = ResourceManager_getLoader(ResourceType_AssetBank, nullptr, nullptr);
    if (shaderBlockLoader == nullptr)
    {
        KYBER_LOG(Error, "Failed to get shader block loader");
        return;
    }

    KYBER_LOG(Debug, "Got shader block loader: " << std::hex << shaderBlockLoader);
}
} // namespace Kyber
