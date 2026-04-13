namespace Kyber
{
class TypeInfo;
#define _KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

_KB_DECLARE_TYPEINFO(ServerCreatureFollowWaypointsEntity, 0x14442CEB0);
_KB_DECLARE_TYPEINFO(ServerCreatureFollowWaypointSegmentEntity, 0x14442CF80);
_KB_DECLARE_TYPEINFO(ServerCreatureCollisionGroupEntity, 0x14442D050);
_KB_DECLARE_TYPEINFO(IMovementProvider, 0x14442D120);
_KB_DECLARE_TYPEINFO(ISteeringProvider, 0x14442D1A0);
_KB_DECLARE_TYPEINFO(CreatureWaypoint_PlayAnimation, 0x14442D220);
_KB_DECLARE_TYPEINFO(CreatureWaypoint_Pause, 0x14442D2A0);
_KB_DECLARE_TYPEINFO(CreatureWaypoint, 0x14442D320);
_KB_DECLARE_TYPEINFO(CL_ProceduralMotion, 0x14442D3A0);
_KB_DECLARE_TYPEINFO(CL_CurveSteering, 0x14442CE30);
_KB_DECLARE_TYPEINFO(CLColAvoidingSteering, 0x14442D420);
_KB_DECLARE_TYPEINFO(IAssessor, 0x14442D4A0);
_KB_DECLARE_TYPEINFO(CLClientState, 0x14442C410);
_KB_DECLARE_TYPEINFO(CLState, 0x14442C490);
_KB_DECLARE_TYPEINFO(CLConduitState, 0x14442C510);
_KB_DECLARE_TYPEINFO(ClientCreatureSpawnEntity, 0x14442C270);
_KB_DECLARE_TYPEINFO(ServerCreatureSpawnEntity, 0x14442C340);
_KB_DECLARE_TYPEINFO(CreatureLocoEntity, 0x14442B100);
_KB_DECLARE_TYPEINFO(CreatureFollowWaypointUnspawnEntity, 0x14442B510);
_KB_DECLARE_TYPEINFO(CreatureFollowBaseEntity, 0x14442B1D0);
_KB_DECLARE_TYPEINFO(ServerCreatureFollowWaypointProviderEntity, 0x14442B5E0);
_KB_DECLARE_TYPEINFO(ClientCreatureFollowWaypointProviderEntity, 0x14442B6B0);
_KB_DECLARE_TYPEINFO(CreatureFollowWaypointClosestChooserEntity, 0x14442B780);
_KB_DECLARE_TYPEINFO(CreatureFollowWaypointOccupancyChooserEntity, 0x14442B850);
_KB_DECLARE_TYPEINFO(CreatureFollowWaypointBoolChooserEntity, 0x14442B920);
_KB_DECLARE_TYPEINFO(CreatureConfigurationProviderEntity, 0x14442B2A0);
_KB_DECLARE_TYPEINFO(CreatureBaseWaypointProviderEntity, 0x14442B370);
_KB_DECLARE_TYPEINFO(CLInfluenceFilterEntity, 0x14442B440);
_KB_DECLARE_TYPEINFO(CLInfluenceCompareEntity, 0x14442B9F0);
_KB_DECLARE_TYPEINFO(CLApplyInfluenceEntity, 0x14442BAC0);
_KB_DECLARE_TYPEINFO(ClientCreatureLocoMotorEntity, 0x14442BB90);
_KB_DECLARE_TYPEINFO(ClientCreatureFollowWaypointsEntity, 0x14442BC60);
_KB_DECLARE_TYPEINFO(ClientCreatureFollowWaypointSegmentEntity, 0x14442BD30);
_KB_DECLARE_TYPEINFO(ClientCreatureCollisionGroupEntity, 0x14442BE00);
_KB_DECLARE_TYPEINFO(CreatureSpawnEntityData, 0x14442A370);
_KB_DECLARE_TYPEINFO(ServerCreatureLocoMotorEntity, 0x14442A3F0);

#undef _KB_DECLARE_TYPEINFO
}
