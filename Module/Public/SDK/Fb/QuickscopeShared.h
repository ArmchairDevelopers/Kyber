namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(QuickscopeControlEntityData, 0x1445AE730);
_KB_DECLARE_TYPEINFO(QuickscopeTest, 0x1445AE7B0);
_KB_DECLARE_TYPEINFO(QuickscopeBudgetsAsset, 0x1445AE830);
_KB_DECLARE_TYPEINFO(QuickscopeBudgetEntry, 0x1445AE9B0);
_KB_DECLARE_TYPEINFO(QuickscopePlatformValue, 0x1445AEA00);
_KB_DECLARE_TYPEINFO(QuickscopePlatform, 0x1445AE670);
_KB_DECLARE_TYPEINFO(QuickscopeCategoriesAsset, 0x1445AE8B0);
_KB_DECLARE_TYPEINFO(QuickscopeCategory, 0x1445AEA50);
_KB_DECLARE_TYPEINFO(QuickscopeLevelData, 0x1445AE930);
_KB_DECLARE_TYPEINFO(QuickscopeProcessorType, 0x1445AE6B0);
_KB_DECLARE_TYPEINFO(QuickscopeFrameType, 0x1445AE6F0);

#undef _KB_DECLARE_TYPEINFO
}
