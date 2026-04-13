namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(LuaRunnerSharedVarsEntity, 0x1445907B0);
_KB_DECLARE_TYPEINFO(LuaRunnerScriptEntity, 0x1445906E0);
_KB_DECLARE_TYPEINFO(CompiledLuaResource, 0x144590660);
_KB_DECLARE_TYPEINFO(LuaRunnerSharedVarsEntityData, 0x144590260);
_KB_DECLARE_TYPEINFO(LuaRunnerScriptEntityData, 0x1445902E0);
_KB_DECLARE_TYPEINFO(CustomProperty, 0x1445903E0);
_KB_DECLARE_TYPEINFO(ExecuteOnPropertyChangeType, 0x144590220);
_KB_DECLARE_TYPEINFO(LuaRunnerCompiledLua, 0x144590360);

#undef _KB_DECLARE_TYPEINFO
}
