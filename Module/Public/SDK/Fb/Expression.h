namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ExpressionConstantEmptyArrayPatch, 0x144587E40);
_KB_DECLARE_TYPEINFO(ExpressionConstantReferencePatch, 0x144587E90);
_KB_DECLARE_TYPEINFO(ExpressionNopPatch, 0x144587EE0);
_KB_DECLARE_TYPEINFO(ExpressionStateData, 0x144587F30);
_KB_DECLARE_TYPEINFO(ExpressionPropertyData, 0x144587F80);
_KB_DECLARE_TYPEINFO(ExpressionPortData, 0x144587FD0);
_KB_DECLARE_TYPEINFO(ExpressionPortDirection, 0x144587D00);
_KB_DECLARE_TYPEINFO(ExpressionNodeGraphData, 0x144587D40);
_KB_DECLARE_TYPEINFO(ReferencedType, 0x144588020);
_KB_DECLARE_TYPEINFO(ExpressionFunctionTypeInfoAsset, 0x144587DC0);
_KB_DECLARE_TYPEINFO(SerializedExpressionNodeGraph, 0x144588070);
_KB_DECLARE_TYPEINFO(ExpressionRuntimeContext, 0x1445880F0);

#undef _KB_DECLARE_TYPEINFO
}
