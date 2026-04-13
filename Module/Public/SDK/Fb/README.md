## Auto generated TypeInfo.h

Made using the following code (if needed to be replicated or touched up):
```cpp
TypeInfo* firstTypeInfo = (TypeInfo*)0x144742650;

typedef eastl::unordered_map<int32_t, std::ofstream> FileMap;
FileMap outFileMap;
for (TypeInfo* info = firstTypeInfo; info; info = info->next)
{
    if (info->typeInfoData->totalSize == 0 || strlen(info->typeInfoData->name) == 0 || info->getBasicType() == kTypeCode_Array ||
        info->getBasicType() == kTypeCode_DbObject || info->getBasicType() == kTypeCode_Void)
    {
        continue;
    }

    int32_t moduleHash = StringUtils::HashQuick(info->typeInfoData->module->moduleName);

    FileMap::iterator it = outFileMap.find(moduleHash);
    if (it == outFileMap.end())
    {
        outFileMap[moduleHash] =
            std::ofstream(std::string("E:/_Downloads/GeneratedTypeInfo/") + info->typeInfoData->module->moduleName + ".h");
        it = outFileMap.find(moduleHash);
        it->second << "namespace Kyber" << std::endl;
        it->second << "{" << std::endl;
        it->second << "class TypeInfo;" << std::endl;
        it->second << "#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr"
                    << std::endl << std::endl;
    }
    std::ofstream& outFile = it->second;

    outFile << "_KB_DECLARE_TYPEINFO(";
    outFile << info->getName();
    outFile << ", ";
    outFile << "0x" << std::hex << info;
    outFile << ");" << std::endl;
}

for (auto& pair : outFileMap)
{
    pair.second << std::endl;
    pair.second << "#undef _KB_DECLARE_TYPEINFO" << std::endl;
    pair.second << "}" << std::endl;
    pair.second.close();
}```