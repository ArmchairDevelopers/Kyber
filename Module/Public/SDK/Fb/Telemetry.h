namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(TransactionalTelemetryHookEntity, 0x1445F2150);
_KB_DECLARE_TYPEINFO(TelemetryHookEntity, 0x1445F2220);
_KB_DECLARE_TYPEINFO(TelemetryGenericHookEntity, 0x1445F22F0);
_KB_DECLARE_TYPEINFO(FixedStreamTelemetryHookEntity, 0x1445F23C0);
_KB_DECLARE_TYPEINFO(TransactionalTelemetryStream, 0x1445F1FD0);
_KB_DECLARE_TYPEINFO(TelemetryStream, 0x1445F2050);
_KB_DECLARE_TYPEINFO(EventTelemetryStream, 0x1445F20D0);
_KB_DECLARE_TYPEINFO(VarStreamTelemetryHookEntity, 0x1445F19F0);

#undef _KB_DECLARE_TYPEINFO
}
