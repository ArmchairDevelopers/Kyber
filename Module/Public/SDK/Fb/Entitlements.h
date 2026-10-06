namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(PresenceLicenseRequestMessageBase, 0x14473DAA0);
_KB_DECLARE_TYPEINFO(PresenceLicenseMessageBase, 0x14473DAF0);
_KB_DECLARE_TYPEINFO(LicenseConfiguration, 0x14473DB40);
_KB_DECLARE_TYPEINFO(LicenseInfo, 0x14473DB90);
_KB_DECLARE_TYPEINFO(NucleusEntitlementInfo, 0x14473DBE0);
_KB_DECLARE_TYPEINFO(EntitlementsServerBackendData, 0x14473D0A0);
_KB_DECLARE_TYPEINFO(EntitlementsBackendData, 0x14473D120);
_KB_DECLARE_TYPEINFO(EntitlementSettings, 0x14473D1A0);
_KB_DECLARE_TYPEINFO(EntitlementSettingsAsset, 0x14473D220);
_KB_DECLARE_TYPEINFO(EntitlementPlatformToProjectId, 0x14473D320);
_KB_DECLARE_TYPEINFO(EntitlementConfigData, 0x14473D000);
_KB_DECLARE_TYPEINFO(EntitlementOriginConfigData, 0x14473D050);
_KB_DECLARE_TYPEINFO(EntitlementGroup, 0x14473D370);
_KB_DECLARE_TYPEINFO(EntitlementInfo, 0x14473D3C0);
_KB_DECLARE_TYPEINFO(PresenceEntitlementsServiceData, 0x14473D2A0);
_KB_DECLARE_TYPEINFO(ServerEntitlementsBackend, 0x14473D610);
_KB_DECLARE_TYPEINFO(PresenceGetNucleusEntitlementsRequestParameters, 0x14473D410);
_KB_DECLARE_TYPEINFO(PresenceGrantNucleusEntitlementRequestParameters, 0x14473D490);
_KB_DECLARE_TYPEINFO(PresenceGetOriginEntitlementsRequestParameters, 0x14473D510);
_KB_DECLARE_TYPEINFO(PresenceGetFirstPartyEntitlementsRequestParameters, 0x14473D690);
_KB_DECLARE_TYPEINFO(LicenseMappingEvent, 0x14473D590);
_KB_DECLARE_TYPEINFO(ClientEntitlementsService, 0x14473D710);
_KB_DECLARE_TYPEINFO(ClientEntitlementsBackend, 0x14473D790);

#undef _KB_DECLARE_TYPEINFO
}
