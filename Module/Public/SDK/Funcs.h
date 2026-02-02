// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <SDK/TypeInfo.h>
#include <SDK/SDK.h>

#include <ToolLib/Func.h>

namespace Kyber
{
// ClientServer
TL_DECLARE_FUNC(0x140BCF350, void, ServerLoadLevelMessage_post, LevelSetup* levelSetup, bool fadeOut, bool forceReloadResources);
TL_DECLARE_FUNC(0x14131AB20, void*, DirtySockSocketManager_ctor, void* inst, MemoryArena* arena, uint32_t maxPacketSize);
TL_DECLARE_FUNC(0x14193DA20, bool, Server_sendChatMessage, ChatChannel channel, const char* message, const ServerPlayer* player);
TL_DECLARE_FUNC(0x140C162F0, void, Server_setCompleted);

// Camera
TL_DECLARE_FUNC(0x140A7A990, __int64, ClientCameraViewManager_getActiveCameraTransform, void* inst, LinearTransform& transform);
TL_DECLARE_FUNC(0x14546A700, Camera*, ClientCameraViewManager_getActiveCamera, void* inst);

// Resource Manager
TL_DECLARE_FUNC(0x1454B93B0, void, ResourceRefResolver_addResourceRef, void* inst, ResourceRef* ref);
TL_DECLARE_FUNC(0x145494820, void, RuntimeDatabaseDomain_addResourceRefForResolve, void* inst, ResourceRef* ref);
TL_DECLARE_FUNC(0x140209310, DatabasePartition*, RuntimeDatabaseDomain_findPartitionFromGuidIncludingImports, void* inst, const Guid& guid);
TL_DECLARE_FUNC(0x140209140, DatabasePartition*, RuntimeDatabaseDomain_findPartitionContaining, void* inst, const DataContainer* container);
TL_DECLARE_FUNC(0x1454B82B0, DataContainer*, ResourceManager_lookupDataContainer, ResourceCompartment compartment, const char* name);
TL_DECLARE_FUNC(0x1402201F0, DataContainer*, ResourceManager_lookupDataContainerByHash, ResourceCompartment compartment, const Guid& guid, uint32_t partitionNameHash);
TL_DECLARE_FUNC(0x1454BA670, const char*, getCompartmentName, ResourceCompartment compartment);
TL_DECLARE_FUNC(0x1454B6AC0, void*, ResourceManager_getDomain, ResourceCompartment compartment);

// Filesystem
TL_DECLARE_FUNC(0x140241B30, void*, Win32FileSystem_ctor, void* inst, const char* basePath);
TL_DECLARE_FUNC(0x145488D60, void*, ExecutionContext_getVirtualFileSystem);
TL_DECLARE_FUNC(0x14023A210, void*, VirtualFileSystem_mount, void* inst, void* backend, const char* pathName);
TL_DECLARE_FUNC(0x140238C60, Win32Buffer*, VirtualFileSystem_createBuffer, void* inst, unsigned int bufferFlags, const char* pathName);
TL_DECLARE_FUNC(0x1401EF680, uint64_t, Buffer_readEx, void* inst, void* destination, int64_t byteCount);

// ECS
TL_DECLARE_FUNC(0x140CEF870, __int64, GameComponentEntity_externalSetWorldTransform, TypeObject* inst, const LinearTransform& transform, bool external);

// Network
TL_DECLARE_FUNC(0x146375820, void*, OnlineManager_clientConnection, void* inst);
TL_DECLARE_FUNC(0x1469F0180, float, ClientConnection_getAverageLatency, void* inst);

// Reflection
TL_DECLARE_FUNC(0x1453D5AB0, DataContainer*, DataContainerClassInfo_createInstance, const TypeInfo* type, MemoryArena* arena, bool a3, bool hasGuid);
TL_DECLARE_FUNC(0x1401F54A0, __int64, SettingsManager_add, void* inst, const char* groupName, void* instance, bool exposeToConsole,
    const char* metaString, TypeInfo* forcedType, char applySettings);
TL_DECLARE_FUNC(0x145456E80, __int64, StringBuilder_ctor, StringBuilder* inst, char* buffer, uint64_t size);
TL_DECLARE_FUNC(0x1401D76E0, __int64, TypeInfo_toString, const void* inst, void* stringBuilder, const void* data, void* params);
TL_DECLARE_FUNC(0x145440530, bool, ClassInfo_isKindOf, const TypeInfo* type, const TypeInfo* other);
TL_DECLARE_FUNC(0x1474D8510, void**, LinearTransform_copyCtor, const LinearTransform* inst, LinearTransform* other);

// Execution environment and related
TL_DECLARE_FUNC(0x140208C30, bool, ScriptContext_Impl_executeString, void* inst, const char* cmdString, int size, eastl::string* outErr);
TL_DECLARE_FUNC(0x145488820, char*, ExecutionContext_getOptionValue, const char* optionName, const char* defaultValue, int* token);

// Misc
TL_DECLARE_FUNC(0x14778DE50, char*, LocalizationManager_getString, const char* id, bool showLocalizationError);

inline bool ScriptContext_Impl_executeStringEasy(void* inst, const eastl::string& cmdString, eastl::string* outErr = nullptr)
{
    return ScriptContext_Impl_executeString(inst, cmdString.c_str(), cmdString.size(), outErr);
}

// Expensive! Searches all compartments, use only when necessary
DataContainer* ResourceManagerLookupDataContainer(const char* name);
} // namespace Kyber
