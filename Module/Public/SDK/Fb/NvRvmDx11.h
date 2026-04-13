namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(Dx11NvDrawStateFTInstructionFactory, 0x1445917F0);
_KB_DECLARE_TYPEINFO(Dx11NvViewStateFTInstructionFactory, 0x144591870);
_KB_DECLARE_TYPEINFO(Dx11NvDrawStateDepthInstructionFactory, 0x1445918F0);
_KB_DECLARE_TYPEINFO(Dx11NvViewStateDepthInstructionFactory, 0x144591970);
_KB_DECLARE_TYPEINFO(RvmSerializedDb_ns_Dx11NvViewStateDepthInstructionData, 0x143FE9130);
_KB_DECLARE_TYPEINFO(RvmSerializedDb_ns_Dx11NvDrawStateInstructionData, 0x143FE9060);
_KB_DECLARE_TYPEINFO(RvmSerializedDb_ns_Dx11NvViewStateInstructionData, 0x143FE8F90);
_KB_DECLARE_TYPEINFO(Dx11NvRvmBackendConfig, 0x1445916F0);
_KB_DECLARE_TYPEINFO(Dx11NvRvmDatabaseLoader, 0x1445919F0);
_KB_DECLARE_TYPEINFO(Dx11NvRvmDatabase, 0x144591770);

#undef _KB_DECLARE_TYPEINFO
}
