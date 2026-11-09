#pragma once

#include <ModLoader/CustomAssetHandler.h>

#include <map>

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
    std::vector<wchar_t> ModifyHistogram(uint8_t* histogramData, uint32_t histogramSize, LocalizationMergeData* data, bool& outModified);
    std::vector<uint8_t> ModifyChunk(
        uint8_t* chunkData, uint32_t chunkSize, LocalizationMergeData* data, const std::vector<wchar_t>& values);
};
} // namespace Kyber
