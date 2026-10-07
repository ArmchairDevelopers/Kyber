namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LinearMediaSettings, 0x1445326D0);
_KB_DECLARE_TYPEINFO(LinearMediaAssetDesc, 0x144532750);
_KB_DECLARE_TYPEINFO(LinearMediaRuntimeResource, 0x144532810);
_KB_DECLARE_TYPEINFO(LinearMediaPipelineAssetDescAttributeSamplingRate, 0x1445327D0);
_KB_DECLARE_TYPEINFO(LinearMediaChannelRuntime, 0x1445328E0);
_KB_DECLARE_TYPEINFO(LinearMediaAsset, 0x144532860);

#undef _KB_DECLARE_TYPEINFO
}
