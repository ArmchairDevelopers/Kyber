#pragma once

#include <ModLoader/CustomAssetHandler.h>
#include <map>
#include <vector>
#include <string>

namespace Kyber
{
struct LocalizationMergeData : public CustomAssetHandlerData
{
    std::map<uint32_t, std::wstring> strings;
};

class LocalizationHandler : public GenericCustomAssetHandler<LocalizationMergeData>
{
public:
    LocalizationHandler();

    void Load(const eastl::string& modName, bb::ByteBuffer& buf, LocalizationMergeData* data) override;
    bool Modify(CustomAssetHandlerContext& ctx, DataContainer* container, LocalizationMergeData* data) override;

private:
    std::vector<uint16_t> ModifyHistogram(uint8_t** histogramData, uint32_t sizeBytes, LocalizationMergeData* data, uint32_t tableOffset, std::map<wchar_t, uint8_t>& outCharMap);
    
    std::vector<uint8_t> ModifyChunk(
        uint8_t* chunkData, uint32_t chunkSize, LocalizationMergeData* data, const std::map<wchar_t, uint8_t>& charMap);
};
} // namespace Kyber
