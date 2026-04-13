namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(InputSettings, 0x14458AA70);
_KB_DECLARE_TYPEINFO(ClientInputRemotePadChangedMessage, 0x14458B430);
_KB_DECLARE_TYPEINFO(ClientInputSettingsRefreshMessage, 0x14458B480);
_KB_DECLARE_TYPEINFO(ClientInputUnchangedInputMessage, 0x14458B4D0);
_KB_DECLARE_TYPEINFO(InputMessagesResetJoystickSimValuesMessage, 0x14458B520);
_KB_DECLARE_TYPEINFO(InputMessagesKeyboardLayoutChangedMessage, 0x14458B570);
_KB_DECLARE_TYPEINFO(InputMessagesSingleInputEventMessage, 0x14458B5C0);
_KB_DECLARE_TYPEINFO(InputGraph, 0x14458AAF0);
_KB_DECLARE_TYPEINFO(EntryInputActionNodePorts, 0x14458B610);
_KB_DECLARE_TYPEINFO(InputConceptNodePorts, 0x14458B660);
_KB_DECLARE_TYPEINFO(InputConceptToEntryInputActionMappings, 0x14458AB70);
_KB_DECLARE_TYPEINFO(InputConceptToEntryInputActionMappingStruct, 0x14458B6B0);
_KB_DECLARE_TYPEINFO(InputDeviceKeys, 0x14458A830);
_KB_DECLARE_TYPEINFO(CursorStyle, 0x14458B3F0);
_KB_DECLARE_TYPEINFO(InputDeviceMouseButtons, 0x14458A870);
_KB_DECLARE_TYPEINFO(InputDeviceMotionControllerButtons, 0x14458A8B0);
_KB_DECLARE_TYPEINFO(InputDeviceWheelButtons, 0x14458A8F0);
_KB_DECLARE_TYPEINFO(InputDevicePadButtons, 0x14458A930);
_KB_DECLARE_TYPEINFO(InputDeviceAxes, 0x14458A970);
_KB_DECLARE_TYPEINFO(InputConfigurationAsset, 0x14458ABF0);
_KB_DECLARE_TYPEINFO(EditableActionMap, 0x14458B700);
_KB_DECLARE_TYPEINFO(InputActionMapsData, 0x14458AC70);
_KB_DECLARE_TYPEINFO(InputActionMapData, 0x14458ACF0);
_KB_DECLARE_TYPEINFO(InputActionsData, 0x14458AD70);
_KB_DECLARE_TYPEINFO(MessageInputActionData, 0x14458ADF0);
_KB_DECLARE_TYPEINFO(MouseInputActionData, 0x14458AE70);
_KB_DECLARE_TYPEINFO(KeyboardInputActionData, 0x14458AEF0);
_KB_DECLARE_TYPEINFO(WheelInputActionData, 0x14458AF70);
_KB_DECLARE_TYPEINFO(VrInputActionData, 0x14458AFF0);
_KB_DECLARE_TYPEINFO(MotionControllerInputActionData, 0x14458B070);
_KB_DECLARE_TYPEINFO(JoystickInputActionData, 0x14458B0F0);
_KB_DECLARE_TYPEINFO(PadInputActionData, 0x14458B170);
_KB_DECLARE_TYPEINFO(AxesInputActionData, 0x14458B1F0);
_KB_DECLARE_TYPEINFO(InputActionData, 0x14458B270);
_KB_DECLARE_TYPEINFO(InputActionMapSlot, 0x14458A9B0);
_KB_DECLARE_TYPEINFO(InputActionMapPlatform, 0x14458A9F0);
_KB_DECLARE_TYPEINFO(EntryInputActionBindingsData, 0x14458B2F0);
_KB_DECLARE_TYPEINFO(EntryInputActionBinding, 0x14458B750);
_KB_DECLARE_TYPEINFO(EntryInputActionType, 0x14458AA30);
_KB_DECLARE_TYPEINFO(EntryInputActionIndexPair, 0x14458B7A0);
_KB_DECLARE_TYPEINFO(BaseInputSettings, 0x14458B370);

#undef _KB_DECLARE_TYPEINFO
}
