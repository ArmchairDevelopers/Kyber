// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <ModLoader/CustomAssetHandler.h>

#include <ModLoader/ModLoader.h>
#include <Core/Program.h>
#include <Utilities/StringUtils.h>
#include <SDK/Funcs.h>

namespace Kyber
{
CustomAssetHandler::CustomAssetHandler(CustomAssetHandlerLoadStage loadStage)
    : m_loadStage(loadStage)
{}

DataContainer* findDataContainer(void* domain, const EbxImportReference& ref, const char* tag)
{
    if (ref.partitionGuid.IsZero())
    {
        return nullptr;
    }

    DatabasePartition* partition = RuntimeDatabaseDomain_findPartitionFromGuidIncludingImports(domain, ref.partitionGuid);
    if (partition == nullptr)
    {
        auto& vec = g_modLoader->m_domainLoadedPartitions[domain];
        auto it = vec.find(ref.partitionGuid);
        if (it != vec.end())
        {
            partition = it->second;
        }
    }
    
    if (partition == nullptr)
    {

        KYBER_LOG(Warning, "[" << tag << "] Failed to find partition " << ref.partitionGuid.ToString() << "/" << ref.instanceGuid.ToString());
        return nullptr;
    }

    DataContainer* container = partition->FindInstanceByGuid(ref.instanceGuid);
    if (container == nullptr)
    {
        KYBER_LOG(Warning, "[" << tag << "] Failed to find instance " << ref.partitionGuid.ToString() << "/" << ref.instanceGuid.ToString());
        return nullptr;
    }

    return container;
}

EbxImportReference parseReference(bb::ByteBuffer& buf)
{
    Guid classGuid = Guid::FromFrostyLE(buf);
    Guid fileGuid = Guid::FromFrostyLE(buf);

    return EbxImportReference{ fileGuid, classGuid };
}

EbxImportReference parseReference2(bb::ByteBuffer& buf)
{
    Guid fileGuid = Guid::FromFrostyLE(buf);
    Guid classGuid = Guid::FromFrostyLE(buf);

    return EbxImportReference{ fileGuid, classGuid };
}
} // namespace Kyber