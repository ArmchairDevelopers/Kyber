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

WIP code

```cpp
TypeInfo* firstTypeInfo = (TypeInfo*)0x144742650;

const char nl = '\n';
typedef eastl::unordered_map<int32_t, std::ofstream> FileMap;
typedef eastl::unordered_map<int32_t, eastl::string> ModuleNameMap;
typedef eastl::unordered_map<int32_t, eastl::hash_set<uint32_t>> GeneratedTypesMap;

FileMap outFileMap;
ModuleNameMap moduleNameMap;
GeneratedTypesMap generatedTypesMap;

for (TypeInfo* info = firstTypeInfo; info; info = info->next)
{
    if (info->typeInfoData->totalSize == 0 || strlen(info->typeInfoData->name) == 0 || info->getBasicType() == kTypeCode_Array ||
        info->getBasicType() == kTypeCode_DbObject || info->getBasicType() == kTypeCode_Void)
    {
        continue;
    }

    int32_t moduleHash = StringUtils::HashQuick(info->typeInfoData->module->moduleName);

    ModuleNameMap::iterator mnmIt = moduleNameMap.find(moduleHash);
    if (mnmIt == moduleNameMap.end())
    {
        moduleNameMap[moduleHash] = info->typeInfoData->module->moduleName;
    }

    FileMap::iterator it = outFileMap.find(moduleHash);
    if (it == outFileMap.end())
    {
        outFileMap[moduleHash] =
            std::ofstream(std::string("E:/_Downloads/GeneratedTypeInfo/") + info->typeInfoData->module->moduleName + ".h");
        it = outFileMap.find(moduleHash);
        it->second << "#pragma once" << std::endl << std::endl;
        it->second << "namespace Kyber" << std::endl;
        it->second << "{" << std::endl;
        it->second << "class TypeInfo;" << std::endl;
        it->second << "#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr"
                    << std::endl
                    << std::endl;
    }
    std::ofstream& stream = it->second;

    if (info->m_super && info->m_super->typeInfoData->module && info->m_super->typeInfoData->module != info->typeInfoData->module)
    {
        GeneratedTypesMap::iterator gtmIt = generatedTypesMap.find(moduleHash);
        if (gtmIt == generatedTypesMap.end())
        {
            generatedTypesMap[moduleHash] = eastl::hash_set<uint32_t>();
            gtmIt = generatedTypesMap.find(moduleHash);
        }

        gtmIt->second.insert(StringUtils::HashQuick(info->m_super->getName()));
    }

    if (info->getBasicType() == kTypeCode_Class || info->getBasicType() == kTypeCode_ValueType)
    {
        bool isClass = info->getBasicType() == kTypeCode_Class;
    }
    else if (info->getBasicType() == kTypeCode_Enum)
    {
        // Easiest of all

        stream << "enum class " << info->getName() << nl;
        stream << "{" << nl;

        EnumTypeInfoData* data = (EnumTypeInfoData*)info->typeInfoData;

        for (int i = 0; i < data->fieldCount; i++)
        {
            FieldInfoData& field = data->fields[i];
            stream << '\t' << field.name << " = " << reinterpret_cast<uint64_t>(field.fieldTypePtr) << nl;
        }

        stream << "};" << nl;
    }

    stream << "_KB_DECLARE_TYPEINFO(" << info->getName() << ", ";
    stream << "0x" << std::hex << info;
    stream << ");" << std::endl;
}

for (auto& pair : outFileMap)
{
    pair.second << std::endl;
    pair.second << "#undef _KB_DECLARE_TYPEINFO" << std::endl;
    pair.second << "}" << std::endl;
    pair.second.close();
}
```