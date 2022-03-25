// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <stddef.h>

namespace Kyber
{
enum ClientState
{
    ClientState_WaitingForStaticBundleLoad,

    ClientState_LoadProfileOptions,
    ClientState_LostConnection,
    ClientState_WaitingForUnload,
    ClientState_Startup,
    ClientState_StartServer,

    ClientState_WaitingForLevel,
    ClientState_StartLoadingLevel,
    ClientState_WaitingForLevelLoaded,
    ClientState_WaitingForLevelLink,
    ClientState_LevelLinked,
    ClientState_WaitingForGhosts,

    ClientState_Ingame,
    ClientState_LeaveIngame,

    ClientState_ConnectToServer,

    ClientState_ShuttingDown,
    ClientState_Shutdown,

    ClientState_None,
};
enum SecureReason
{
    SecureReason_Ok,
    SecureReason_WrongProtocolVersion,
    SecureReason_WrongTitleVersion,
    SecureReason_ServerFull,
    SecureReason_KickedOut,
    SecureReason_Banned,
    SecureReason_GenericError,
    SecureReason_WrongPassword,
    SecureReason_MissingContent,
    SecureReason_NotVerified,
    SecureReason_TimedOut,
    SecureReason_ConnectFailed,
    SecureReason_NoReply,
    SecureReason_AcceptFailed,
    SecureReason_MismatchingContent,
    SecureReason_MalformedPacket,
    SecureReason_SendFail,
    SecureReason_ConnectionHandshaking,
    SecureReason_DuplicateConnection,

    SecureReason_InteractivityTimeout,
    SecureReason_KickedFromQueue,
    SecureReason_TeamKills,
    SecureReason_KickedByAdmin,
    SecureReason_KickedViaPunkBuster,
    SecureReason_KickedOutServerFull,
    SecureReason_ESportsMatchStarting,
    SecureReason_NotInESportsRosters,
    SecureReason_ESportsMatchEnding,
    SecureReason_VirtualServerExpired,
    SecureReason_VirtualServerRecreate,
    SecureReason_ESportsTeamFull,
    SecureReason_ESportsMatchAborted,
    SecureReason_ESportsMatchWalkover,
    SecureReason_ESportsMatchWarmupTimedOut,
    SecureReason_NotAllowedToSpectate,
    SecureReason_NoSpectateSlotAvailable,
    SecureReason_InvalidSpectateJoin,
    SecureReason_KickedViaFairFight,
    SecureReason_KickedCommanderOnLeave,
    SecureReason_KickedCommanderAfterMutiny,
    SecureReason_ServerMaintenance,
    SecureReason_KickedOutDemoOver,
    SecureReason_RankRestricted,
    SecureReason_ConfigurationNotAllowed,
    SecureReason_ServerReclaimed,

    SecureReason_PlayerRemoveTimedOut,
    SecureReason_PlayerRemovePoorQuality,
    SecureReason_PlayerRemovedConnLost,
    SecureReason_PlayerRemovedBlazeserverConnLost,
    SecureReason_PlayerRemovedMigrationFailed,
    SecureReason_PlayerRemovedGameDestroyed,
    SecureReason_PlayerRemovedQueueFailed,
    SecureReason_PlayerRemovedExternalSessionFailed,
    SecureReason_HostDisbandedGroup,
    SecureReason_PersistenceDownloadFailed,

    SecureReason_ClientInactivity,
    SecureReason_TrialExpired,
    SecureReason_TrialUpgraded
};
class DataContainer
{
public:
    char _0x000[24]; // 0x0000
};
enum GamePlatform
{
    GamePlatform_Win32,   // 0x0000
    GamePlatform_Gen4a,   // 0x0001
    GamePlatform_Gen4b,   // 0x0002
    GamePlatform_Android, // 0x0003
    GamePlatform_iOS,     // 0x0004
    GamePlatform_OSX,     // 0x0005
    GamePlatform_Linux,   // 0x0006
    GamePlatform_Any,     // 0x0007
    GamePlatform_Invalid, // 0x0008
    GamePlatformCount     // 0x0009
};
class SystemSettings : public DataContainer
{
public:
    GamePlatform Platform; // 0x0018
    char _0x001C[4];       // 0x001C
};
enum LogFileCollisionMode
{
    LFCM_Overwrite, // 0x0000
    LFCM_Rotate,    // 0x0001
    LFCM_TimeStamp  // 0x0002
};
enum TeamId
{
    TeamNeutral, // 0x0000
    Team1,       // 0x0001
    Team2,       // 0x0002
    Team3,       // 0x0003
    Team4,       // 0x0004
    Team5,       // 0x0005
    Team6,       // 0x0006
    Team7,       // 0x0007
    Team8,       // 0x0008
    Team9,       // 0x0009
    Team10,      // 0x000A
    Team11,      // 0x000B
    Team12,      // 0x000C
    Team13,      // 0x000D
    Team14,      // 0x000E
    Team15,      // 0x000F
    Team16,      // 0x0010
    TeamIdCount  // 0x0011
};
class Asset : public DataContainer
{
public:
    char* Name; // 0x0018
};
enum LocalPlayerViewId
{
    LocalPlayerViewId_RootView,  // 0x0000
    LocalPlayerViewId_Secondary, // 0x0001
    LocalPlayerViewId_Custom1,   // 0x0002
    LocalPlayerViewId_Custom2,   // 0x0003
    LocalPlayerViewId_Custom3,   // 0x0004
    LocalPlayerViewId_Custom4,   // 0x0005
    LocalPlayerViewId_Count      // 0x0006
};
enum ViewDefinitionType
{
    ViewType_FullScreen,                  // 0x0000
    ViewType_AutoVerticalSplit,           // 0x0001
    ViewType_AutoFullHorizontalSplit,     // 0x0002
    ViewType_AutoOffsetedHorizontalSplit, // 0x0003
    ViewType_AutoQuadrant,                // 0x0004
    ViewType_Custom                       // 0x0005
};
struct ViewDefinition
{
    LocalPlayerViewId ViewId;    // 0x0000
    ViewDefinitionType ViewType; // 0x0004
    uint32_t ScreenIndex;        // 0x0008
    float OffsetX;               // 0x000C
    float OffsetY;               // 0x0010
    float Width;                 // 0x0014
    float Height;                // 0x0018
    float FovScale;              // 0x001C
    bool NormalizedSize;         // 0x0020
    char _0x0021[3];             // 0x0021
};
enum LocalPlayerId
{
    LocalPlayerId_0,      // 0x0000
    LocalPlayerId_1,      // 0x0001
    LocalPlayerId_2,      // 0x0002
    LocalPlayerId_3,      // 0x0003
    LocalPlayerId_4,      // 0x0004
    LocalPlayerId_5,      // 0x0005
    LocalPlayerId_6,      // 0x0006
    LocalPlayerId_7,      // 0x0007
    LocalPlayerId_Any,    // 0x0008
    LocalPlayerId_All,    // 0x0009
    LocalPlayerId_Invalid // 0x000A
};
struct PlayerViewDefinition
{
    ViewDefinition* Views;       // 0x0000
    LocalPlayerId LocalPlayerId; // 0x0008
    char _0x000C[4];             // 0x000C
};
class GameModeViewDefinition : public Asset
{
public:
    char* GameModeName;                    // 0x0020
    PlayerViewDefinition* ViewDefinitions; // 0x0028
};
class GameSettingsComponent : public Asset
{};
class VersionData : public Asset
{
public:
    char* disclaimer;   // 0x0020
    int32_t Version;    // 0x0028
    char _0x002C[4];    // 0x002C
    char* DateTime;     // 0x0030
    char* BranchId;     // 0x0038
    char* DataBranchId; // 0x0040
    char* GameName;     // 0x0048
};
class SubWorldInclusionCriterion : public DataContainer
{
public:
    char** Options; // 0x0018
    char* Name;     // 0x0020
};
class SubWorldInclusion : public Asset
{
public:
    SubWorldInclusionCriterion** Criteria; // 0x0020
};
class SubViewData : public DataContainer
{};
class PlayerViewData : public DataContainer
{
public:
    SubViewData** SubViews; // 0x0018
};
class PlayerData : public Asset
{
public:
    PlayerViewData* PlayerView; // 0x0020
};
class GameSettings : public SystemSettings
{
public:
    uint32_t MaxPlayerCount;                          // 0x0020
    char _0x0024[4];                                  // 0x0024
    GameModeViewDefinition** GameModeViewDefinitions; // 0x0028
    VersionData* Version;                             // 0x0030
    SubWorldInclusion* SubWorldInclusion;             // 0x0038
    PlayerData* Player;                               // 0x0040
    GameSettingsComponent** GameSettingsComponents;   // 0x0048
    uint32_t MaxSpectatorCount;                       // 0x0050
    LogFileCollisionMode LogFileCollisionMode;        // 0x0054
    uint32_t LogFileRotationHistoryLength;            // 0x0058
    char _0x005C[4];                                  // 0x005C
    char* Level;                                      // 0x0060
    char* StartPoint;                                 // 0x0068
    char* InstallationLevel;                          // 0x0070
    char* InstallationStartPoint;                     // 0x0078
    char* InstallationDefaultLayerInclusion;          // 0x0080
    char* ActiveGameModeViewDefinition;               // 0x0088
    TeamId DefaultTeamId;                             // 0x0090
    char _0x0094[4];                                  // 0x0094
    char* DefaultLayerInclusion;                      // 0x0098
    float TimeToWaitForQuitTaskCompletion;            // 0x00A0
    int32_t DifficultyIndex;                          // 0x00A4
    bool LogFileEnable;                               // 0x00A8
    bool ResourceRefreshAlwaysAllowed;                // 0x00A9
    bool SpawnMaxLocalPlayersOnStartup;               // 0x00AA
    char _0x00AB[5];                                  // 0x00AB
};
class NetworkSettings : public SystemSettings
{
public:
    uint32_t ProtocolVersion;                        // 0x0020
    char _0x0024[4];                                 // 0x0024
    char* TitleId;                                   // 0x0028
    uint32_t ClientPort;                             // 0x0030
    uint32_t ServerPort;                             // 0x0034
    uint32_t MaxGhostCount;                          // 0x0038
    uint32_t MaxClientToServerGhostCount;            // 0x003C
    uint32_t MaxClientCount;                         // 0x0040
    uint32_t MaxClientFrameSize;                     // 0x0044
    uint32_t MaxServerFrameSize;                     // 0x0048
    uint32_t MaxNumVoipPeers;                        // 0x004C
    char* ServerAddress;                             // 0x0050
    char* ClientConnectionDebugFilePrefix;           // 0x0058
    char* ServerConnectionDebugFilePrefix;           // 0x0060
    float SinglePlayerTimeNudgeBias;                 // 0x0068
    float SinglePlayerTimeNudge;                     // 0x006C
    float MemorySocketTimeNudgeBias;                 // 0x0070
    float MemorySocketTimeNudge;                     // 0x0074
    float LocalHostTimeNudgeBias;                    // 0x0078
    float LocalHostTimeNudge;                        // 0x007C
    float DefaultTimeNudgeBias;                      // 0x0080
    float DefaultTimeNudge;                          // 0x0084
    float ConnectTimeout;                            // 0x0088
    float PacketLossLogInterval;                     // 0x008C
    uint32_t ValidLocalPlayersMask;                  // 0x0090
    uint32_t DesiredLocalPlayersMask;                // 0x0094
    uint32_t PersistentLocalPlayersMask;             // 0x0098
    uint32_t SinglePlayerMaxMessagesPerNetworkFrame; // 0x009C
    uint32_t MaxMessagesPerNetworkFrame;             // 0x00A0
    bool SinglePlayerAutomaticTimeNudge;             // 0x00A4
    bool MemorySocketAutomaticTimeNudge;             // 0x00A5
    bool LocalHostAutomaticTimeNudge;                // 0x00A6
    bool DefaultAutomaticTimeNudge;                  // 0x00A7
    bool IncrementServerPortOnFail;                  // 0x00A8
    bool UseFrameManager;                            // 0x00A9
    bool TimeSyncEnabled;                            // 0x00AA
    bool MLUREnabled;                                // 0x00AB
    char _0x00AC[4];                                 // 0x00AC
};
struct Guid
{
    uint32_t data1;
    uint16_t data2;
    uint16_t data3;
    uint8_t data4[8];
};
class ClientSettings : public SystemSettings
{
public:
    Guid AudioSystemGuid;               // 0x0020
    char* ScreenshotFilename;           // 0x0030
    char* ScreenshotSuffix;             // 0x0038
    uint32_t Team;                      // 0x0040
    int32_t SpawnPointIndex;            // 0x0044
    char* ServerIp;                     // 0x0048
    char* SecondaryServerIp;            // 0x0050
    float AimScale;                     // 0x0058
    float IncomingFrequency;            // 0x005C
    float OutgoingFrequency;            // 0x0060
    uint32_t IncomingRate;              // 0x0064
    uint32_t OutgoingRate;              // 0x0068
    float LoadingTimeout;               // 0x006C
    float LoadedTimeout;                // 0x0070
    float IngameTimeout;                // 0x0074
    float CpuQuality;                   // 0x0078
    char _0x007C[4];                    // 0x007C
    char* InstancePath;                 // 0x0080
    float FrameHistoryTimeWarnScale;    // 0x0088
    bool IsSpectator;                   // 0x008C
    bool AllowVideoRecording;           // 0x008D
    bool DebrisClusterEnabled;          // 0x008E
    bool VegetationEnabled;             // 0x008F
    bool ForceEnabled;                  // 0x0090
    bool WorldRenderEnabled;            // 0x0091
    bool TerrainEnabled;                // 0x0092
    bool WaterPhysicsEnabled;           // 0x0093
    bool OvergrowthEnabled;             // 0x0094
    bool EffectsEnabled;                // 0x0095
    bool AutoIncrementPadIndex;         // 0x0096
    bool LipSyncEnabled;                // 0x0097
    bool PauseGameOnStartUp;            // 0x0098
    bool SkipFastLevelLoad;             // 0x0099
    bool ScreenshotToFile;              // 0x009A
    bool LoadMenu;                      // 0x009B
    bool DebugMenuOnLThumb;             // 0x009C
    bool ScreenshotComparisonsEnable;   // 0x009D
    bool RenderTags;                    // 0x009E
    bool Scheme0FlipY;                  // 0x009F
    bool Scheme1FlipY;                  // 0x00A0
    bool Scheme2FlipY;                  // 0x00A1
    bool HavokVisualDebugger;           // 0x00A2
    bool HavokCaptureToFile;            // 0x00A3
    bool ShowBuildId;                   // 0x00A4
    bool ExtractPersistenceInformation; // 0x00A5
    bool EnableRestTool;                // 0x00A6
    bool LocalVehicleSimulationEnabled; // 0x00A7
    bool AutoUnspawnDynamicObjects;     // 0x00A8
    bool QuitGameOnServerDisconnect;    // 0x00A9
    bool LuaOptionSetEnable;            // 0x00AA
    bool FastExit;                      // 0x00AB
    char _0x00AC[4];                    // 0x00AC
};
class WSGameSettings : public SystemSettings
{
public:
    char* ReleaseVersionName;                     // 0x0020
    float RestartCooldown;                        // 0x0028
    float PostSpawnRestartCooldown;               // 0x002C
    float NoInteractivityTimeoutTime;             // 0x0030
    float NoInteractivityThresholdLimit;          // 0x0034
    float PrivateMatchNoInteractivityTimeoutTime; // 0x0038
    int32_t PreferredTeam;                        // 0x003C
    char* PlayerName;                             // 0x0040
    int32_t LevelLightingOverride;                // 0x0048
    float ObjectiveDamageScale;                   // 0x004C
    int32_t TicketLossScale;                      // 0x0050
    int32_t LobbyThreshold;                       // 0x0054
    int32_t MaxTeamSizeDifference;                // 0x0058
    int32_t EventWelcomeTimer;                    // 0x005C
    int32_t MaximumBattlepoints;                  // 0x0060
    bool SupportsDebugging;                       // 0x0064
    bool Is2PlayersCoop;                          // 0x0065
    bool ForceThirdPerson;                        // 0x0066
    bool EnableMaxRegenerationLimit;              // 0x0067
    bool SkipLobby;                               // 0x0068
    bool DisableHeroDebugMenu;                    // 0x0069
    bool ForcePrivateMatchLobby;                  // 0x006A
    bool StopEOR;                                 // 0x006B
    bool DisableStartupFlow;                      // 0x006C
    bool AutoBalanceTeamsOnNeutral;               // 0x006D
    char _0x006E[2];                              // 0x006E
};
class AutoPlayerSettings : public SystemSettings
{
public:
    float AFKTakeover;                                           // 0x0020
    int32_t PlayerCount;                                         // 0x0024
    int32_t ForcedServerAutoPlayerCount;                         // 0x0028
    int32_t ForceFillGameplayBotsTeam1;                          // 0x002C
    int32_t ForceFillGameplayBotsTeam2;                          // 0x0030
    float RespawnDelay;                                          // 0x0034
    float InitialRespawnDelay;                                   // 0x0038
    float ClientJoinDelay;                                       // 0x003C
    int32_t RoundTimeout;                                        // 0x0040
    int32_t SquadMembers;                                        // 0x0044
    int32_t PickupItemsSecondaryObjectiveAttemptIntervalSeconds; // 0x0048
    float PlannerTerrainVerticalCutoff;                          // 0x004C
    float PlannerConnectionCutoff;                               // 0x0050
    float PlannerMaxNodesSearchRadius;                           // 0x0054
    float PlannerLinkEndArrivalRange;                            // 0x0058
    float InputScaleYaw;                                         // 0x005C
    float InputScalePitch;                                       // 0x0060
    float InputScaleClient;                                      // 0x0064
    float InputOverrideYaw;                                      // 0x0068
    float InputOverridePitch;                                    // 0x006C
    float AimAcceleration;                                       // 0x0070
    float AimLapTime;                                            // 0x0074
    float LofTimeoutS;                                           // 0x0078
    float LofReactionTimeS;                                      // 0x007C
    int32_t ForceKit;                                            // 0x0080
    float SquadSpawnProbability;                                 // 0x0084
    float KitChangeProbability;                                  // 0x0088
    float UseDefaultUnlocksProbability;                          // 0x008C
    float WeaponSwapIntervalS;                                   // 0x0090
    float WeaponSwapPrimaryProbability;                          // 0x0094
    int32_t VehicleBailTime;                                     // 0x0098
    float JumpIfStuckTimeSeconds;                                // 0x009C
    float JumpCooldownSeconds;                                   // 0x00A0
    float PatrolPositionCooldownSeconds;                         // 0x00A4
    float ForcedFireTimeMaxS;                                    // 0x00A8
    float ForcedFireTimeMinS;                                    // 0x00AC
    float ForcedFireVehicleTimeScale;                            // 0x00B0
    float ExitVehicleWhenStuckTimeout;                           // 0x00B4
    float MinDistanceForVehicleUTurn;                            // 0x00B8
    int32_t MinAirplaneBailOutTime;                              // 0x00BC
    int32_t MaxAirplaneBailOutTime;                              // 0x00C0
    float LoginRate;                                             // 0x00C4
    float SpawnRate;                                             // 0x00C8
    int32_t MaxSpawnsPerUpdate;                                  // 0x00CC
    float Variance;                                              // 0x00D0
    int32_t AirplaneExitInput;                                   // 0x00D4
    float SecondaryObjectiveGenerationMinSeconds;                // 0x00D8
    float SecondaryObjectiveGenerationMaxSeconds;                // 0x00DC
    float EnterVehicleCooldownSeconds;                           // 0x00E0
    float EnterVehicleProbability;                               // 0x00E4
    float EnterVehicleSearchRadius;                              // 0x00E8
    float SecondaryObjectiveTimeoutSeconds;                      // 0x00EC
    float FortificationProbability;                              // 0x00F0
    float FortificationSearchRadius;                             // 0x00F4
    float RepathCooldownSeconds;                                 // 0x00F8
    float UnStuckVehicleActionsTriggerTimeSeconds;               // 0x00FC
    float UnstuckMinimalMoveDistance;                            // 0x0100
    float UnstuckMinimalMoveSuicideTimeout;                      // 0x0104
    float FallenBelowSuicideTimeout;                             // 0x0108
    float NavigationPositionToleranceMeters;                     // 0x010C
    float StuckEscapeProcedureSensorLength;                      // 0x0110
    float StuckEscapeProcedurePIFraction;                        // 0x0114
    float StuckEscapeProcedureEscapeDistance;                    // 0x0118
    float StuckEscapeProcedureActivationSeconds;                 // 0x011C
    float StuckEscapeProcedureUpdateInterval;                    // 0x0120
    float StuckEscapeProcedureTimeoutSeconds;                    // 0x0124
    float UnStuckActionsTriggerTimeSeconds;                      // 0x0128
    float UnStuckActionsTriggerCooldown;                         // 0x012C
    int32_t StuckEscapeProcedureRetries;                         // 0x0130
    float PrimaryInteractionSearchRadius;                        // 0x0134
    float SecondaryInteractionsProbability;                      // 0x0138
    float SecondaryInteractionsSearchRadius;                     // 0x013C
    float SecondaryObjectivePickupItemsSearchRadius;             // 0x0140
    float SecondaryObjectivePickupItemsInteractOrActionRadius;   // 0x0144
    float SecondaryReviveSearchDistance;                         // 0x0148
    float ExpectedTravelTimeDistanceScale;                       // 0x014C
    float ExpectedTravelTimeBase;                                // 0x0150
    float InteractAreaTime;                                      // 0x0154
    int32_t DebugHighlightObjectiveType;                         // 0x0158
    float SeekAndDestroyMinRadius;                               // 0x015C
    float SeekAndDestroyMaxRadius;                               // 0x0160
    float ForceRepathIfTooFarFromWaypointMeters;                 // 0x0164
    float WaypointMinimumProgressMeters;                         // 0x0168
    float AimNoiseScale;                                         // 0x016C
    float TargetMinSwitchTimeS;                                  // 0x0170
    float MaxTargetEngagingDistanceScale;                        // 0x0174
    float RandomPathSpreadRadius;                                // 0x0178
    float RandomPathSpreadCenterDistance;                        // 0x017C
    float UpdateTargetCooldown;                                  // 0x0180
    float ForcedTargetTimeoutSeconds;                            // 0x0184
    float ActionObjectiveDefaultTime;                            // 0x0188
    float ActionGadgetProbability;                               // 0x018C
    float ActionGadgetInteractableSearchRadius;                  // 0x0190
    float HeroSpawnProbability_Gameplay;                         // 0x0194
    float SpecialSpawnProbability_Gameplay;                      // 0x0198
    float HeroVehicleSpawnProbability_Gameplay;                  // 0x019C
    float VehicleSpawnProbability_Gameplay;                      // 0x01A0
    float HeroSpawnProbability;                                  // 0x01A4
    float SpecialSpawnProbability;                               // 0x01A8
    float HeroVehicleSpawnProbability;                           // 0x01AC
    float VehicleSpawnProbability;                               // 0x01B0
    float FollowTargetPositionCheckCooldown;                     // 0x01B4
    float NotAliveAssertTime;                                    // 0x01B8
    float TimeOnPathToleranceSeconds;                            // 0x01BC
    float SwimmingSuicideTimeout;                                // 0x01C0
    float LofPredictionTime;                                     // 0x01C4
    float TargetTrackerFieldOfViewDegrees;                       // 0x01C8
    uint32_t UpdateTargetPerFrameCap;                            // 0x01CC
    char* ReplayTelemetryFile;                                   // 0x01D0
    char* ReplayTelemetryFileFormat;                             // 0x01D8
    float ReplayTelemetryAdjustTimePadding;                      // 0x01E0
    float EvasiveManeuversJumpProbability;                       // 0x01E4
    float EvasiveManeuversDodgeRollProbability;                  // 0x01E8
    float EvasiveManeuversInvertStrafeDurationMax;               // 0x01EC
    float EvasiveManeuversInvertStrafeDurationMin;               // 0x01F0
    float LegHeadAimRatioOverride;                               // 0x01F4
    float AttackingAbilityLeftProbability;                       // 0x01F8
    float AttackingAbilityLeftDurationSeconds;                   // 0x01FC
    float AttackingAbilityMiddleProbability;                     // 0x0200
    float AttackingAbilityMiddleDurationSeconds;                 // 0x0204
    float AttackingAbilityRightProbability;                      // 0x0208
    float AttackingAbilityRightDurationSeconds;                  // 0x020C
    float EvasiveManeuversCrouchProbability;                     // 0x0210
    float EvasiveManeuversCrouchDuration;                        // 0x0214
    float BlasterLegHeadAimRatio;                                // 0x0218
    float BlasterAimNoise;                                       // 0x021C
    float SniperRifleLegHeadAimRatio;                            // 0x0220
    float SniperRifleAimNoise;                                   // 0x0224
    float LmgLegHeadAimRatio;                                    // 0x0228
    float LmgAimNoise;                                           // 0x022C
    float ShotgunLegHeadAimRatio;                                // 0x0230
    float ShotgunAimNoise;                                       // 0x0234
    float LauncherLegHeadAimRatio;                               // 0x0238
    float LauncherAimNoise;                                      // 0x023C
    float UseSwordAttackingAbilitiesFromMeters;                  // 0x0240
    float SwordAttackDurationTimeMinS;                           // 0x0244
    float SwordAttackDurationTimeMaxS;                           // 0x0248
    float PauseSwordAttackDurationTimeMinS;                      // 0x024C
    float PauseSwordAttackDurationTimeMaxS;                      // 0x0250
    float SwordAttackDistanceMetersMin;                          // 0x0254
    float SwordAttackDistanceMetersMax;                          // 0x0258
    float DebugWindowPositionScaleOffsetX;                       // 0x025C
    float DebugWindowPositionScaleOffsetY;                       // 0x0260
    int32_t DebugWindowWidth;                                    // 0x0264
    int32_t DebugWindowHeight;                                   // 0x0268
    float PathLookAheadMeters;                                   // 0x026C
    float PathLookRightMeters;                                   // 0x0270
    float WaypointToleranceMeters;                               // 0x0274
    float EvasiveManeuversVehicleScale;                          // 0x0278
    float VehicleAimNoiseScale;                                  // 0x027C
    float SwordGuardDurationTimeMinS;                            // 0x0280
    float SwordGuardDurationTimeMaxS;                            // 0x0284
    float AimNoiseScaleTeam1;                                    // 0x0288
    float AimNoiseScaleTeam2;                                    // 0x028C
    float HeroStrafeProbabilityPerFrame;                         // 0x0290
    float EmoteProbabilityAfterPlayersDeath;                     // 0x0294
    float EmoteDuration;                                         // 0x0298
    float MeleeIntervalS;                                        // 0x029C
    float MeleeDistanceM;                                        // 0x02A0
    float EvasiveManeuversGroundCheckDistanceM;                  // 0x02A4
    float EvasiveManeuversGroundCheckHeightDistanceM;            // 0x02A8
    float EvasiveManeuversGroundCheckHeightOffsetM;              // 0x02AC
    float EvasiveManeuversGroundCheckCooldownS;                  // 0x02B0
    float VehicleMinimumForwardThrottle;                         // 0x02B4
    bool ClientEnabled;                                          // 0x02B8
    bool AllowClientTakeOver;                                    // 0x02B9
    bool ForceServerControl;                                     // 0x02BA
    bool ForceServerObjectiveControl;                            // 0x02BB
    bool ForceClientObjectiveControl;                            // 0x02BC
    bool ForceClientNavigation;                                  // 0x02BD
    bool DebugDrawEnabled;                                       // 0x02BE
    bool DebugDrawWaypoints;                                     // 0x02BF
    bool DebugDrawClientDetails;                                 // 0x02C0
    bool DebugDrawCombatDetails;                                 // 0x02C1
    bool AllowAddAutoFillPlayers;                                // 0x02C2
    bool AllowRemoveAutoFillPlayers;                             // 0x02C3
    bool ForceApplyGameplayBotsCount;                            // 0x02C4
    bool AllowGameplayBotsToJoinPlayerSquads;                    // 0x02C5
    bool AllowGameplayBotsToFormOwnSquads;                       // 0x02C6
    bool AllowVehicleSpawn;                                      // 0x02C7
    bool ForceDisableVehicleSpawn;                               // 0x02C8
    bool AllowClientVehicleSpawn;                                // 0x02C9
    bool AllowFirstClientInitialVehicleSpawn;                    // 0x02CA
    bool ControlConnectionlessPlayers;                           // 0x02CB
    bool AllowRespawn;                                           // 0x02CC
    bool UseTelemetryBasedPlanner;                               // 0x02CD
    bool DebugTelemetryBasedPlanner;                             // 0x02CE
    bool UseFadeOverride;                                        // 0x02CF
    bool InputForceMouse;                                        // 0x02D0
    bool UseInputOverrideYawPitch;                               // 0x02D1
    bool UseSeekAndDestroy;                                      // 0x02D2
    bool AllowTeleport;                                          // 0x02D3
    bool ForceAllowAllTeleports;                                 // 0x02D4
    bool DebugDrawTeleports;                                     // 0x02D5
    bool UpdateAI;                                               // 0x02D6
    bool DebugDrawClientOnly;                                    // 0x02D7
    bool DebugDrawClientRealmOnly;                               // 0x02D8
    bool AllowMoveOutsideCombatArea;                             // 0x02D9
    bool AllowSpawnOutsideCombatArea;                            // 0x02DA
    bool AllowVehicleSpawnOutsideCombatArea;                     // 0x02DB
    bool AllowVehicleSpawnOnly;                                  // 0x02DC
    bool DebugDrawPrettyPath;                                    // 0x02DD
    bool DebugDrawUseWaypointsAlpha;                             // 0x02DE
    bool DebugDrawInvalidMoveIntention;                          // 0x02DF
    bool DebugSpam;                                              // 0x02E0
    bool ServerPlayersIgnoreClientPlayers;                       // 0x02E1
    bool IgnoreHumanPlayers;                                     // 0x02E2
    bool OpportunisticInteract;                                  // 0x02E3
    bool AllowMedicRevive;                                       // 0x02E4
    bool AllowPickupItems;                                       // 0x02E5
    bool DebugDrawObjectives;                                    // 0x02E6
    bool DebugDrawObjectiveAlways;                               // 0x02E7
    bool Wallhack;                                               // 0x02E8
    bool CombatUseGrenades;                                      // 0x02E9
    bool CombatUseProne;                                         // 0x02EA
    bool CombatUseMelee;                                         // 0x02EB
    bool UseCrouch;                                              // 0x02EC
    bool AllowPrimaryWeaponForcedFire;                           // 0x02ED
    bool AllowVehicleForcedFire;                                 // 0x02EE
    bool AllowEnterVehicle;                                      // 0x02EF
    bool PrintClientInput;                                       // 0x02F0
    bool AllowPrimaryObjective;                                  // 0x02F1
    bool AllowSecondaryObjectivesWhilePassive;                   // 0x02F2
    bool AllowSecondaryObjectivesWhileDefensive;                 // 0x02F3
    bool AllowPathfinding;                                       // 0x02F4
    bool ForcePassiveMode;                                       // 0x02F5
    bool ForcePrimaryObjectiveDefensiveMode;                     // 0x02F6
    bool ForcePrimaryObjectiveAggressiveMode;                    // 0x02F7
    bool ForceSecondaryObjectiveDefensiveMode;                   // 0x02F8
    bool ForceSecondaryObjectiveAggressiveMode;                  // 0x02F9
    bool ClientJesusMode;                                        // 0x02FA
    bool AllowFortifications;                                    // 0x02FB
    bool UseNameGenerator;                                       // 0x02FC
    bool AllowStuckEscapeProcedure;                              // 0x02FD
    bool ExitStuckEscapeProcedureOnVisualCheck;                  // 0x02FE
    bool DebugDrawUnstuck;                                       // 0x02FF
    bool AllowSuicide;                                           // 0x0300
    bool AllowRandomBehavior;                                    // 0x0301
    bool AllowSecondaryInteractions;                             // 0x0302
    bool SecondaryObjectiveJesusMode;                            // 0x0303
    bool DebugDrawNavigationDetails;                             // 0x0304
    bool DebugDrawNavigationProgressDetails;                     // 0x0305
    bool DebugDrawCustomInput;                                   // 0x0306
    bool DebugDrawAimNoise;                                      // 0x0307
    bool AllowRandomPathSpread;                                  // 0x0308
    bool ForceUseRandomPathSpread;                               // 0x0309
    bool DebugDrawPlayersNamesAndIds;                            // 0x030A
    bool VerboseLogging;                                         // 0x030B
    bool AllowActionGadget;                                      // 0x030C
    bool PreferFPSCamera;                                        // 0x030D
    bool CheckWaterDepthForIntermediatePositions;                // 0x030E
    bool DebugDrawCombatRaycastHitPoints;                        // 0x030F
    bool DebugDrawTransforms;                                    // 0x0310
    bool PickRandomVehicleOnSecondaryObjective;                  // 0x0311
    bool NeverExitVehicleAfterEntering;                          // 0x0312
    bool ReplayTelemetryAdjustTime;                              // 0x0313
    bool DebugDrawWeaponDetails;                                 // 0x0314
    bool DebugDrawExtensiveClientDetails;                        // 0x0315
    bool DebugDrawInputDetails;                                  // 0x0316
    bool DebugDrawAimAtPositions;                                // 0x0317
    bool ResetSettingsOnLevelUnload;                             // 0x0318
    bool AllowEvasiveManouversOOB;                               // 0x0319
    bool EvasiveManeuversGroundCheckEnabled;                     // 0x031A
    bool EvasiveManeuversVehiclesEnabled;                        // 0x031B
    bool VehicleUseCharacterThrottle;                            // 0x031C
    char _0x031D[3];                                             // 0x031D
};
struct NetObjectPrioritySettings
{
    float MinFrequencyFactor;           // 0x0000
    float MaxFrequencyFactor;           // 0x0004
    float MinFrequencyFactorRadius;     // 0x0008
    float MaxFrequencyFactorRadius;     // 0x000C
    float MaxFrequencyFactorConeRadius; // 0x0010
    float MinConeFrequencyFactor;       // 0x0014
    float CameraFovBiasDegrees;         // 0x0018
    float MaxCameraFovDegrees;          // 0x001C
    float MinCameraFovDegrees;          // 0x0020
};
struct NetObjectSystemDebugSettings
{
    float IncomingReplicationStatusReportMaxDelta;         // 0x0000
    char _0x0004[4];                                       // 0x0004
    char* IncomingReplicationStatusReportFilter;           // 0x0008
    uint32_t InitialGraceTimeInFrames;                     // 0x0010
    uint32_t ReportReplicationWarningsAfterFrames;         // 0x0014
    bool EnableReplicationWarnings;                        // 0x0018
    bool EnableIncomingReplicationStatusReport;            // 0x0019
    bool IncomingReplicationStatusReportIncludeSpatial;    // 0x001A
    bool IncomingReplicationStatusReportIncludeStatic;     // 0x001B
    bool IncomingReplicationStatusReportIncludeNonSpatial; // 0x001C
    bool IncomingReplicationStatusReportDrawName;          // 0x001D
    bool OutputObjectProtocols;                            // 0x001E
    bool WarnOnMissingInitDependency;                      // 0x001F
    bool WarnOnTooLargeNetObject;                          // 0x0020
    bool WarnOnNoStateCanBeSent;                           // 0x0021
    bool WarnOnWaitingForCreationAck;                      // 0x0022
    char _0x0023[5];                                       // 0x0023
};
struct DeltaCompressionSettings
{
    uint32_t BaselineReuseCount;          // 0x0000
    bool IsEnabled;                       // 0x0004
    bool ShareBaselinesAcrossConnections; // 0x0005
    char _0x0006[2];                      // 0x0006
};
class NetObjectSystemSettings : public DataContainer
{
public:
    NetObjectPrioritySettings PrioritySettings;        // 0x0018
    char _0x003C[4];                                   // 0x003C
    NetObjectSystemDebugSettings Debug;                // 0x0040
    DeltaCompressionSettings DeltaCompressionSettings; // 0x0068
    uint32_t MaxNetObjectCount;                        // 0x0070
    uint32_t MaxStaticNetObjectCount;                  // 0x0074
    uint32_t MaxClientConnectionCount;                 // 0x0078
    uint32_t MaxServerConnectionCount;                 // 0x007C
    uint32_t InProcBufferSize;                         // 0x0080
    uint32_t GameViewInProcBufferSize;                 // 0x0084
    uint32_t MaxRemoteAuthorityNetObjectCount;         // 0x0088
    int32_t DefaultDynamicPriorityMethod;              // 0x008C
    int32_t DefaultFilterMethod;                       // 0x0090
    bool InProcReplicationEnabled;                     // 0x0094
    char _0x0095[3];                                   // 0x0095
};
} // namespace Kyber