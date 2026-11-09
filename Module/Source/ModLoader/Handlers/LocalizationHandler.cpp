// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/Handlers/LocalizationHandler.h>

#include <ModLoader/ModLoader.h>
#include <Core/Program.h>
#include <Utilities/StringUtils.h>

#include <algorithm>
#include <map>
#include <set>

namespace Kyber
{
LocalizationHandler::LocalizationHandler()
    : GenericCustomAssetHandler(CustomAssetHandlerLoadStage_PostLoad)
{}

void LocalizationHandler::Load(const eastl::string& modName, bb::ByteBuffer& buf, LocalizationMergeData* data)
{
    uint32_t magic = buf.getInt();

    int32_t count = 0;
    if (magic != 0xABCD0001)
    {
        count = (int32_t)magic;
    }
    else
    {
        count = buf.getInt();
    }

    for (int i = 0; i < count; i++)
    {
        uint32_t hash = buf.getInt();
        std::wstring str = buf.getNullTerminatedWideString();
        data->strings[hash] = str;
    }
}

bool LocalizationHandler::Modify(CustomAssetHandlerContext& ctx, DataContainer* container, LocalizationMergeData* data)
{
    UITextDatabase* db = static_cast<UITextDatabase*>(container);

    uint8_t* histogramData = new (FB_GLOBAL_ARENA) uint8_t[db->HistogramChunkSize];
    ModLoader::ReadChunkSync(db->HistogramChunk, histogramData, db->HistogramChunkSize);

    bool histogramModified = false;
    std::vector<wchar_t> values = ModifyHistogram(histogramData, db->HistogramChunkSize, data, histogramModified);

    if (values.empty())
    {
        KYBER_LOG(Error, "Failed to merge localization: Invalid Histogram Chunk");
        FB_GLOBAL_ARENA->free(histogramData);
        return false;
    }

    if (histogramModified)
    {
        // The game reads the overridden chunk from this buffer, so it must stay alive
        ModLoader::ModifyChunk(db->HistogramChunk, histogramData, db->HistogramChunkSize);
    }
    else
    {
        FB_GLOBAL_ARENA->free(histogramData);
    }

    uint8_t* chunkData = new (FB_GLOBAL_ARENA) uint8_t[db->BinaryChunkSize];
    ModLoader::ReadChunkSync(db->BinaryChunk, chunkData, db->BinaryChunkSize);

    std::vector<uint8_t> chunk = ModifyChunk(chunkData, db->BinaryChunkSize, data, values);
    FB_GLOBAL_ARENA->free(chunkData);

    if (chunk.empty())
    {
        return false;
    }

    KYBER_LOG(Info, "[ModLoader] Wrote Localization chunk (Sz: " << chunk.size() << ", " << db->BinaryChunkSize << ")");
    db->BinaryChunkSize = chunk.size();

    uint8_t* newData = new (FB_GLOBAL_ARENA) uint8_t[chunk.size()];
    memcpy(newData, chunk.data(), chunk.size());

    ModLoader::ModifyChunk(db->BinaryChunk, newData, chunk.size());

    return true;
}

std::vector<wchar_t> LocalizationHandler::ModifyHistogram(
    uint8_t* histogramData, uint32_t histogramSize, LocalizationMergeData* data, bool& outModified)
{
    // Chunk layout: magic (u32), size of the data after this field (u32), character count (u32),
    // then the character table (u16 per entry). Data after the character table is not part of it.
    constexpr uint32_t c_headerSize = 12;

    // Bytes 0x80-0xFF in the string chunk index the table directly, empty slots hold 0
    constexpr uint32_t c_singleByteBegin = 0x80;
    constexpr uint32_t c_singleByteEnd = 0x100;

    outModified = false;

    if (histogramSize < c_headerSize)
    {
        return std::vector<wchar_t>();
    }

    uint32_t count = *reinterpret_cast<uint32_t*>(histogramData + 8);
    count = std::min(count, (histogramSize - c_headerSize) / static_cast<uint32_t>(sizeof(uint16_t)));

    wchar_t* table = reinterpret_cast<wchar_t*>(histogramData + c_headerSize);
    wchar_t* tableEnd = table + count;

    // Characters used by mods that the current game language has no table entry for
    std::set<wchar_t> missing;
    for (const auto& entry : data->strings)
    {
        for (wchar_t c : entry.second)
        {
            if (c < 0x80)
            {
                continue;
            }

            if (std::find(table, tableEnd, c) == tableEnd)
            {
                missing.insert(c);
            }
        }
    }

    // Put them into free single-byte slots, the same way localized game clients store their characters
    uint32_t slot = c_singleByteBegin;
    uint32_t slotEnd = std::min(c_singleByteEnd, count);
    uint32_t added = 0;
    for (wchar_t c : missing)
    {
        while (slot < slotEnd && table[slot] != 0)
        {
            slot++;
        }

        if (slot >= slotEnd)
        {
            KYBER_LOG(Warning, "[ModLoader] Localization histogram is full, character not added: " << static_cast<uint16_t>(c));
            continue;
        }

        table[slot] = c;
        added++;
    }

    if (added > 0)
    {
        outModified = true;
        KYBER_LOG(Info, "[ModLoader] Added " << added << " characters to localization histogram");
    }

    return std::vector<wchar_t>(table, tableEnd);
}

std::vector<uint8_t> LocalizationHandler::ModifyChunk(
    uint8_t* chunkData, uint32_t chunkSize, LocalizationMergeData* data, const std::vector<wchar_t>& values)
{
    bb::ByteBuffer inBuf(chunkData, chunkSize);

    uint32_t magic = inBuf.getInt();
    if (magic != 0x00039000)
    {
        KYBER_LOG(Error, "Failed to merge localization: Invalid Chunk Header");
        return std::vector<uint8_t>();
    }

    uint32_t size = inBuf.getInt();
    int32_t count = inBuf.getInt();
    uint32_t dataOffset = inBuf.getInt();
    uint32_t stringsOffset = inBuf.getInt();

    std::string tag = inBuf.getNullTerminatedString();

    inBuf.setReadPos(dataOffset + 8);

    std::map<uint32_t, std::wstring> strings;
    std::vector<uint32_t> ids(count);
    std::vector<uint32_t> offsets(count);

    for (int i = 0; i < count; i++)
    {
        ids[i] = inBuf.getInt();
        offsets[i] = inBuf.getInt();
    }

    for (int i = 0; i < count; i++)
    {
        inBuf.setReadPos(stringsOffset + offsets[i] + 8);

        std::wstring str = inBuf.getNullTerminatedWideStringAsAscii();
        strings[ids[i]] = str;
    }

    std::vector<uint8_t> histogramShifts;
    int32_t lastShift = std::min(0x1FE, static_cast<int32_t>(values.size()) - 1);
    for (int32_t i = lastShift; i >= 0x80; i--)
    {
        if (values[i] < 0x80)
        {
            histogramShifts.push_back((uint8_t)i);
        }
    }

    for (const auto& entry : data->strings)
    {
        std::wstring sb;
        for (char16_t b : entry.second)
        {
            if (b < 0x80)
            {
                sb += b;
                continue;
            }

            auto it = std::find(values.begin(), values.end(), b);
            if (it == values.end())
            {
                KYBER_LOG(Debug, "Character not supported: " << (uint16_t)b << " from string: " << entry.first);
                continue;
            }

            auto index = std::distance(values.begin(), it);
            if (index <= 0xFF)
            {
                sb += (char16_t)((uint8_t)index);
                continue;
            }

            for (uint8_t shift : histogramShifts)
            {
                if ((index - (values[shift] << 7)) < 0x80)
                {
                    sb += (char16_t)shift;
                    sb += (char16_t)((uint8_t)(index - (values[shift] << 7) + 0x80));
                    break;
                }
            }
        }

        if (std::find(ids.begin(), ids.end(), entry.first) == ids.end())
        {
            ids.push_back(entry.first);
        }

        strings[entry.first] = sb;
    }

    std::sort(ids.begin(), ids.end());
    offsets.clear();

    bb::ByteBuffer stringBuf;
    for (int i = 0; i < ids.size(); i++)
    {
        offsets.push_back(stringBuf.getWritePos());

        std::wstring& str = strings[ids[i]];
        stringBuf.putNullTerminatedWideString(str.c_str());
    }

    bb::ByteBuffer buf;
    buf.putInt(0x00039000); // magic
    buf.putInt(0xdeadbeef); // size
    buf.putInt(ids.size());
    buf.putInt(0x8C); // dataOffset

    buf.putInt(0x8C + (8 * ids.size())); // stringsOffset
    buf.putNullTerminatedString(tag.c_str());

    while (buf.getWritePos() < 0x8C + 8)
    {
        buf.put((uint8_t)0x00);
    }

    for (int i = 0; i < ids.size(); i++)
    {
        buf.putInt(ids[i]);
        buf.putInt(offsets[i]);
    }

    buf.put(&stringBuf);

    size = buf.getWritePos() - 8;
    buf.setWritePos(4);
    buf.putInt(size);

    return buf.getBuf();
}
} // namespace Kyber
