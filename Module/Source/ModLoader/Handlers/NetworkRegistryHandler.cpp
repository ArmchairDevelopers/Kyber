// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/Handlers/NetworkRegistryHandler.h>

#include <ModLoader/ModLoader.h>
#include <Core/Program.h>
#include <Utilities/StringUtils.h>

namespace Kyber
{
NetworkRegistryHandler::NetworkRegistryHandler()
    : GenericCustomAssetHandler(CustomAssetHandlerLoadStage_ReferencesResolved)
{}

void NetworkRegistryHandler::Load(const eastl::string& modName, bb::ByteBuffer& buf, NetworkRegistryMergeData* data)
{
    int32_t count = buf.getInt();
    for (int i = 0; i < count; i++)
    {
        Guid classGuid = Guid::FromFrostyLE(buf);
        Guid fileGuid = Guid::FromFrostyLE(buf);

        EbxImportReference eir = { fileGuid, classGuid };
        data->values.push_back(eir);
    }

    KYBER_LOG(Debug, "[ModLoader] Loaded " << count << " new netreg IDs");
}

bool NetworkRegistryHandler::Modify(CustomAssetHandlerContext& ctx, DataContainer* container, NetworkRegistryMergeData* data)
{
    NetworkRegistryAsset* asset = static_cast<NetworkRegistryAsset*>(container);

    if (ctx.clearRequired)
    {
        asset->Objects.init(0);
    }
    else
    {
        bool foundNull = false;

        // Make sure it's safe to extend the array;
        // all references need to be resolved.
        // Returning false here kicks the resource
        // manager and calls this function again.
        for (int i = 0; i < asset->Objects.size(); i++)
        {
            if (asset->Objects.m_data[i] == nullptr)
            {
                KYBER_LOG(Debug, "[ModLoader] Retrying netreg (" << asset->Name << ", " << i << "/" << asset->Objects.size() << ", " << std::hex
                                                       << &asset->Objects.m_data[i] << ")");
                // foundNull = true;
                asset->Objects.m_data[i] = asset->Objects.m_data[0];
            }
        }

        if (foundNull)
        {
            return false;
        }
    }

    uint32_t oldSize = asset->Objects.size();
    uint32_t addedSize = data->values.size();

    asset->Objects.extend(addedSize);
    for (int i = 0; i < addedSize; i++)
    {
        DataContainer* object = findDataContainer(ctx.runtimeDatabaseDomain, data->values[i], "NetReg");
        if (object == nullptr)
        {
            KYBER_LOG(Error, "[ModLoader] Network Registry instance was null: Index " << (oldSize + i) << " of " << asset->Name);
            continue;
        }

        asset->Objects.m_data[oldSize + i] = object;
    }

    KYBER_LOG(Debug, "[ModLoader] Added " << addedSize << " objects to " << asset->Name << ", new size " << asset->Objects.size());
    return true;
}
} // namespace Kyber
