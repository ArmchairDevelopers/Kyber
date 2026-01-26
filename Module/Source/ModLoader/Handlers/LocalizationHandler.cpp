// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/Handlers/LocalizationHandler.h>
#include <ModLoader/ModLoader.h>
#include <Core/Program.h>
#include <Utilities/StringUtils.h>

#include <map>
#include <set>
#include <vector>
#include <algorithm>

namespace Kyber
{
LocalizationHandler::LocalizationHandler()
    : GenericCustomAssetHandler(CustomAssetHandlerLoadStage_PostLoad)
{}

void LocalizationHandler::Load(const eastl::string& modName, bb::ByteBuffer& buf, LocalizationMergeData* data)
{
    uint32_t magic = buf.getInt();
    int32_t count = (magic == 0xABCD0001) ? buf.getInt() : (int32_t)magic;

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

    // 1. Process Histogram
    uint8_t* histogramDataRaw = new uint8_t[db->HistogramChunkSize];
    ModLoader::ReadChunkSync(db->HistogramChunk, histogramDataRaw, db->HistogramChunkSize);

    // Detect character table start (skipping header and padding)
    uint32_t tableOffset = 0x100; 
    for (uint32_t i = 8; i < 0x200; i += 2) {
        if (*(uint16_t*)(histogramDataRaw + i) != 0) {
            tableOffset = i;
            break;
        }
    }

    // Mapping of Char -> Byte Index
    std::map<wchar_t, uint8_t> charMap;
    std::vector<uint16_t> patchedTable = ModifyHistogram(&histogramDataRaw, db->HistogramChunkSize, data, tableOffset, charMap);

    uint8_t* persistentHistogram = new uint8_t[db->HistogramChunkSize];
    memset(persistentHistogram, 0, db->HistogramChunkSize);
    memcpy(persistentHistogram, histogramDataRaw, db->HistogramChunkSize); 

    // Inject our custom character table
    memcpy(persistentHistogram + tableOffset, patchedTable.data(), patchedTable.size() * 2);

    ModLoader::ModifyChunk(db->HistogramChunk, (const void*)persistentHistogram, db->HistogramChunkSize);
    delete[] histogramDataRaw;

    // 2. Process Binary Strings
    uint8_t* chunkData = new uint8_t[db->BinaryChunkSize];
    ModLoader::ReadChunkSync(db->BinaryChunk, chunkData, db->BinaryChunkSize);

    std::vector<uint8_t> newBinaryVec = ModifyChunk(chunkData, db->BinaryChunkSize, data, charMap);

    uint8_t* persistentBinary = new uint8_t[newBinaryVec.size()];
    memcpy(persistentBinary, newBinaryVec.data(), newBinaryVec.size());

    db->BinaryChunkSize = (uint32_t)newBinaryVec.size();
    ModLoader::ModifyChunk(db->BinaryChunk, (const void*)persistentBinary, (uint32_t)newBinaryVec.size());

    delete[] chunkData;
    return true;
}

std::vector<uint16_t> LocalizationHandler::ModifyHistogram(uint8_t** histogramDataPtr, uint32_t sizeBytes, LocalizationMergeData* data, uint32_t tableOffset, std::map<wchar_t, uint8_t>& outCharMap)
{
    uint8_t* raw = *histogramDataPtr;
    const int numEntries = 2048; 
    std::vector<uint16_t> histogram(numEntries, 0);

    // Copy original character map (latin, icons, numbers)
    uint32_t bytesToCopy = std::min((uint32_t)(numEntries * 2), sizeBytes - tableOffset);
    memcpy(histogram.data(), raw + tableOffset, bytesToCopy);

    // Populate existing characters into our map for strings processing
    for (int i = 0; i < 128; i++) {
        if (histogram[i] != 0) outCharMap[(wchar_t)histogram[i]] = (uint8_t)i;
    }

    // Find all custom non-ASCII characters across all mod strings
    std::set<wchar_t> neededChars;
    for (const auto& entry : data->strings) {
        for (wchar_t c : entry.second) {
            if (c >= 0x80) neededChars.insert(c);
        }
    }

    // Remove characters that already exist in the original histogram
    for (int i = 0; i < numEntries; i++) {
        if (neededChars.count((wchar_t)histogram[i])) {
            neededChars.erase((wchar_t)histogram[i]);
        }
    }

    // In English Frostbite engine, indices 128 and 129 (0x80, 0x81) are often ignored
    // or treated as internal control codes. To fix text rendering, we start 
    // custom characters at index 130 and apply a -2 offset during encoding.
    int slotPtr = 130;
    for (wchar_t c : neededChars) {
        while (slotPtr < 255 && histogram[slotPtr] != 0) slotPtr++;
        
        if (slotPtr < 255) {
            histogram[slotPtr] = (uint16_t)c;
            outCharMap[c] = (uint8_t)(slotPtr - 2); // Save index with -2 correction
            slotPtr++;
        }
    }

    return histogram;
}

std::vector<uint8_t> LocalizationHandler::ModifyChunk(
    uint8_t* chunkData, uint32_t chunkSize, LocalizationMergeData* data, const std::map<wchar_t, uint8_t>& charMap)
{
    bb::ByteBuffer inBuf(chunkData, chunkSize);
    uint32_t magic = inBuf.getInt();
    uint32_t size = inBuf.getInt();
    int32_t count = inBuf.getInt();
    uint32_t dataOffset = inBuf.getInt();
    uint32_t stringsOffset = inBuf.getInt();
    std::string tag = inBuf.getNullTerminatedString();

    std::map<uint32_t, std::wstring> strings;
    std::vector<uint32_t> ids(count);
    
    // Read original string database
    inBuf.setReadPos(dataOffset + 8);
    for (int i = 0; i < count; i++) {
        ids[i] = inBuf.getInt();
        uint32_t offset = inBuf.getInt();
        size_t savedPos = inBuf.getReadPos();
        inBuf.setReadPos(stringsOffset + offset + 8);
        strings[ids[i]] = inBuf.getNullTerminatedWideStringAsAscii();
        inBuf.setReadPos(savedPos);
    }

    // Merge mod strings
    for (const auto& entry : data->strings) {
        if (std::find(ids.begin(), ids.end(), entry.first) == ids.end()) ids.push_back(entry.first);
        strings[entry.first] = entry.second;
    }
    std::sort(ids.begin(), ids.end());

    bb::ByteBuffer stringBuf;
    std::vector<uint32_t> newOffsets;

    for (uint32_t id : ids) {
        newOffsets.push_back((uint32_t)stringBuf.getWritePos());
        std::wstring& text = strings[id];

        for (wchar_t c : text) {
            // Native ASCII support
            if (c < 128) {
                stringBuf.put((uint8_t)c);
                continue;
            }

            // Lookup custom character from our corrected map
            if (charMap.count(c)) {
                stringBuf.put(charMap.at(c));
            } else {
                stringBuf.put((uint8_t)'?');
            }
        }
        stringBuf.put((uint8_t)0x00);
    }

    bb::ByteBuffer outBuf;
    outBuf.putInt(magic);
    outBuf.putInt(0); 
    outBuf.putInt((int32_t)ids.size());
    outBuf.putInt(0x8C);
    outBuf.putInt(0x8C + (8 * (uint32_t)ids.size()));
    outBuf.putNullTerminatedString(tag.c_str());

    while (outBuf.getWritePos() < 0x8C + 8) outBuf.put((uint8_t)0x00);

    for (int i = 0; i < (int)ids.size(); i++) {
        outBuf.putInt(ids[i]);
        outBuf.putInt(newOffsets[i]);
    }
    outBuf.put(&stringBuf);

    outBuf.setWritePos(4);
    outBuf.putInt((uint32_t)outBuf.getWritePos() - 8);

    return outBuf.getBuf();
}
} // namespace Kyber
