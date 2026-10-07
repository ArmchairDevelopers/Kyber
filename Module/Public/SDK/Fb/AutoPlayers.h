namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(AutoPlayerActionObjectiveEntity, 0x1444006F0);
_KB_DECLARE_TYPEINFO(AutoPlayerListenerEntity, 0x1444007C0);
_KB_DECLARE_TYPEINFO(AutoPlayerObjectiveEntityData, 0x144400280);
_KB_DECLARE_TYPEINFO(AutoPlayerMoveMode, 0x144400240);
_KB_DECLARE_TYPEINFO(AutoPlayerMoveObjectiveEntityData, 0x144400300);
_KB_DECLARE_TYPEINFO(AutoPlayerInteractObjectiveEntityData, 0x144400380);
_KB_DECLARE_TYPEINFO(AutoPlayerFollowObjectiveEntityData, 0x144400400);
_KB_DECLARE_TYPEINFO(AutoPlayerDefendObjectiveEntityData, 0x144400480);
_KB_DECLARE_TYPEINFO(AutoPlayerAttackObjectiveEntityData, 0x144400500);
_KB_DECLARE_TYPEINFO(AutoPlayerActionObjectiveEntityData, 0x1443FF480);
_KB_DECLARE_TYPEINFO(AutoPlayerSettingsEntityData, 0x1443FF500);
_KB_DECLARE_TYPEINFO(AutoPlayerSettingsChoice, 0x1443FF430);
_KB_DECLARE_TYPEINFO(AutoPlayerSettingsKind, 0x1443FF3F0);
_KB_DECLARE_TYPEINFO(AutoPlayerManagerEntityData, 0x1443FF580);
_KB_DECLARE_TYPEINFO(AutoPlayerEntityData, 0x1443FF600);
_KB_DECLARE_TYPEINFO(AutoPlayerSettings, 0x1443FF680);
_KB_DECLARE_TYPEINFO(ServerAutoPlayerSettingsEntity, 0x1443FF700);
_KB_DECLARE_TYPEINFO(ServerAutoPlayerManagerEntity, 0x1443FF7D0);
_KB_DECLARE_TYPEINFO(AutoPlayerObjectiveEntityBase, 0x1443FF8A0);
_KB_DECLARE_TYPEINFO(AutoPlayerMoveObjectiveEntity, 0x1443FF970);
_KB_DECLARE_TYPEINFO(AutoPlayerInteractObjectiveEntity, 0x1443FFA40);
_KB_DECLARE_TYPEINFO(AutoPlayerFollowObjectiveEntity, 0x1443FFB10);
_KB_DECLARE_TYPEINFO(AutoPlayerDefendObjectiveEntity, 0x1443FFBE0);
_KB_DECLARE_TYPEINFO(AutoPlayerAttackObjectiveEntity, 0x1443FFCB0);

#undef _KB_DECLARE_TYPEINFO
}
