namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(SnitchSettings, 0x1445D3350);
_KB_DECLARE_TYPEINFO(LiveScoreboardProviderSettings, 0x1445D33D0);
_KB_DECLARE_TYPEINFO(DistroProviderSettings, 0x1445D3450);
_KB_DECLARE_TYPEINFO(StatsDProviderSettings, 0x1445D34D0);
_KB_DECLARE_TYPEINFO(ContactProviderSettings, 0x1445D3550);
_KB_DECLARE_TYPEINFO(LogTransmitterProviderSettings, 0x1445D35D0);
_KB_DECLARE_TYPEINFO(LiveScoreboardProviderDisableMessage, 0x1445D3650);
_KB_DECLARE_TYPEINFO(LiveScoreboardProviderEnableMessage, 0x1445D36A0);
_KB_DECLARE_TYPEINFO(MetricsProviderStringMetricMessage, 0x1445D36F0);
_KB_DECLARE_TYPEINFO(MetricsProviderCounterMetricMessage, 0x1445D3740);
_KB_DECLARE_TYPEINFO(MetricsProviderGaugeMetricMessage, 0x1445D3790);
_KB_DECLARE_TYPEINFO(MetricsProviderTagMetricMessage, 0x1445D37E0);
_KB_DECLARE_TYPEINFO(SnitchSettingsUpdatedMessage, 0x1445D3830);

#undef _KB_DECLARE_TYPEINFO
}
