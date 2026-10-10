namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(MonitorNodeConfigData, 0x1443FE730);
_KB_DECLARE_TYPEINFO(MonitorNodeData, 0x1443FE7B0);
_KB_DECLARE_TYPEINFO(MonitoredNodeMetaData, 0x1443FE8F0);
_KB_DECLARE_TYPEINFO(MonitoredNodePortMetaData, 0x1443FE940);
_KB_DECLARE_TYPEINFO(MonitoredNodePortType, 0x1443FE830);
_KB_DECLARE_TYPEINFO(MonitoringSortType, 0x1443FE870);
_KB_DECLARE_TYPEINFO(DebugRenderingSelection, 0x1443FE8B0);

#undef _KB_DECLARE_TYPEINFO
}
