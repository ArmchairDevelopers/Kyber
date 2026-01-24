// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/Handlers/LocalizationHandler.h>

#include <ModLoader/ModLoader.h>
#include <Core/Program.h>
#include <Utilities/StringUtils.h>

#include <map>

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

    uint8_t* histogramData = new uint8_t[db->HistogramChunkSize];
    ModLoader::ReadChunkSync(db->HistogramChunk, histogramData, db->HistogramChunkSize);

    std::vector<wchar_t> values = ModifyHistogram(&histogramData);

    uint8_t* chunkData = new uint8_t[db->BinaryChunkSize];
    ModLoader::ReadChunkSync(db->BinaryChunk, chunkData, db->BinaryChunkSize);

    std::vector<uint8_t> chunk = ModifyChunk(chunkData, db->BinaryChunkSize, data, values);

    KYBER_LOG(Info, "[ModLoader] Wrote Localization chunk (Sz: " << chunk.size() << ", " << db->BinaryChunkSize << ")");
    db->BinaryChunkSize = chunk.size();

    uint8_t* newData = new uint8_t[chunk.size()];
    memcpy(newData, chunk.data(), chunk.size());

    ModLoader::ModifyChunk(db->BinaryChunk, newData, chunk.size());

    delete[] chunkData;
    return true;
}

std::vector<wchar_t> LocalizationHandler::ModifyHistogram(uint8_t** histogramData)
{
    std::vector<wchar_t> values;
    uint32_t unk = RT_READ_BUF(uint32_t, histogramData);
    uint32_t size = RT_READ_BUF(uint32_t, histogramData);
    uint32_t unk2 = RT_READ_BUF(uint32_t, histogramData);

    for (int i = 0; i < (size / 2); i++)
    {
        wchar_t data = RT_READ_BUF(wchar_t, histogramData);
        values.push_back(data);
    }

    return values;
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
    for (int i = 0x1FE; i >= 0x80; i--)
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
