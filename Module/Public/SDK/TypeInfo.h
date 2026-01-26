// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <SDK/SDK.h>

#include <nlohmann/json.hpp>

#include <string>

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

std::string ClientStateToString(ClientState state);

enum SecureReason
{
    SecureReason_Ok = 0x102CBECD,
    SecureReason_WrongProtocolVersion = 0xB0D2286,
    SecureReason_WrongTitleVersion = 0x207B2770, // guess
    SecureReason_ServerFull = 0xEEA836DF,
    SecureReason_KickedOut,
    SecureReason_Banned = 0xC9360C4B,
    SecureReason_GenericError = 0x5FCE71A0,
    SecureReason_WrongPassword,
    SecureReason_MissingContent = 0x16086164,
    SecureReason_NotVerified,
    SecureReason_TimedOut = 0xB59C9896,
    SecureReason_ConnectFailed,
    SecureReason_NoReply = 0xCD9691DA,
    SecureReason_AcceptFailed = 0xB0CCC0CA,
    SecureReason_MismatchingContent = 0x78D1CA4,
    SecureReason_MalformedPacket,
    SecureReason_SendFail,
    SecureReason_ConnectionHandshaking,
    SecureReason_DuplicateConnection,

    SecureReason_InteractivityTimeout,
    SecureReason_KickedFromQueue,
    SecureReason_TeamKills = 0xD2156DA5,
    SecureReason_KickedByAdmin = 0xC765936,
    SecureReason_KickedViaPunkBuster,
    SecureReason_KickedOutServerFull = 0x9F3E83A,
    SecureReason_ESportsMatchStarting,
    SecureReason_NotInESportsRosters = 0xBA879C19,
    SecureReason_ESportsMatchEnding,
    SecureReason_VirtualServerExpired,
    SecureReason_VirtualServerRecreate,
    SecureReason_ESportsTeamFull = 0x1386ADFB,
    SecureReason_ESportsMatchAborted = 0xDDB53DCD,
    SecureReason_ESportsMatchWalkover,
    SecureReason_ESportsMatchWarmupTimedOut,
    SecureReason_NotAllowedToSpectate = 0xE0E36F1E,
    SecureReason_NoSpectateSlotAvailable = 0xC98B3354,
    SecureReason_InvalidSpectateJoin,
    SecureReason_KickedViaFairFight = 0x78B15894,
    SecureReason_KickedCommanderOnLeave = 0xC949E1A8,
    SecureReason_KickedCommanderAfterMutiny,
    SecureReason_ServerMaintenance,
    SecureReason_KickedOutDemoOver = 0xEF204AC1,
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
    SecureReason_TrialUpgraded,
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
#pragma pack(push, 1)
class SystemSettings : public DataContainer
{
public:
    GamePlatform Platform; // 0x0018
    char _0x001C[4];       // 0x001C
};
#pragma pack(pop)
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

class DataBusData : public Asset
{
public:
    uint16_t Flags;                     // 0x0020
    char _0x0022[6];                    // 0x0022
    FBArray<void*> PropertyConnections; // 0x0028
    FBArray<void*> LinkConnections;     // 0x0030
    void* Interface;                    // 0x0038
};

class EntityBusData : public DataBusData
{
public:
    FBArray<void*> EventConnections; // 0x0040
};

class EntityData : public GameObjectData
{
public:
};

class Blueprint : public EntityBusData
{
public:
    FBArray<GameObjectData*> Objects; // 0x0048
    void* Schematics;                  // 0x0050
};

class ObjectBlueprint : public Blueprint
{
public:
    EntityData* Object; //0x0058
};

enum BoolOverride
{
    BoolOverride_Inherit, //0x0000
    BoolOverride_Enable, //0x0001
    BoolOverride_Disable //0x0002
};

struct RenderingOverrides
{
    BoolOverride ShadowEnable; //0x0000
    BoolOverride SunShadowEnable; //0x0004
    BoolOverride LocalShadowEnable; //0x0008
    BoolOverride DynamicReflectionEnable; //0x000C
    BoolOverride StaticReflectionEnable; //0x0010
    BoolOverride PlanarShadowEnable; //0x0014
    BoolOverride HologramEnable; //0x0018
    uint32_t HologramProjectorIndex; //0x001C
    BoolOverride DistantShadowCacheEnable; //0x0020
    BoolOverride DynamicDistantShadowCacheEnable; //0x0024
    BoolOverride LocalShadowCacheEnable; //0x0028
    BoolOverride RootShaderEffect; //0x002C
};

enum StreamRealm
{
    StreamRealm_None, //0x0000
    StreamRealm_Client, //0x0001
    StreamRealm_Both //0x0002
};

enum RadiosityTypeOverride
{
    RadiosityTypeOverride_None, //0x0000
    RadiosityTypeOverride_Dynamic, //0x0001
    RadiosityTypeOverride_LightProbe, //0x0002
    RadiosityTypeOverride_Static, //0x0003
    RadiosityTypeOverride_TerrainProjected, //0x0004
    RadiosityTypeOverride_Proxy //0x0005
};

class ReferenceObjectData : public GameObjectData
{
public:
    RenderingOverrides RenderingOverrides; //0x0020
    StreamRealm StreamRealm; //0x0050
    char _0x0054[12]; //0x0054
    LinearTransform BlueprintTransform; //0x0060
    Blueprint* Blueprint; //0x00A0
    void* ObjectVariation; //0x00A8
    RadiosityTypeOverride RadiosityTypeOverride; //0x00B0
    uint32_t LightmapResolutionScale; //0x00B4
    bool LightmapScaleWithSize; //0x00B8
    bool Excluded; //0x00B9
    bool CreateIndestructibleEntity; //0x00BA
    char _0x00BB[5]; //0x00BB
};

enum BundleHeapType
{
    BundleHeapType_OwnWithParentSmallblock, //0x0000
    BundleHeapType_OwnWithSmallblock, //0x0001
    BundleHeapType_OwnWithoutSmallblock, //0x0002
    BundleHeapType_Parent, //0x0003
    BundleHeapType_Level, //0x0004
    BundleHeapType_Global, //0x0005
    BundleHeapType_Null //0x0006
};

struct BundleHeapInfo
{
    BundleHeapType HeapType; //0x0000
    uint32_t InitialSize; //0x0004
    bool AllowGrow; //0x0008
    char _0x0009[3]; //0x0009
};

struct SharedBundleReference
{
    BundleHeapInfo Heap; //0x0000
    char* Name; //0x0010
};

class SubWorldReferenceObjectData : public ReferenceObjectData
{
public:
    FBArray<char*> PreloadedBundleNames; //0x00C0
    void* InclusionSettings; //0x00C8
    FBArray<SharedBundleReference> Parents; //0x00D0
    BundleHeapInfo BundleHeap; //0x00D8
    char _0x00E4[4]; //0x00E4
    char* BundleName; //0x00E8
    bool AutoLoad; //0x00F0
    bool IsDetachedSubLevel; //0x00F1
    bool IsWin32SubLevel; //0x00F2
    bool IsGen4aSubLevel; //0x00F3
    bool IsGen4bSubLevel; //0x00F4
    bool IsIOSSubLevel; //0x00F5
    bool IsAndroidSubLevel; //0x00F6
    bool IsOSXSubLevel; //0x00F7
    bool IsLinuxSubLevel; //0x00F8
    bool OnLevelLoadFireOnStreamIn; //0x00F9
    bool UsePeerFiltering; //0x00FA
    char _0x00FB[5]; //0x00FB
};

class DataContainerPolicyAsset : public Asset
{};

enum UILinkLayer
{
    UILinkLayer_Menu, // 0x0000
    UILinkLayer_Game, // 0x0001
    UILinkLayer_Count // 0x0002
};

struct PropertyChannel
{
    Realm Realm;           // 0x0000
    int32_t Id;            // 0x0004
    int32_t FieldTypeHash; // 0x0008
};

class LocalizedStringId : public DataContainer
{
public:
    int32_t StringHash; // 0x0018
    char _0x001C[4];    // 0x001C
};

class UILinkTargetAsset : public DataContainerPolicyAsset
{
public:
    int32_t CharacterIdPropertyHash;         // 0x0020
    char _0x0024[4];                         // 0x0024
    FBArray<UILinkTargetAsset*> Breadcrumbs; // 0x0028
    FBArray<PropertyChannel> Properties;     // 0x0030
    LocalizedStringId* Title;                // 0x0038
    UILinkLayer Layer;                       // 0x0040
    char _0x0044[4];                         // 0x0044
    char* Breadcrumb;                        // 0x0048
    bool IsCustomizationScreen;              // 0x0050
    char _0x0051[7];                         // 0x0051
};

class ConsoleCommandTriggerEntityData : public EntityData
{
public:
    char* CommandName;            // 0x0020
    FBArray<char*> Arguments;     // 0x0028
    char* GroupName;              // 0x0030
    Realm Realm;                  // 0x0038
    bool UpdateDefaultsOnChanged; // 0x003C
    char _0x003D[3];              // 0x003D
};

class PrintDebugTextEntityData : public EntityData
{
public:
    Vec2 ScreenPosition;   // 0x0020
    Realm Realm;           // 0x0028
    char _0x002C[4];       // 0x002C
    char* Text;            // 0x0030
    float TimeToShow;      // 0x0038
    char _0x003C[4];       // 0x003C
    Vec3 TextColor;        // 0x0040
    Vec3 WorldPosition;    // 0x0050
    float TextScale;       // 0x0060
    bool UseWorldPosition; // 0x0064
    bool VisibleAtStart;   // 0x0065
    bool Enabled;          // 0x0066
    char _0x0067[9];       // 0x0067
};

enum PropertyDebugGraphMode
{
    PropertyDebugGraphMode_Curve, // 0x0000
    PropertyDebugGraphMode_Bar    // 0x0001
};

class PropertyDebugEntityData : public EntityData
{
public:
    Vec2 ScreenPosition;              // 0x0020
    Vec2 GraphSize;                   // 0x0028
    Vec2 GraphValueMinMax;            // 0x0030
    Vec2 Vec2Value;                   // 0x0038
    Realm Realm;                      // 0x0040
    char _0x0044[12];                 // 0x0044
    LinearTransform TransformValue;   // 0x0050
    Vec3 TextColor;                   // 0x0090
    Vec3 WorldPosition;               // 0x00A0
    Vec3 Vec3Value;                   // 0x00B0
    Vec4 Vec4Value;                   // 0x00C0
    char* ValuePrefix;                // 0x00D0
    float TextScale;                  // 0x00D8
    PropertyDebugGraphMode GraphMode; // 0x00DC
    float FloatValue;                 // 0x00E0
    int32_t IntValue;                 // 0x00E4
    char* StringValue;                // 0x00E8
    bool Multiline;                   // 0x00F0
    bool ShowTransformInWorld;        // 0x00F1
    bool ShowTransformCoordinates;    // 0x00F2
    bool DefaultVisible;              // 0x00F3
    bool DrawGraph;                   // 0x00F4
    char _0x00F5[11];                 // 0x00F5
};

struct PrintDebugTextInput
{
    char* Name;         // 0x0000
    char* NameInternal; // 0x0008
    uint32_t NameHash;  // 0x0010
    int32_t Index;      // 0x0014
};

class WSPrintDebugTextEntityData : public EntityData
{
public:
    Realm Realm;                         // 0x0020
    char _0x0024[4];                     // 0x0024
    FBArray<PrintDebugTextInput> Events; // 0x0028
    char* Owner;                         // 0x0030
    char* EntityName;                    // 0x0038
    char* SubName;                       // 0x0040
    bool ShowOnScreen;                   // 0x0048
    bool PrintAsStream;                  // 0x0049
    char _0x004A[6];                     // 0x004A
};

class ConsoleCommandEntityData : public EntityData
{
public:
    char* DynamicCommand;          // 0x0020
    FBArray<const char*> Commands; // 0x0028
    Realm realm;                   // 0x0030
    char _0x0034[4];               // 0x0034
};

enum PropertyDebugTypeClass
{
    PropertyDebugTypeClass_String,          // 0x0000
    PropertyDebugTypeClass_Float,           // 0x0001
    PropertyDebugTypeClass_Vec2,            // 0x0002
    PropertyDebugTypeClass_Vec3,            // 0x0003
    PropertyDebugTypeClass_Vec4,            // 0x0004
    PropertyDebugTypeClass_Uint64,          // 0x0005
    PropertyDebugTypeClass_Uint32,          // 0x0006
    PropertyDebugTypeClass_LinearTransform, // 0x0007
    PropertyDebugTypeClass_Bool,            // 0x0008
    PropertyDebugTypeClass_Int,             // 0x0009
    PropertyDebugTypeClass_Enum,            // 0x000A
    PropertyDebugTypeClass_Object           // 0x000B
};

struct PropertyDebugInput
{
    char* Name;                       // 0x0000
    char* NameInternal;               // 0x0008
    uint32_t NameHash;                // 0x0010
    char _0x0014[4];                  // 0x0014
    char* TypeName;                   // 0x0018
    PropertyDebugTypeClass TypeClass; // 0x0020
    uint32_t TypeNameHash;            // 0x0024
    int32_t Index;                    // 0x0028
    char _0x002C[4];                  // 0x002C
};

class WSPropertyDebugEntityData : public EntityData
{
public:
    Realm Realm;                        // 0x0020
    char _0x0024[4];                    // 0x0024
    FBArray<PropertyDebugInput> Inputs; // 0x0028
    char* Owner;                        // 0x0030
    char* EntityName;                   // 0x0038
    char* SubName;                      // 0x0040
    bool ShowDataPath;                  // 0x0048
    bool ShowOnScreen;                  // 0x0049
    bool RuntimeVisible;                // 0x004A
    char _0x004B[5];                    // 0x004B
};

class SoundDataEntityData : public EntityData
{
public:
    Realm Realm; // 0x0020
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

class SyncedGameSettings : public SystemSettings
{
public:
    uint32_t DifficultyIndex;                                 // 0x0020
    float BulletDamageModifier;                               // 0x0024
    float MaxAllowedLatency;                                  // 0x0028
    float FrameHistoryTimeMax;                                // 0x002C
    float FrameHistoryTime;                                   // 0x0030
    uint32_t MoveManagerOutgoingFrequencyDivider;             // 0x0034
    uint32_t MoveManagerSinglePlayerOutgoingFrequencyDivider; // 0x0038
    uint32_t MaxCorrectionUpdateCount;                        // 0x003C
    bool DisableToggleEntryCamera;                            // 0x0040
    bool DisableRegenerateHealth;                             // 0x0041
    bool EnableFriendlyFire;                                  // 0x0042
    bool AllowClientSideDamageArbitration;                    // 0x0043
    bool EnableAutomaticCorrectionUpdateCount;                // 0x0044
    char _0x0045[3];                                          // 0x0045
};

struct CongestionControlSettings
{
    uint32_t LatencySampleCount; // 0x0000
    float LatencyMsMin;          // 0x0004
    float LatencyMsMax;          // 0x0008
    float PacketLossMin;         // 0x000C
    float PacketLossMax;         // 0x0010
    float LatencyIncrMsMin;      // 0x0014
    float LatencyIncrMsMax;      // 0x0018
    float ConnectionGradeBad;    // 0x001C
    float ConnectionGradeGood;   // 0x0020
    float ConnectionGradeBest;   // 0x0024
    float FreqChangeStepScale;   // 0x0028
    float FreqDistScaleMin;      // 0x002C
    float FreqDistBiasMax;       // 0x0030
    bool Enabled;                // 0x0034
    char _0x0035[3];             // 0x0035
};

class ServerSettings : public SystemSettings
{
public:
    CongestionControlSettings CongestionCtrl; // 0x0020
    char* InstancePath;                       // 0x0058
    uint32_t RemoteControlPort;               // 0x0060
    uint32_t MaxQueriesPerSecond;             // 0x0064
    char* SavePoint;                          // 0x0068
    float TimeoutTime;                        // 0x0070
    uint32_t PlayerCountNeededForMultiplayer; // 0x0074
    char* DebugMenuClick;                     // 0x0078
    float LoadingTimeout;                     // 0x0080
    float IngameTimeout;                      // 0x0084
    float OutgoingFrequency;                  // 0x0088
    float IncomingFrequency;                  // 0x008C
    uint32_t IncomingRate;                    // 0x0090
    uint32_t OutgoingRate;                    // 0x0094
    char* Playlist;                           // 0x0098
    int32_t DedicatedServerCpu;               // 0x00A0
    uint32_t SaveGameVersion;                 // 0x00A4
    char* ServerName;                         // 0x00A8
    char* ServerPassword;                     // 0x00B0
    float VehicleSpawnDelayModifier;          // 0x00B8
    float HumanHealthMultiplier;              // 0x00BC
    float RespawnTimeModifier;                // 0x00C0
    char _0x00C4[4];                          // 0x00C4
    char* AdministrationPassword;             // 0x00C8
    char* RemoteAdministrationPort;           // 0x00D0
    bool QueryProviderEnabled;                // 0x00D8
    bool DebrisClusterEnabled;                // 0x00D9
    bool VegetationEnabled;                   // 0x00DA
    bool WaterPhysicsEnabled;                 // 0x00DB
    bool IsDesertingAllowed;                  // 0x00DC
    bool IsRenderDamageEvents;                // 0x00DD
    bool RespawnOnDeathPosition;              // 0x00DE
    bool IsStatsEnabled;                      // 0x00DF
    bool IsNetworkStatsEnabled;               // 0x00E0
    bool IsAiEnabled;                         // 0x00E1
    bool IsDestructionEnabled;                // 0x00E2
    bool IsSoldierAnimationEnabled;           // 0x00E3
    bool IsSoldierDetailedCollisionEnabled;   // 0x00E4
    bool LoadSavePoint;                       // 0x00E5
    bool DisableCutscenes;                    // 0x00E6
    bool HavokVisualDebugger;                 // 0x00E7
    bool HavokCaptureToFile;                  // 0x00E8
    bool ShowTriggerDebugText;                // 0x00E9
    bool TimeoutGame;                         // 0x00EA
    bool AILooksIntoCamera;                   // 0x00EB
    bool DeathmatchDebugInfo;                 // 0x00EC
    bool VehicleInteractionIgnoresSeeThrough; // 0x00ED
    bool JobEnable;                           // 0x00EE
    bool ThreadingEnable;                     // 0x00EF
    bool DrawActivePhysicsObjects;            // 0x00F0
    bool IsRanked;                            // 0x00F1
    bool UnlockResolver;                      // 0x00F2
    bool ScoringLogEnabled;                   // 0x00F3
    bool InstantUpdateEnabled;                // 0x00F4
    bool ForcePlaylist;                       // 0x00F5
    bool AutoUnspawnBangers;                  // 0x00F6
    bool RegulatedAIThrottle;                 // 0x00F7
    bool EnableAnimationCulling;              // 0x00F8
    bool FallBackToSquadSpawn;                // 0x00F9
    bool SaveGameUseProfileSaves;             // 0x00FA
    bool VehicleSpawnAllowed;                 // 0x00FB
    bool AdministrationEnabled;               // 0x00FC
    bool AdministrationLogEnabled;            // 0x00FD
    bool AdministrationTimeStampLogNames;     // 0x00FE
    bool AdministrationEventsEnabled;         // 0x00FF
    bool AdministrationServerNameRestricted;  // 0x0100
    bool ExtendedJuiceLoggingEnabled;         // 0x0101
    char _0x0102[6];                          // 0x0102
};

enum OnlineEnvironment
{
    OnlineEnvironment_Development,   // 0x0000
    OnlineEnvironment_Test,          // 0x0001
    OnlineEnvironment_Certification, // 0x0002
    OnlineEnvironment_Production,    // 0x0003
    OnlineEnvironment_Count          // 0x0004
};

enum OnlineBackend
{
    OnlineBackend_Unknown,
    OnlineBackend_Blaze,
    OnlineBackend_BlazeInProc,
    OnlineBackend_DirtySock,
    OnlineBackend_Nucleus,
    OnlineBackend_FirstParty,
    OnlineBackend_Lan,
    OnlineBackend_Local,
    OnlineBackend_Peer,
};

class PresenceBackendData : public Asset
{
public:
    OnlineBackend BackendType; // 0x0020
    char _0x0024[4];           // 0x0024
};

struct OnlinePlatformConfiguration
{
    void* PlatformData;                               // 0x0000
    void* Services;                                   // 0x0008
    void* ServerServices;                             // 0x0010
    FBArray<PresenceBackendData*> ClientBackends;     // 0x0018
    FBArray<PresenceBackendData*> ServerBackends;     // 0x0020
    FBArray<PresenceBackendData*> ServerGameBackends; // 0x0028
    GamePlatform Platform;                            // 0x0030
    bool IsFallback;                                  // 0x0034
    char _0x0035[3];                                  // 0x0035
};

enum LogLevelType
{
    LogLevel_Default, // 0x0000
    LogLevel_Fatal,   // 0x0001
    LogLevel_Error,   // 0x0002
    LogLevel_Warn,    // 0x0003
    LogLevel_Info,    // 0x0004
    LogLevel_Debug,   // 0x0005
    LogLevel_Trace    // 0x0006
};

class OnlineSettings : public SystemSettings
{
public:
    OnlineEnvironment Environment;                  // 0x0020
    char _0x0024[4];                                // 0x0024
    void* Provider;                                 // 0x0028
    FBArray<OnlinePlatformConfiguration> Platforms; // 0x0030
    void* RichPresenceData;                         // 0x0038
    char* ServiceNameOverride;                      // 0x0040
    LogLevelType LogLevel;                          // 0x0048
    int32_t BlazeLogLevel;                          // 0x004C
    int32_t DirtySockLogLevel;                      // 0x0050
    char _0x0054[4];                                // 0x0054
    char* Region;                                   // 0x0058
    char* Country;                                  // 0x0060
    char* PingSite;                                 // 0x0068
    char* MatchmakingToken;                         // 0x0070
    uint32_t NegativeUserCacheRefreshPeriod;        // 0x0078
    char _0x007C[4];                                // 0x007C
    char* ServerLoginEmail;                         // 0x0080
    char* ServerLoginPassword;                      // 0x0088
    char* ServerLoginPersonaName;                   // 0x0090
    char* ServerLoginProjectTag;                    // 0x0098
    int32_t BlazeServerConnectionTimeout;           // 0x00A0
    int32_t BlazeServerTimeout;                     // 0x00A4
    uint32_t BlazeServerTunnelSocketRecvBufSize;    // 0x00A8
    uint32_t BlazeServerTunnelSocketSendBufSize;    // 0x00AC
    uint32_t BlazeOutgoingBufferSize;               // 0x00B0
    int32_t BlazeClientConnectionTimeout;           // 0x00B4
    int32_t BlazeClientTimeout;                     // 0x00B8
    uint32_t BlazeClientTunnelSocketRecvBufSize;    // 0x00BC
    uint32_t BlazeClientTunnelSocketSendBufSize;    // 0x00C0
    int32_t PeerPort;                               // 0x00C4
    int32_t DirtySockServerPacketQueueCapacity;     // 0x00C8
    uint32_t DirtySockMaxConnectionCount;           // 0x00CC
    uint32_t BlazeCachedUserRefreshInterval;        // 0x00D0
    char _0x00D4[4];                                // 0x00D4
    char* TrustedLoginPath;                         // 0x00D8
    char* TrustedLoginCertFilename;                 // 0x00E0
    char* TrustedLoginKeyFilename;                  // 0x00E8
    uint32_t MinPlayerCapacity;                     // 0x00F0
    char _0x00F4[4];                                // 0x00F4
    char* DebugMessageCallstackTypeList;            // 0x00F8
    char* OverrideCreateGameTemplateName;           // 0x0100
    char* ResettablePool;                           // 0x0108
    bool AssertOnPresenceRequestFailures;           // 0x0110
    bool ClientIsPresenceEnabled;                   // 0x0111
    bool ServerIsPresenceEnabled;                   // 0x0112
    bool IsSecure;                                  // 0x0113
    bool EnableQoS;                                 // 0x0114
    bool WaitForQoS;                                // 0x0115
    bool ServerIsReconfigurable;                    // 0x0116
    bool SupportHostMigration;                      // 0x0117
    bool ServerAllowAnyReputation;                  // 0x0118
    bool EnableGamegroupInvites;                    // 0x0119
    bool EnableNucleusLtOverride;                   // 0x011A
    bool ShouldControlDirtySock;                    // 0x011B
    bool OverrideCreateGameTemplate;                // 0x011C
    char _0x011D[3];                                // 0x011D
};

class DatabasePartition
{
public:
    virtual const Guid& GetPartitionGuid() const = 0;
    virtual const char* GetName() const = 0;
    virtual DataContainer* GetPrimaryInstance() const = 0;
    virtual void unk() const = 0;
    virtual DataContainer* FindInstanceByGuid(const Guid& guid) const = 0;

    template<class T>
    T* GetPrimaryInstance() const
    {
        return static_cast<T*>(GetPrimaryInstance());
    }

    template<class T>
    T* FindInstanceByGuid(const Guid& guid) const
    {
        return static_cast<T*>(FindInstanceByGuid(guid));
    }
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

class GameTimeSettings : public SystemSettings
{
public:
    float MaxSimFps;                                // 0x0020
    uint32_t ForceSimRate;                          // 0x0024
    uint32_t MaxVirtualTicks;                       // 0x0028
    float MaxVariableFps;                           // 0x002C
    float MaxInactiveVariableFps;                   // 0x0030
    float ForceDeltaTime;                           // 0x0034
    float TimeScale;                                // 0x0038
    uint32_t DebugFrameDelayMs;                     // 0x003C
    uint32_t DedicatedServerSleepInMsDuringLoading; // 0x0040
    bool UseWaitableTimers;                         // 0x0044
    bool ForceUseSleepTimer;                        // 0x0045
    char _0x0046[2];                                // 0x0046
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

struct TypeInfoAttributeArgument
{
    char* Name;  // 0x0000
    char* Value; // 0x0008
};

class TypeInfoAttribute : public DataContainer
{
public:
    FBArray<TypeInfoAttributeArgument> Arguments; // 0x0018
    char* Name;                                   // 0x0020
    bool IsNative;                                // 0x0028
    char _0x0029[7];                              // 0x0029
};

class TypeInfoAsset : public Asset
{
public:
    char* ModuleName;                       // 0x0020
    FBArray<TypeInfoAttribute*> Attributes; // 0x0028
    const char* TypeName;                   // 0x0030
    bool IsMeta;                            // 0x0038
    bool IsNative;                          // 0x0039
    char _0x003A[6];                        // 0x003A
};

class TypeRef
{
public:
    union
    {
        const TypeInfo* m_typeInfo;
        uintptr_t m_unresolvedData;
    };
};

struct TypeInfoRef
{
    TypeInfoAsset* Asset; // 0x0000
    TypeRef TypeInfo;     // 0x0008
};

enum ProtectionLevel
{
    ProtectionLevel_Private,   // 0x0000
    ProtectionLevel_Protected, // 0x0001
    ProtectionLevel_Public     // 0x0002
};

enum AccessType
{
    AccessType_Member, // 0x0000
    AccessType_Const   // 0x0001
};

class TypeInfoFieldData : public DataContainer
{
public:
    TypeInfoRef TypeRef;                    // 0x0018
    FBArray<TypeInfoAttribute*> Attributes; // 0x0028
    const char* Name;                       // 0x0030
    ProtectionLevel ProtectionLevel;        // 0x0038
    uint32_t MemorySortIndex;               // 0x003C
    AccessType AccessType;                  // 0x0040
    bool IsArray;                           // 0x0044
    bool IsMeta;                            // 0x0045
    bool IsExposed;                         // 0x0046
    bool AlwaysPersist;                     // 0x0047

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1443FA1F0;
    }
};

class TypeInfoFieldValue : public DataContainer
{
public:
    char* Field; // 0x0018
};

class TypeInfoFieldCollection : public DataContainer
{
public:
    FBArray<TypeInfoFieldData*> Fields;         // 0x0018
    FBArray<TypeInfoFieldValue*> DefaultValues; // 0x0020

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1443FA0F0;
    }
};

struct TypeInfoFieldCollectionRef
{
    TypeInfoFieldCollection* Collection; // 0x0000
};

class ComplexTypeInfoAsset : public TypeInfoAsset
{
public:
    FBArray<TypeInfoFieldCollectionRef> FieldCollections; // 0x0040
    uint32_t Alignment;                                   // 0x0048
    char _0x004C[4];                                      // 0x004C
};

struct ClassInfoRef
{
    class ClassInfoAsset* Asset; // 0x0000
    TypeRef TypeInfo;            // 0x0008
};

class ClassInfoAsset : public ComplexTypeInfoAsset
{
public:
    ClassInfoRef SuperClassRef; // 0x0050
    bool IsAbstract;            // 0x0060
    bool IsSealed;              // 0x0061
    char _0x0062[6];            // 0x0062

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1443F9FF0;
    }

    virtual const char** getTypeName()
    {
        return &TypeName;
    }
};

class ValueTypeInfoAsset : public ComplexTypeInfoAsset
{};

enum LanguageFormat
{
    LanguageFormat_English,             // 0x0000
    LanguageFormat_French,              // 0x0001
    LanguageFormat_German,              // 0x0002
    LanguageFormat_Spanish,             // 0x0003
    LanguageFormat_SpanishMex,          // 0x0004
    LanguageFormat_Italian,             // 0x0005
    LanguageFormat_Japanese,            // 0x0006
    LanguageFormat_Russian,             // 0x0007
    LanguageFormat_Polish,              // 0x0008
    LanguageFormat_Dutch,               // 0x0009
    LanguageFormat_Portuguese,          // 0x000A
    LanguageFormat_TraditionalChinese,  // 0x000B
    LanguageFormat_Korean,              // 0x000C
    LanguageFormat_Czech,               // 0x000D
    LanguageFormat_BrazilianPortuguese, // 0x000E
    LanguageFormat_ArabicSA,            // 0x000F
    LanguageFormat_Swedish,             // 0x0010
    LanguageFormat_Norwegian,           // 0x0011
    LanguageFormat_Danish,              // 0x0012
    LanguageFormat_Turkish,             // 0x0013
    LanguageFormat_SimplifiedChinese,   // 0x0014
    LanguageFormat_WorstCase,           // 0x0015
    LanguageFormat_Count,               // 0x0016
    LanguageFormat_Undefined            // 0x0017
};

class UITextDatabase : public Asset
{
public:
    Guid BinaryChunk;            // 0x0020
    Guid HistogramChunk;         // 0x0030
    LanguageFormat Language;     // 0x0040
    uint32_t BinaryChunkSize;    // 0x0044
    uint32_t HistogramChunkSize; // 0x0048
    char _0x004C[4];             // 0x004C
};

class UIItemMetaDataBase : public DataContainer
{
public:
    FBArray<uint32_t> Identifiers; // 0x0018
    char* TelemetryId;             // 0x0020
};

class UIMetaDataAsset : public Asset
{
public:
    FBArray<UIItemMetaDataBase*> Items; // 0x0020
    FBArray<UIMetaDataAsset*> Assets;   // 0x0028
};

class NetworkRegistryAsset : public Asset
{
public:
    uint32_t Checksum;               // 0x0020
    char _0x0024[4];                 // 0x0024
    FBArray<DataContainer*> Objects; // 0x0028
};

struct EbxImportReference
{
    Guid partitionGuid;
    Guid instanceGuid;
};

struct MeshVariationDatabaseRedirectEntry
{
    Asset* Mesh;                     // 0x0000
    uint32_t VariationAssetNameHash; // 0x0008
    char _0x000C[4];                 // 0x000C
};

struct TextureShaderParameter
{
    Asset* Value;        // 0x0000
    char* ParameterName; // 0x0008
};

struct MeshVariationDatabaseMaterial
{
    DataContainer* Material;                           // 0x0000
    DataContainer* MaterialVariation;                  // 0x0008
    uint64_t MaterialId;                               // 0x0010
    FBArray<TextureShaderParameter> TextureParameters; // 0x0018
    Guid SurfaceShaderGuid;                            // 0x0020
    uint32_t SurfaceShaderId;                          // 0x0030
    char _0x0034[4];                                   // 0x0034
};

struct MeshVariationDatabaseEntry
{
    Asset* Mesh;                                      // 0x0000
    FBArray<MeshVariationDatabaseMaterial> Materials; // 0x0008
    uint32_t VariationAssetNameHash;                  // 0x0010
    char _0x0014[4];                                  // 0x0014
};

class MeshVariationDatabase : public Asset
{
public:
    FBArray<MeshVariationDatabaseEntry> Entries;                 // 0x0020
    FBArray<MeshVariationDatabaseRedirectEntry> RedirectEntries; // 0x0028
};

enum FactionId
{
    FactionNeutral, // 0x0000
    FactionUS,      // 0x0001
    FactionRUS,     // 0x0002
    FactionMEC,     // 0x0003
    FactionIdCount, // 0x0004
    FactionInvalid  // 0x0005
};

class GameplayTeamData : public DataContainerPolicyAsset
{
public:
    FactionId Faction; // 0x0020
    char _0x0024[4];   // 0x0024
};

class TeamData : public GameplayTeamData
{
public:
    DataContainer* Soldier;                       // 0x0028
    FBArray<DataContainer*> SoldierCustomization; // 0x0030
    FBArray<DataContainer*> VehicleCustomization; // 0x0038
};

class WSFactionAsset : public DataContainerPolicyAsset
{
public:
    uint32_t Identifier; // 0x0020
    char _0x0024[4];     // 0x0024
};

class WSSoldierCustomizationKitList : public DataContainerPolicyAsset
{
public:
    FBArray<Asset*> Kits; // 0x0020
};

class WSVehicleCustomizationKitList : public DataContainerPolicyAsset
{
public:
    FBArray<Asset*> Kits; // 0x0020
};

class WSDroidCustomizationKitList : public DataContainerPolicyAsset
{
public:
    FBArray<Asset*> Kits; // 0x0020
};

class CharacterClassIdData : public DataContainer
{
public:
    uint32_t CharacterClassId; // 0x0018
    char _0x001C[4];           // 0x001C

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1446B1AB0;
    }
};

class CharacterIdData : public CharacterClassIdData
{
public:
    uint32_t CharacterId; // 0x0020
    char _0x0024[4];      // 0x0024

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1446B19B0;
    }
};

class CharacterIdCollection : public DataContainer
{
public:
    FBArray<CharacterIdData*> Characters; // 0x0018
};

class CharacterClassIdCollection : public DataContainer
{
public:
    FBArray<CharacterClassIdData*> CharacterClasses; // 0x0018
};

class AbilityToCharacterMappingData : public DataContainer
{
public:
    uint32_t AbilityId;   // 0x0018
    uint32_t CharacterId; // 0x001C
};

class EmoteToCharacterMappingData : public DataContainer
{
public:
    uint32_t EmoteId;     // 0x0018
    uint32_t CharacterId; // 0x001C
};

class VoiceLineToCharacterMappingData : public DataContainer
{
public:
    uint32_t VoiceLineId; // 0x0018
    uint32_t CharacterId; // 0x001C
};

class WSTeamData : public TeamData
{
public:
    WSFactionAsset* WSFaction;                                             // 0x0040
    WSSoldierCustomizationKitList* Soldiers;                               // 0x0048
    WSSoldierCustomizationKitList* AutoPlayerSoldiers;                     // 0x0050
    WSSoldierCustomizationKitList* Heroes;                                 // 0x0058
    WSSoldierCustomizationKitList* AutoPlayerHeroes;                       // 0x0060
    WSSoldierCustomizationKitList* SpecialSoldiers;                        // 0x0068
    WSSoldierCustomizationKitList* AutoPlayerSpecialSoldiers;              // 0x0070
    WSVehicleCustomizationKitList* Vehicles;                               // 0x0078
    WSVehicleCustomizationKitList* AutoPlayerVehicles;                     // 0x0080
    WSVehicleCustomizationKitList* HeroVehicles;                           // 0x0088
    WSVehicleCustomizationKitList* AutoPlayerHeroVehicles;                 // 0x0090
    WSDroidCustomizationKitList* Droids;                                   // 0x0098
    CharacterIdCollection* SoldierIdCollection;                            // 0x00A0
    CharacterIdCollection* HeroIdCollection;                               // 0x00A8
    CharacterIdCollection* SpecialSoldiersIdCollection;                    // 0x00B0
    CharacterIdCollection* VehicleIdCollection;                            // 0x00B8
    CharacterIdCollection* HeroVehicleIdCollection;                        // 0x00C0
    CharacterClassIdCollection* TrooperClassIdCollection;                  // 0x00C8
    CharacterClassIdCollection* SpecialClassIdCollection;                  // 0x00D0
    CharacterClassIdCollection* VehicleClassIdCollection;                  // 0x00D8
    CharacterClassIdCollection* HeroClassIdCollection;                     // 0x00E0
    CharacterClassIdCollection* HeroVehicleClassIdCollection;              // 0x00E8
    FBArray<Asset*> AllPlayerAbilities;                                    // 0x00F0
    FBArray<AbilityToCharacterMappingData*> AbilityToCharacterMapping;     // 0x00F8
    FBArray<DataContainerPolicyAsset*> AllPlayerEmotes;                    // 0x0100
    FBArray<EmoteToCharacterMappingData*> EmoteToCharacterMapping;         // 0x0108
    FBArray<DataContainerPolicyAsset*> AllPlayerVoiceLines;                // 0x0110
    FBArray<VoiceLineToCharacterMappingData*> VoiceLineToCharacterMapping; // 0x0118
    uint32_t WSPlanetId;                                                   // 0x0120
    char _0x0124[4];                                                       // 0x0124
};

class ProfileOptionsAsset : public Asset
{
public:
    char* FileName;                 // 0x0020
    FBArray<Asset*> Options;        // 0x0028
    FBArray<Asset*> OptionsPs3;     // 0x0030
    FBArray<Asset*> OptionsXenon;   // 0x0038
    FBArray<Asset*> OptionsGen4a;   // 0x0040
    FBArray<Asset*> OptionsGen4b;   // 0x0048
    FBArray<Asset*> OptionsWin;     // 0x0050
    FBArray<Asset*> OptionsAndroid; // 0x0058
    FBArray<Asset*> OptionsiOS;     // 0x0060
    char* ContentName;              // 0x0068
    uint32_t FileSize;              // 0x0070
    bool AutoSaveOnQuit;            // 0x0074
    char _0x0075[3];                // 0x0075
};

class SpatialEntityData : public EntityData
{
public:
    LinearTransform Transform; // 0x0020
};

enum RigidBodyCollisionLayer
{
    RigidBodyCollisionLayer_Invalid, //0x0000
    RigidBodyCollisionLayer_StaticLayer, //0x0001
    RigidBodyCollisionLayer_DynamicLayer, //0x0002
    RigidBodyCollisionLayer_PlayerCollisionLayer, //0x0003
    RigidBodyCollisionLayer_AICollisionLayer, //0x0004
    RigidBodyCollisionLayer_KeyframeLayer, //0x0005
    RigidBodyCollisionLayer_DebrisLayer, //0x0006
    RigidBodyCollisionLayer_FastDebrisLayer, //0x0007
    RigidBodyCollisionLayer_OnlyStaticCollisionLayer, //0x0008
    RigidBodyCollisionLayer_RagdollLayer, //0x0009
    RigidBodyCollisionLayer_NoCollisionLayer, //0x000A
    RigidBodyCollisionLayer_WaterLayer, //0x000B
    RigidBodyCollisionLayer_BangerLayer, //0x000C
    RigidBodyCollisionLayer_NoVehicleCollisionLayer, //0x000D
    RigidBodyCollisionLayer_CharacterLayer, //0x000E
    RigidBodyCollisionLayer_DynamicNoCharacterCollisionLayer, //0x000F
    RigidBodyCollisionLayer_PredictedVehicleLayer, //0x0010
    RigidBodyCollisionLayer_TerrainLayer, //0x0011
    RigidBodyCollisionLayer_OnlyTerrainCollionLayer, //0x0012
    RigidBodyCollisionLayer_CharacterCollisionGeometryLayer, //0x0013
    RigidBodyCollisionLayer_AiCollisionBodyLayer, //0x0014
    RigidBodyCollisionLayer_CameraCollisionLayer, //0x0015
    RigidBodyCollisionLayer_OnlyStaticCameraCollisionLayer, //0x0016
    RigidBodyCollisionLayer_KeyframedCollisionBodyLayer, //0x0017
    RigidBodyCollisionLayer_VehicleLayer, //0x0018
    RigidBodyCollisionLayer_VehicleAndCharacterCollisionLayer, //0x0019
    RigidBodyCollisionLayer_BlockVehicleOnlyCollisionLayer, //0x001A
    RigidBodyCollisionLayer_TerrainAndStaticCollisionLayer, //0x001B
    RigidBodyCollisionLayer_StarfighterLayer, //0x001C
    RigidBodyCollisionLayer_DefaultQueryLayer, //0x001D
    RigidBodyCollisionLayer_Size //0x001E
};

enum RigidBodyType
{
    RBTypeCollision, //0x0000
    RBTypeDetail, //0x0001
    RBTypeCharacter, //0x0002
    RBTypeRaycast, //0x0003
    RBTypeGroup, //0x0004
    RBTypeProxy, //0x0005
    RBTypeCloth, //0x0006
    RBTypeSize //0x0007
};

enum RigidBodyMotionType
{
    RigidBodyMotionType_Invalid, //0x0000
    RigidBodyMotionType_Fixed, //0x0001
    RigidBodyMotionType_Keyframed, //0x0002
    RigidBodyMotionType_Dynamic, //0x0003
    RigidBodyMotionType_Size //0x0004
};

enum RigidBodyQualityType
{
    RigidBodyQualityType_Fixed, //0x0000
    RigidBodyQualityType_Debris, //0x0001
    RigidBodyQualityType_Dynamic, //0x0002
    RigidBodyQualityType_NeighborWelding, //0x0003
    RigidBodyQualityType_MotionWelding, //0x0004
    RigidBodyQualityType_TriangleWelding, //0x0005
    RigidBodyQualityType_Critical, //0x0006
    RigidBodyQualityType_Vehicle, //0x0007
    RigidBodyQualityType_Character, //0x0008
    RigidBodyQualityType_Grenade, //0x0009
    RigidBodyQualityType_Projectile, //0x000A
    RigidBodyQualityType_Invalid //0x000B
};

class PhysicsBodyData : public EntityData
{
public:
    Realm Realm; //0x0020
    char _0x0024[4]; //0x0024
    Asset* Asset; //0x0028
    DataContainer* PhysicsCallbackHandler; //0x0030
    RigidBodyType RigidBodyType; //0x0038
    RigidBodyCollisionLayer CollisionLayer; //0x003C
    RigidBodyMotionType MotionType; //0x0040
    RigidBodyQualityType QualityType; //0x0044
    uint8_t TransformIndex; //0x0048
    uint8_t WorldIndex; //0x0049
    uint8_t CollisionRootShapeIndex; //0x004A
    uint8_t RaycastRootShapeIndex; //0x004B
    bool AddToSpatialQueryManager; //0x004C
    char _0x004D[3]; //0x004D
};

class OBBCollisionEntityData : public SpatialEntityData
{
public:
    Vec3 HalfExtents;                   // 0x0060
    FBArray<PhysicsBodyData*> PhysicsBodies; // 0x0070
    RigidBodyCollisionLayer CollisionLayer; //0x0078
    // MaterialDecl Material; //0x007C
    bool Enabled;     // 0x0080
    char _0x0081[15]; // 0x0081
};

class AlternateSpawnEntityData : public SpatialEntityData
{
public:
    TeamId Team;     // 0x0060
    float Priority;  // 0x0064
    bool Enabled;    // 0x0068
    char _0x0069[7]; // 0x0069
};

enum ReleaseVersion
{
    ReleaseVersion_Mainline,      // 0x0000
    ReleaseVersion_E3,            // 0x0001
    ReleaseVersion_E3VideoShoot,  // 0x0002
    ReleaseVersion_ConsumerAlpha, // 0x0003
    ReleaseVersion_SoakTest,      // 0x0004
    ReleaseVersion_EAPlay,        // 0x0005
    ReleaseVersion_GamescomSB,    // 0x0006
    ReleaseVersion_OpenBeta,      // 0x0007
    ReleaseVersion_Gamescom2019   // 0x0008
};

class ReleaseVersionEntityData : public EntityData
{
public:
    Realm Realm;                                // 0x0020
    char _0x0024[4];                            // 0x0024
    FBArray<ReleaseVersion> IncludedInVersions; // 0x0028
};

class MeshStreamingSettings : public SystemSettings
{
public:
    uint32_t MaxUnloadCountPerFrame; //0x0020
    uint32_t PoolSize; //0x0024
    uint32_t PoolHeadroomSize; //0x0028
    uint32_t PoolMaxAllocCount; //0x002C
    float CpuPoolSizeScale; //0x0030
    uint32_t DefragTransferLimit; //0x0034
    uint32_t DefragSearchLimit; //0x0038
    uint32_t DefragJobCount; //0x003C
    int32_t ForceLod; //0x0040
    uint32_t MaxPendingLoadCount; //0x0044
    float DistanceMin; //0x0048
    uint32_t ListViewPageIndex; //0x004C
    uint32_t ListViewSortOrder; //0x0050
    char _0x0054[4]; //0x0054
    char* DumpLoadedListFileName; //0x0058
    char* DumpInstanceListFileName; //0x0060
    uint32_t ReservedPositionedInstanceCount; //0x0068
    uint32_t ReservedDistancedInstanceCount; //0x006C
    uint32_t SweepablePageSize; //0x0070
    uint32_t SweepablePageAlign; //0x0074
    uint32_t SweepableMinPages; //0x0078
    uint32_t SweepableReservedPages; //0x007C
    uint32_t SweepablePageAllocationLimit; //0x0080
    int32_t SweepableDirectAllocationAlignmentWasteThreshold; //0x0084
    uint32_t SweepableVirtualPoolInitialVirtualSize; //0x0088
    uint32_t SweepableVirtualPoolExtendVirtualSize; //0x008C
    uint32_t SweepableVirtualPoolMaxDelayedOperations; //0x0090
    bool Enable; //0x0094
    bool UpdateEnable; //0x0095
    bool UpdateJobEnable; //0x0096
    bool PriorityJobEnable; //0x0097
    bool PrioritySpuJobEnable; //0x0098
    bool UseSlowTexturePrio; //0x0099
    bool InstantUnloadingEnable; //0x009A
    bool AsyncCreatesEnable; //0x009B
    bool DxImmutableUsageEnable; //0x009C
    bool OverridePoolSizes; //0x009D
    bool CpuPoolEnabled; //0x009E
    bool DefragEnable; //0x009F
    bool DefragTransfersEnable; //0x00A0
    bool PrioritizeVisibleMeshesFirstEnable; //0x00A1
    bool PrioritizeVisibleLodsFirstEnable; //0x00A2
    bool PrioritizeVisibleLoadsEnable; //0x00A3
    bool PrioritizeTexturesEnable; //0x00A4
    bool HighestPriorityEnable; //0x00A5
    bool PrioritizeNearestPointEnable; //0x00A6
    bool TwoPhasePrioEnable; //0x00A7
    bool DrawInstanceBoxesEnable; //0x00A8
    bool DrawStatsEnable; //0x00A9
    bool DrawMissingListEnable; //0x00AA
    bool DrawPriorityListEnable; //0x00AB
    bool DrawLoadingListEnable; //0x00AC
    bool DrawMeshListEnable; //0x00AD
    bool DrawNonStreamedListEnable; //0x00AE
    bool DumpLoadedList; //0x00AF
    bool DumpInstanceList; //0x00B0
    bool DumpPoolAllocations; //0x00B1
    bool UseSweepablePool; //0x00B2
    bool SweepableUseVirtualPool; //0x00B3
    bool SweepableVirtualPoolCanDelayAllocations; //0x00B4
    char _0x00B5[3]; //0x00B5
};

class LoadSinglePlayerLevelEntityData : public EntityData
{
public:
    char* LevelName; //0x0020
    char* StartPoint; //0x0028
    char* GameMode; //0x0030
    int32_t DifficultyIndex; //0x0038
    bool SplitScreen; //0x003C
    char _0x003D[3]; //0x003D
};

class ClientGameLoopStateEntityData : public EntityData
{
public:
    Realm Realm; //0x0020
    char _0x0024[4]; //0x0024
};

class CompareEntityBaseData : public EntityData
{
public:
    Realm Realm; //0x0020
    bool TriggerOnPropertyChange; //0x0024
    bool TriggerOnStart; //0x0025
    bool AlwaysSend; //0x0026
    char _0x0027[1]; //0x0027
};

class TestCaseEntityData : public EntityData
{
public:
    Realm Realm; //0x0020
    float TimeOut; //0x0024
    char* TestGroup; //0x0028
    char* Description; //0x0030
    char* TestCaseName; //0x0038
    char* TestAuthorName; //0x0040
    float CleanupTimeout; //0x0048
    bool Enabled; //0x004C
    bool Stable; //0x004D
    char _0x004E[2]; //0x004E
};

class WSTestCaseEntityData : public TestCaseEntityData
{};

enum PropertyInterpolationMode
{
    PropertyInterpolationMode_EaseIn, //0x0000
    PropertyInterpolationMode_EaseOut, //0x0001
    PropertyInterpolationMode_EaseInOut, //0x0002
    PropertyInterpolationMode_EaseOutIn, //0x0003
    PropertyInterpolationMode_Count //0x0004
};

enum PropertyInterpolationType
{
    PropertyInterpolationType_Linear, //0x0000
    PropertyInterpolationType_Quad, //0x0001
    PropertyInterpolationType_Cubic, //0x0002
    PropertyInterpolationType_Quart, //0x0003
    PropertyInterpolationType_Quint, //0x0004
    PropertyInterpolationType_Expo, //0x0005
    PropertyInterpolationType_Sine, //0x0006
    PropertyInterpolationType_Circ, //0x0007
    PropertyInterpolationType_Back, //0x0008
    PropertyInterpolationType_Elastic, //0x0009
    PropertyInterpolationType_Bounce, //0x000A
    PropertyInterpolationType_Count //0x000B
};

struct AntRef
{
    Guid AssetGuid; //0x0000
    int32_t ProjectId; //0x0010
};

struct CharacterStatePublicChannelMappingTable
{
    FBArray<void*> BoolChannelMappings; //0x0000
    FBArray<void*> IntChannelMappings; //0x0008
    FBArray<void*> FloatChannelMappings; //0x0010
    FBArray<void*> Vec3ChannelMappings; //0x0018
    FBArray<void*> TransformChannelMappings; //0x0020
};

struct CharacterStateControllerGroup
{
    FBArray<void*> ControllersInGroup; //0x0000
    char* Name; //0x0008
};

class CharacterStateBaseControllerData : public DataContainer
{
public:
    FBArray<CharacterStateBaseControllerData*> Subjects; //0x0018
    int32_t AssetIndex; //0x0020
    char _0x0024[4]; //0x0024
    char* Name; //0x0028
};

struct ResetEveryFrameData
{
    FBArray<uint8_t> BoolBucketMasks; //0x0000
    FBArray<uint8_t> BoolBucketValues; //0x0008
    FBArray<uint8_t> NetBoolBucketMasks; //0x0010
    FBArray<uint8_t> NetBoolBucketValues; //0x0018
    FBArray<uint8_t> IntBucketMasks; //0x0020
    FBArray<uint8_t> NetIntBucketMasks; //0x0028
    FBArray<uint8_t> FloatBucketMasks; //0x0030
    FBArray<uint8_t> NetFloatBucketMasks; //0x0038
    FBArray<uint8_t> Vec3BucketMasks; //0x0040
    FBArray<uint8_t> NetVec3BucketMasks; //0x0048
    FBArray<uint8_t> TransformBucketMasks; //0x0050
    FBArray<uint8_t> NetTransformBucketMasks; //0x0058
    FBArray<int32_t> IntChannelIndices; //0x0060
    FBArray<int32_t> IntChannelValues; //0x0068
    FBArray<int32_t> NetIntChannelIndices; //0x0070
    FBArray<int32_t> NetIntChannelValues; //0x0078
    FBArray<int32_t> FloatChannelIndices; //0x0080
    FBArray<float> FloatChannelValues; //0x0088
    FBArray<int32_t> NetFloatChannelIndices; //0x0090
    FBArray<float> NetFloatChannelValues; //0x0098
    FBArray<int32_t> Vec3ChannelIndices; //0x00A0
    FBArray<Vec3> Vec3ChannelValues; //0x00A8
    FBArray<int32_t> NetVec3ChannelIndices; //0x00B0
    FBArray<Vec3> NetVec3ChannelValues; //0x00B8
    FBArray<int32_t> TransformChannelIndices; //0x00C0
    FBArray<LinearTransform> TransformChannelValues; //0x00C8
    FBArray<int32_t> NetTransformChannelIndices; //0x00D0
    FBArray<LinearTransform> NetTransformChannelValues; //0x00D8
};

class ChannelData : public DataContainer
{
public:
    int32_t ChannelAssetIndex; //0x0018
    char _0x001C[4]; //0x001C
    char* Name; //0x0020
    int32_t TableIndex; //0x0028
    bool ResetWithControllerTreeReset; //0x002C
    bool ResetEveryFrame; //0x002D
    bool MirrorToAnt; //0x002E
    bool Replicate; //0x002F
    bool Networked; //0x0030
    char _0x0031[7]; //0x0031
};

class BoolChannelData : public ChannelData
{
public:
    AntRef AntBool; //0x0038
    int32_t LatencyCompensateTagFrames; //0x004C
    bool DefaultValue; //0x0050
    char _0x0051[7]; //0x0051
};

struct IntNetworkQuantization
{
    int32_t LowerLimit; //0x0000
    int32_t UpperLimit; //0x0004
};

class IntChannelData : public ChannelData
{
public:
    AntRef AntInt; //0x0038
    IntNetworkQuantization NetworkQuantization; //0x004C
    int32_t DefaultValue; //0x0054
    int32_t LatencyCompensateTagFrames; //0x0058
    char _0x005C[4]; //0x005C
};

struct FloatNetworkQuantization
{
    float QuantizationScale; //0x0000
    float MaxValue; //0x0004
    float MinValue; //0x0008
    int32_t BitsNeededForTypicalChange; //0x000C
};

class FloatChannelData : public ChannelData
{
public:
    AntRef AntFloat; //0x0038
    FloatNetworkQuantization NetworkQuantization; //0x004C
    float DefaultValue; //0x005C
    bool IsDeltaChannel; //0x0060
    bool AccumulateDelta; //0x0061
    bool TreatAsGameLogic; //0x0062
    char _0x0063[5]; //0x0063
};

struct Vec3NetworkQuantization
{
    FloatNetworkQuantization XQuant; //0x0000
    FloatNetworkQuantization YQuant; //0x0010
    FloatNetworkQuantization ZQuant; //0x0020
};

class Vec3ChannelData : public ChannelData
{
public:
    Vec3NetworkQuantization NetworkQuantization; //0x0038
    AntRef AntVec; //0x0068
    char _0x007C[4]; //0x007C
    Vec3 DefaultValue; //0x0080
};

struct TransformNetworkQuantization
{
    Vec3NetworkQuantization TranslationQuantization; //0x0000
    float QuatScale; //0x0030
};

enum TransformChannelMirrorToGameStateMode
{
    TransformChannelMirrorToGameStateMode_WorldSpace, //0x0000
    TransformChannelMirrorToGameStateMode_LocalSpace //0x0001
};

class TransformChannelData : public ChannelData
{
public:
    TransformNetworkQuantization NetworkQuantization; //0x0038
    char _0x006C[4]; //0x006C
    LinearTransform DefaultValue; //0x0070
    TransformChannelData* ParentChannel; //0x00B0
    AntRef AntVec; //0x00B8
    AntRef AntQuat; //0x00CC
    TransformChannelMirrorToGameStateMode MirrorMode; //0x00E0
    char _0x00E4[4]; //0x00E4
    char* JointName; //0x00E8
    bool IsDeltaChannel; //0x00F0
    bool AccumulateDelta; //0x00F1
    char _0x00F2[14]; //0x00F2
};

struct ChannelTableData
{
    ResetEveryFrameData ResetEveryFrame; //0x0000
    FBArray<BoolChannelData*> BoolChannels; //0x00E0
    FBArray<IntChannelData*> IntChannels; //0x00E8
    FBArray<FloatChannelData*> FloatChannels; //0x00F0
    FBArray<Vec3ChannelData*> Vec3Channels; //0x00F8
    FBArray<TransformChannelData*> TransformChannels; //0x0100
    FBArray<BoolChannelData*> NetworkedBoolChannels; //0x0108
    FBArray<IntChannelData*> NetworkedIntChannels; //0x0110
    FBArray<FloatChannelData*> NetworkedFloatChannels; //0x0118
    FBArray<Vec3ChannelData*> NetworkedVec3Channels; //0x0120
    FBArray<TransformChannelData*> NetworkedTransformChannels; //0x0128
};

class CharacterStateRootControllerData : public CharacterStateBaseControllerData
{
public:
    ChannelTableData Channels; //0x0030
    AntRef RootAntController; //0x0160
    AntRef PostPhysicsRootAntController; //0x0174
};

class CharacterStateOwnerData : public DataContainerPolicyAsset
{
public:
    AntRef ProxyDataPointer; //0x0020
    char _0x0034[4]; //0x0034
    CharacterStatePublicChannelMappingTable PublicChannelMapping; //0x0038
    CharacterStateRootControllerData* RootController; //0x0060
    void* IncludedChannels; //0x0068
    FBArray<CharacterStateBaseControllerData*> AllControllerDatas; //0x0070
    FBArray<CharacterStateControllerGroup> ControllerGroups; //0x0078
    void* DynamicAvoidance; //0x0080
    AntRef AttachedProxyDataPointer; //0x0088
    AntRef Animatable; //0x009C
    AntRef SceneOpMatrix; //0x00B0
    int32_t ControllerSoftLimitSize; //0x00C4
};

class PlayerAbilityAssetBase : public DataContainerPolicyAsset
{
};

enum PlayerAbilityCategory
{
    PlayerAbilityCategory_Primary, //0x0000
    PlayerAbilityCategory_Middle, //0x0001
    PlayerAbilityCategory_Left, //0x0002
    PlayerAbilityCategory_Right, //0x0003
    PlayerAbilityCategory_AltFire1, //0x0004
    PlayerAbilityCategory_AltFire2, //0x0005
    PlayerAbilityCategory_AltFire3, //0x0006
    PlayerAbilityCategory_Up, //0x0007
    PlayerAbilityCategory_Down, //0x0008
    PlayerAbilityCategory_Passive, //0x0009
    PlayerAbilityCategory_Evade, //0x000A
    PlayerAbilityCategory_HeroMenu, //0x000B
    PlayerAbilityCategory_Legendary, //0x000C
    PlayerAbilityCategory_Pickup, //0x000D
    PlayerAbilityCategory_Extra1, //0x000E
    PlayerAbilityCategory_Extra2, //0x000F
    PlayerAbilityCategory_Extra3, //0x0010
    PlayerAbilityCategory_Extra4, //0x0011
    PlayerAbilityCategory_LLeft, //0x0012
    PlayerAbilityCategory_LRight, //0x0013
    PlayerAbilityCategory_LUp, //0x0014
    PlayerAbilityCategory_LDown, //0x0015
    PlayerAbilityCategory_Emote, //0x0016
    PlayerAbilityCategory_Emote1, //0x0017
    PlayerAbilityCategory_Emote2, //0x0018
    PlayerAbilityCategory_Emote3, //0x0019
    PlayerAbilityCategory_VictoryPose, //0x001A
    PlayerAbilityCategory_Bottom, //0x001B
    PlayerAbilityCategory_CommoRose, //0x001C
    PlayerAbilityCategory_VOWheel, //0x001D
    PlayerAbilityCategory_Count, //0x001E
    PlayerAbilityCategory_Invalid //0x001F
};

class PlayerAbilityAsset : public PlayerAbilityAssetBase
{
public:
    PlayerAbilityCategory Category; //0x0020
    char _0x0024[4]; //0x0024
    void* Unlock; //0x0028
    Blueprint* Blueprint; //0x0030
};

class ReplaySettings : public SystemSettings
{
public:
    uint32_t HeapCoreSizeInMB; //0x0020
    uint32_t HeapReserveSizeInMB; //0x0024
    uint32_t ClipMaxSizeInKB; //0x0028
    uint32_t ClipSBASizeInKB; //0x002C
    uint32_t ClipMaxSizeCompressedInKB; //0x0030
    uint32_t FramesPerClip; //0x0034
    uint32_t UncompressedFrameCount; //0x0038
    uint32_t UncompressedFrameCountReadOnly; //0x003C
    uint32_t TocEntries; //0x0040
    uint32_t TocPinnedEntriesPercentage; //0x0044
    char* VFSMountPoint; //0x0048
    uint32_t BufferSizeInMB; //0x0050
    uint32_t CachePageSizeInKB; //0x0054
    uint32_t CacheSizeInMB; //0x0058
    uint32_t LZ4SoftwareCompressionBlockSizeInKB; //0x005C
    uint32_t ZLibHardwareCompressionBlockSizeInKB; //0x0060
    bool Enable; //0x0064
    bool HeapAllowGrow; //0x0065
    bool PrefetchClips; //0x0066
    bool CompressEndClips; //0x0067
};

class MeshBaseAsset : public Asset
{};

struct QualityScalableInt
{
    int32_t Low; //0x0000
    int32_t Medium; //0x0004
    int32_t High; //0x0008
    int32_t Ultra; //0x000C
    int32_t Cinematic; //0x0010
};

enum QualityLevel
{
    QualityLevel_Low, //0x0000
    QualityLevel_Medium, //0x0001
    QualityLevel_High, //0x0002
    QualityLevel_Ultra, //0x0003
    QualityLevel_Cinematic, //0x0004
    QualityLevel_All, //0x0005
    QualityLevel_Invalid //0x0006
};

enum WorldViewMode
{
    WorldViewMode_Default, //0x0000
    WorldViewMode_Diffuse, //0x0001
    WorldViewMode_BaseColor, //0x0002
    WorldViewMode_MetalMask, //0x0003
    WorldViewMode_Reflectance, //0x0004
    WorldViewMode_Specular, //0x0005
    WorldViewMode_Fresnel0, //0x0006
    WorldViewMode_Fresnel90, //0x0007
    WorldViewMode_Normal, //0x0008
    WorldViewMode_Smoothness, //0x0009
    WorldViewMode_Roughness, //0x000A
    WorldViewMode_LinearRoughness, //0x000B
    WorldViewMode_MaterialId, //0x000C
    WorldViewMode_MaterialIdTileMask, //0x000D
    WorldViewMode_SubSurfaceProfileId, //0x000E
    WorldViewMode_SubSurfaceRadius, //0x000F
    WorldViewMode_SubSurfaceTranslucency, //0x0010
    WorldViewMode_Thickness, //0x0011
    WorldViewMode_LargeThickness, //0x0012
    WorldViewMode_CustomEnvmapId, //0x0013
    WorldViewMode_CoatCoverage, //0x0014
    WorldViewMode_MaterialData, //0x0015
    WorldViewMode_RawLinear, //0x0016
    WorldViewMode_RawLinearAlpha, //0x0017
    WorldViewMode_Light, //0x0018
    WorldViewMode_LightDiffuse, //0x0019
    WorldViewMode_LightColoredDiffuse, //0x001A
    WorldViewMode_LightSpecular, //0x001B
    WorldViewMode_LightIndirectDiffuse, //0x001C
    WorldViewMode_LightIndirectDiffuseOnly, //0x001D
    WorldViewMode_LightColoredIndirectDiffuse, //0x001E
    WorldViewMode_LightTranslucency, //0x001F
    WorldViewMode_LightReflectionOnly, //0x0020
    WorldViewMode_LightMirrorReflectionOnly, //0x0021
    WorldViewMode_ShadowMask, //0x0022
    WorldViewMode_Transmittance, //0x0023
    WorldViewMode_SkyVisibility, //0x0024
    WorldViewMode_Emissive, //0x0025
    WorldViewMode_DynamicAO, //0x0026
    WorldViewMode_Depth, //0x0027
    WorldViewMode_RadiosityLightMaps, //0x0028
    WorldViewMode_RadiosityDiffuseColor, //0x0029
    WorldViewMode_RadiosityTargetUV, //0x002A
    WorldViewMode_RadiosityNormal, //0x002B
    WorldViewMode_Overdraw, //0x002C
    WorldViewMode_OverdrawDepthTest, //0x002D
    WorldViewMode_LightOverdraw, //0x002E
    WorldViewMode_ShaderCost, //0x002F
    WorldViewMode_Occluders, //0x0030
    WorldViewMode_SssTiles, //0x0031
    WorldViewMode_DielectricRange, //0x0032
    WorldViewMode_ConductorRange, //0x0033
    WorldViewMode_Fresnel0Range, //0x0034
    WorldViewMode_IlluminanceRange, //0x0035
    WorldViewMode_LuminanceRange, //0x0036
    WorldViewMode_FilmicEffects, //0x0037
    WorldViewMode_CoC, //0x0038
    WorldViewMode_VelocityVector, //0x0039
    WorldViewMode_DistortionVector, //0x003A
    WorldViewMode_StaticIBL, //0x003B
    WorldViewMode_ScreenSpaceRaytraceReflections, //0x003C
    WorldViewMode_ScreenSpaceRaytraceCoverage, //0x003D
    WorldViewMode_ScreenSpaceRaytraceImportons, //0x003E
    WorldViewMode_NanDetection, //0x003F
    WorldViewMode_Count //0x0040
};

enum FrameSynthesisMode
{
    FrameSynthesisMode_None, //0x0000
    FrameSynthesisMode_Checkerboard //0x0001
};

enum MipmapFilterMode
{
    MipmapFilterMode_Box, //0x0000
    MipmapFilterMode_Renormalize, //0x0001
    MipmapFilterMode_Poisson13, //0x0002
    MipmapFilterMode_Poisson13Clamped, //0x0003
    MipmapFilterMode_BoxAverageEdges //0x0004
};

class WorldRenderSettingsBase : public DataContainer
{
public:
    QualityScalableInt VolumetricCloudsSampleCount; //0x0018
    float CullScreenAreaScale; //0x002C
    Vec3 VelocityVectorsClearValue; //0x0030
    QualityLevel SunShadowmapLevel; //0x0040
    float ShadowmapMinFov; //0x0044
    float ShadowmapSizeZScale; //0x0048
    uint32_t ShadowmapResolution; //0x004C
    uint32_t AdjustedShadowmapResolution; //0x0050
    uint32_t ShadowmapQuality; //0x0054
    float ShadowmapPoissonFilterScale; //0x0058
    uint32_t ShadowmapSliceCount; //0x005C
    uint32_t AdjustedShadowmapSliceCount; //0x0060
    float ShadowmapSliceSchemeWeight; //0x0064
    float ShadowmapFirstSliceScale; //0x0068
    float ShadowmapViewDistance; //0x006C
    float ShadowmapExtrusionLength; //0x0070
    float ShadowmapFirstSliceExtrusionLength; //0x0074
    float ShadowmapTransitionBlendAmount; //0x0078
    float ShadowmapForegroundExtrusionLength; //0x007C
    float ShadowmapForegroundSplitDistance; //0x0080
    float ShadowmapForegroundSizeZScale; //0x0084
    uint32_t DistantShadowCacheResolution; //0x0088
    int32_t DistantShadowCacheForceResolution; //0x008C
    float DistantShadowCacheResolutionScale; //0x0090
    uint32_t DistantShadowCacheMaxResolution; //0x0094
    uint32_t DistantShadowCacheForceMode; //0x0098
    float DistantShadowCacheCoalesceTime; //0x009C
    uint32_t DistantShadowCacheMaxBakeEvents; //0x00A0
    int32_t SunPcssMaxSampleCount; //0x00A4
    int32_t SunPcssAdaptiveSampleIncrement; //0x00A8
    float MotionBlurScale; //0x00AC
    float MotionBlurFixedShutterTime; //0x00B0
    float MotionBlurMax; //0x00B4
    float MotionBlurRadialBlurMax; //0x00B8
    float MotionBlurNoiseScale; //0x00BC
    uint32_t MotionBlurQuality; //0x00C0
    uint32_t MotionBlurDebugMode; //0x00C4
    uint32_t MotionBlurMaxSampleCount; //0x00C8
    float MotionBlurDepthCheckThreshold; //0x00CC
    float MotionBlurDepthCheckMaxDistance; //0x00D0
    float TiledMotionBlurVarianceThresholdScale; //0x00D4
    uint32_t TiledMotionBlurVelMagDepthDownsample; //0x00D8
    uint32_t MultisampleCount; //0x00DC
    uint32_t MultisampleQuality; //0x00E0
    int32_t OnlyShadowmapSlice; //0x00E4
    WorldViewMode ViewMode; //0x00E8
    uint32_t AdditionalHdrTargetInESRAM; //0x00EC
    uint32_t DrawDebugBuffers; //0x00F0
    FrameSynthesisMode FrameSynthesisMode; //0x00F4
    float HalfResDepthMinMaxDitherThreshold; //0x00F8
    uint32_t PhysicalSkyPrecisionHeight; //0x00FC
    uint32_t PhysicalSkyPrecisionView; //0x0100
    uint32_t PhysicalSkyPrecisionSun; //0x0104
    uint32_t PhysicalSkyScatteringOrders; //0x0108
    uint32_t PhysicalSkyAerialPerspectiveTextureWidth; //0x010C
    uint32_t PhysicalSkyAerialPerspectiveTextureHeight; //0x0110
    uint32_t PhysicalSkyAerialPerspectiveTextureDepth; //0x0114
    uint32_t PhysicalSkyScatteringEvalFrameCount; //0x0118
    float PhysicalSkyAerialPerspectiveMaxDistance; //0x011C
    QualityLevel VolumetricCloudsQuality; //0x0120
    uint32_t VolumetricCloudsRenderTargetResolutionDivider; //0x0124
    uint32_t VolumetricCloudsReflectionRenderTargetResolutionDivider; //0x0128
    uint32_t VolumetricCloudsShadowIterationCount; //0x012C
    uint32_t VolumetricCloudsShadowmapResolution; //0x0130
    uint32_t VolumetricCloudsShadowmapBlurSamples; //0x0134
    uint32_t VolumetricCloudsReflectionSampleCount; //0x0138
    uint32_t VolumetricCloudsIBLSampleCount; //0x013C
    float VolumetricCloudsTemporalCoefficient; //0x0140
    float VolumetricCloudsEnvColorTemporalCoefficient; //0x0144
    float SkyEnvmapFilterWidth; //0x0148
    uint32_t SkyEnvmapResolution; //0x014C
    int32_t DrawDebugSkyEnvmapMipLevel; //0x0150
    MipmapFilterMode SkyEnvmapFilterMode; //0x0154
    uint32_t SkyEnvmapSidesPerFrameCount; //0x0158
    float SkyEnvmapUpdateCountThreshold; //0x015C
    float SkyEnvmapUpdateValueThreshold; //0x0160
    int32_t DrawDebugDynamicEnvmapMipLevel; //0x0164
    uint32_t DynamicEnvmapShadowmapResolution; //0x0168
    int32_t DynamicEnvmapShadowmapFarPlane; //0x016C
    int32_t DynamicEnvmapShadowmapShadowExtrusion; //0x0170
    float IndirectSpecularIntensity; //0x0174
    float IndirectSpecularReflectanceScale; //0x0178
    float IndirectSpecularProbesIntensity; //0x017C
    float IndirectSpecularProbesReflectanceScale; //0x0180
    bool DeferredShadingEnable; //0x0184
    bool ForwardOpaqueEnable; //0x0185
    bool FullZPassEnable; //0x0186
    bool TileMaterialClassificationEnable; //0x0187
    bool ShadowmapsEnable; //0x0188
    bool ShadowmapArrayEnable; //0x0189
    bool TransparencyShadowmapsEnable; //0x018A
    bool NVIDIAShadowsPCSSEnable; //0x018B
    bool NVIDIAShadowsHFTSEnable; //0x018C
    bool TransparencyShadowmapsHalfRes; //0x018D
    bool ShadowmapFixedMovementEnable; //0x018E
    bool ShadowmapFixedDepthEnable; //0x018F
    bool ShadowmapViewDistanceScaleEnable; //0x0190
    bool ShadowmapAdjustFarPlane; //0x0191
    bool DrawDebugShadowmapCascades; //0x0192
    bool ShadowmapAccumEnable; //0x0193
    bool ShadowmapAccumReuseEnable; //0x0194
    bool ShadowmapAccumStencilEnable; //0x0195
    bool ShadowmapAccumStencil2Enable; //0x0196
    bool ShadowmapTransitionBlendEnable; //0x0197
    bool ShadowmapForegroundEnable; //0x0198
    bool ShadowmapForegroundUseFirstPersonViewTransform; //0x0199
    bool ShadowmapAdjustShadowDistanceWithFov; //0x019A
    bool ShadowmapDrawBatchedEnable; //0x019B
    bool DistantShadowCacheDrawFrustum; //0x019C
    bool DistantShadowCacheEnable; //0x019D
    bool DistantShadowCacheDrawDebug; //0x019E
    bool DistantShadowCacheUseQuadtree; //0x019F
    bool DistantShadowCacheBatchGroupEntityBake; //0x01A0
    bool DistantShadowCacheRebakeOnLightChange; //0x01A1
    bool DistantShadowCacheRebakeOnAddRemove; //0x01A2
    bool DistantShadowCacheRebakeOnMove; //0x01A3
    bool DistantShadowCacheRebakeOnPartVisibility; //0x01A4
    bool DxShadowmap16BitEnable; //0x01A5
    bool DxDynamicEnvmapShadowmap16BitEnable; //0x01A6
    bool ApplyShadowmapsEnable; //0x01A7
    bool SimpleShadowmapsEnable; //0x01A8
    bool EmitterShadowingBlendToggle; //0x01A9
    bool EmitterShadowingManySamplesToggle; //0x01AA
    bool DxLinearDepth32BitFormatEnable; //0x01AB
    bool MotionBlurEnable; //0x01AC
    bool MotionBlurForceOn; //0x01AD
    bool MotionBlurPerceptualSpaceEnable; //0x01AE
    bool MotionBlurStencilPassEnable; //0x01AF
    bool MotionBlurCenteredEnable; //0x01B0
    bool TiledMotionBlurSeparableEnable; //0x01B1
    bool TiledMotionBlurEnable; //0x01B2
    bool TiledMotionBlurForce20PxTile; //0x01B3
    bool MotionBlurUseDetailedGpuTimers; //0x01B4
    bool VelocityVectorsDeriveFromDepthEnable; //0x01B5
    bool VelocityVectorsDeriveFromDynamicObjectsEnable; //0x01B6
    bool DrawTransparent; //0x01B7
    bool DrawHalfResTransparent; //0x01B8
    bool DrawTransparentDecal; //0x01B9
    bool TransparentDofEnable; //0x01BA
    bool TransparentDofHalfResEnable; //0x01BB
    bool TransparentDofLerpCocEnable; //0x01BC
    bool Enable; //0x01BD
    bool ConsoleRenderTargetPoolSharingEnable; //0x01BE
    bool FastHdrEnable; //0x01BF
    bool LinearDepthInESRAM; //0x01C0
    bool HalfResDepthResolveEnable; //0x01C1
    bool DepthBufferCollisionEnable; //0x01C2
    bool FinalPostEnable; //0x01C3
    bool OutputGammaCorrectionEnable; //0x01C4
    bool ScreenEffectEnable; //0x01C5
    bool DrawSolidBoundingBoxes; //0x01C6
    bool DrawLineBoundingBoxes; //0x01C7
    bool DrawBoundingSpheres; //0x01C8
    bool DrawFrustums; //0x01C9
    bool DrawLocalIBLFrustums; //0x01CA
    bool DrawDebugShadowmaps; //0x01CB
    bool DrawDebugLocalLightShadows; //0x01CC
    bool DrawDebugSkyEnvmap; //0x01CD
    bool DrawDebugVelocityBuffer; //0x01CE
    bool DrawDebugHalfResEnvironment; //0x01CF
    bool DrawDebugDistortion; //0x01D0
    bool DrawDebugVisibleEntityTypes; //0x01D1
    bool DrawDebugSkyTextures; //0x01D2
    bool DrawDebugDof; //0x01D3
    bool DrawDebugHalfResHdrTargets; //0x01D4
    bool DrawDebugHiZMinMaxBufferEnable; //0x01D5
    bool DrawDebugScreenSpaceRaytraceBucketsEnable; //0x01D6
    bool DrawDebugEmitterSunTransmittanceMaps; //0x01D7
    bool DrawDebugBlurPyramid; //0x01D8
    bool DrawDebugOcclusionZBuffer; //0x01D9
    bool DrawDebugLocalIBLOcclusionZBuffer; //0x01DA
    bool WireframeEnable; //0x01DB
    bool ZPassEnable; //0x01DC
    bool OccluderMeshZPrepassEnable; //0x01DD
    bool OccluderMeshZPrepassDrawEnable; //0x01DE
    bool OccluderMeshZPrepassDebugEnable; //0x01DF
    bool HalfResEnable; //0x01E0
    bool ForceFullResEnable; //0x01E1
    bool HalfResLensFlaresEnable; //0x01E2
    bool ForegroundEnable; //0x01E3
    bool ForegroundZPassEnable; //0x01E4
    bool ForegroundTransparentEnable; //0x01E5
    bool BilateralHalfResCompositeEnable; //0x01E6
    bool HalfResDepthMinMaxDitherEnable; //0x01E7
    bool SkyLightingEnable; //0x01E8
    bool SkyRenderEnable; //0x01E9
    bool SkyDepthFogEnable; //0x01EA
    bool SkyHeightFogEnable; //0x01EB
    bool SkyForwardScatteringEnable; //0x01EC
    bool ProceduralSkyReceiveHeightFog; //0x01ED
    bool PhysicalSkyEnabled; //0x01EE
    bool PhysicalSkyForcePrecompute; //0x01EF
    bool VolumetricCloudsEnabled; //0x01F0
    bool VolumetricCloudsCastShadow; //0x01F1
    bool VolumetricCloudsCastShadowInForwardRender; //0x01F2
    bool VolumetricCloudsAffectAerialPerspective; //0x01F3
    bool VolumetricCloudsReceiveAerialPerspective; //0x01F4
    bool VolumetricCloudsOccludeLensFlare; //0x01F5
    bool TransparentFoggingEnable; //0x01F6
    bool DistortionEnable; //0x01F7
    bool DistortionHalfResEnable; //0x01F8
    bool Distortion8BitEnable; //0x01F9
    bool DistortionTilingEnable; //0x01FA
    bool StaticEnvmapEnable; //0x01FB
    bool CustomEnvmapEnable; //0x01FC
    bool SkyEnvmapEnable; //0x01FD
    bool SkyEnvmapMipmapGenEnable; //0x01FE
    bool SkyEnvmapForceUpdateEnable; //0x01FF
    bool SkyEnvmapUseFastHDR; //0x0200
    bool SkyEnvmapDebugColorEnable; //0x0201
    bool SkyEnvmapCloudFogEnable; //0x0202
    bool SkyEnvmapGenerateNoBackdropEnable; //0x0203
    bool DynamicEnvmapEnable; //0x0204
    bool DynamicEnvmapMipmapGenEnable; //0x0205
    bool DrawDebugDynamicEnvmap; //0x0206
    bool DynamicEnvmapShadowmapEnable; //0x0207
    bool DynamicEnvmapShadowmapFarPlaneOverride; //0x0208
    bool DynamicEnvmapShadowmapShadowExtrusionOverride; //0x0209
    bool DrawDebugDynamicEnvmapShadowmap; //0x020A
    bool DrawDynamicEnvmapFrustums; //0x020B
    bool SetupJobEnable; //0x020C
    bool SetupJobsCreateViewJob; //0x020D
    bool PrepareDispatchListJobEnable; //0x020E
    char _0x020F[1]; //0x020F
};

enum DisplayMappingShoulderType
{
    DisplayMappingShoulderType_None,   // 0x0000
    DisplayMappingShoulderType_Neutral // 0x0001
};

enum ScaleResampleMode
{
    ScaleResampleMode_Point,                // 0x0000
    ScaleResampleMode_Linear,               // 0x0001
    ScaleResampleMode_Bicubic,              // 0x0002
    ScaleResampleMode_Lanczos,              // 0x0003
    ScaleResampleMode_LanczosSeparable,     // 0x0004
    ScaleResampleMode_BicubicSharp,         // 0x0005
    ScaleResampleMode_BicubicSharpSeparable // 0x0006
};

enum ResolutionSetGenerator
{
    ResolutionSetGenerator_Normal,     // 0x0000
    ResolutionSetGenerator_Diagonal,   // 0x0001
    ResolutionSetGenerator_Horizontal, // 0x0002
    ResolutionSetGenerator_Vertical,   // 0x0003
    ResolutionSetGenerator_Invalid     // 0x0004
};

enum ResolutionRegulator
{
    ResolutionRegulator_Default,  // 0x0000
    ResolutionRegulator_Sine,     // 0x0001
    ResolutionRegulator_PingPong, // 0x0002
    ResolutionRegulator_Random,   // 0x0003
    ResolutionRegulator_MinMax,   // 0x0004
    ResolutionRegulator_Invalid   // 0x0005
};

class GameRenderSettings : public SystemSettings
{
public:
    uint32_t InactiveSkipFrameCount;                           // 0x0020
    uint32_t FrameGraphBundleSizeLimit;                        // 0x0024
    float ResolutionScale;                                     // 0x0028
    float ResolutionScaleMin;                                  // 0x002C
    float ResolutionScaleMax;                                  // 0x0030
    float DynamicResolutionScaleTargetTime;                    // 0x0034
    uint32_t DynamicResolutionMaxStepCount;                    // 0x0038
    ResolutionRegulator ResolutionRegulator;               // 0x003C
    ResolutionSetGenerator ResolutionSetGenerator;         // 0x0040
    int32_t DxrEnable;                                         // 0x0044
    float DLISPSharpness;                                      // 0x0048
    float DLAAMotionVectorScaleX;                              // 0x004C
    float DLAAMotionVectorScaleY;                              // 0x0050
    float NearPlane;                                           // 0x0054
    float ViewDistance;                                        // 0x0058
    float ForceFov;                                            // 0x005C
    float FovMultiplier;                                       // 0x0060
    float ForceOrthoViewSize;                                  // 0x0064
    float EdgeModelScreenAreaScale;                            // 0x0068
    float EdgeModelViewDistance;                               // 0x006C
    int32_t EdgeModelForceLod;                                 // 0x0070
    float EdgeModelLodScale;                                   // 0x0074
    float StaticModelPartOcclusionMaxScreenArea;               // 0x0078
    uint32_t StaticModelCullJobCount;                          // 0x007C
    float ForceBlurAmount;                                     // 0x0080
    float ForceWorldFadeAmount;                                // 0x0084
    float ColorBlindProtanopiaFactor;                          // 0x0088
    float ColorBlindDeuteranopiaFactor;                        // 0x008C
    float ColorBlindTritanopiaFactor;                          // 0x0090
    float ColorBlindDaltonizeFactor;                           // 0x0094
    float ColorBlindBrightnessFactor;                          // 0x0098
    float ColorBlindContrastFactor;                            // 0x009C
    ScaleResampleMode RenderScaleResampleMode;             // 0x00A0
    float StereoCrosshairMaxHitDepth;                          // 0x00A4
    float StereoCrosshairRadius;                               // 0x00A8
    float StereoCrosshairDampingFactor;                        // 0x00AC
    float DisplayMappingSdrPeakLuma;                           // 0x00B0
    float DisplayMappingHdr10PeakLuma;                         // 0x00B4
    DisplayMappingShoulderType DisplayMappingShoulderType; // 0x00B8
    float HdrLiveGradingOverlayOpacity;                        // 0x00BC
    float DolbyVisionMetadataL1MinLuminanceOverride;           // 0x00C0
    float DolbyVisionMetadataL1MaxLuminanceOverride;           // 0x00C4
    float DolbyVisionMetadataL2MinLuminanceOverride;           // 0x00C8
    float DolbyVisionMetadataL2MaxLuminanceOverride;           // 0x00CC
    float DolbyVisionMetadataL2AvgLuminanceOverride;           // 0x00D0
    float DistortionMaxValueScale;                             // 0x00D4
    float BrightnessScale;                                     // 0x00D8
    float OverlayDropShadowAmount;                             // 0x00DC
    bool Enable;                                               // 0x00E0
    bool NullRendererEnable;                                   // 0x00E1
    bool JobEnable;                                            // 0x00E2
    bool BuildJobSyncEnable;                                   // 0x00E3
    bool FrameGraphParallelExecuteEnable;                      // 0x00E4
    bool RenderQuickEndJobEnable;                              // 0x00E5
    bool DrawDebugDynamicTextureArrays;                        // 0x00E6
    bool DrawDebugInfo;                                        // 0x00E7
    bool DrawScreenInfo;                                       // 0x00E8
    bool DrawDisplayInfo;                                      // 0x00E9
    bool DynamicResolutionScaleEnable;                         // 0x00EA
    bool DynamicResolutionDrawGraphEnable;                     // 0x00EB
    bool DynamicResolutionDrawTableEnable;                     // 0x00EC
    bool VsyncEnable;                                          // 0x00ED
    bool VsyncDuringLoadingScreenEnable;                       // 0x00EE
    bool Fullscreen;                                           // 0x00EF
    bool ForceVSyncEnable;                                     // 0x00F0
    bool MovieVSyncEnable;                                     // 0x00F1
    bool VSyncFlashTestEnable;                                 // 0x00F2
    bool OutputBrightnessTestEnable;                           // 0x00F3
    bool Dx11Enable;                                           // 0x00F4
    bool Dx12Enable;                                           // 0x00F5
    bool Dx12UseProfileOptionEnable;                           // 0x00F6
    bool DLISPEnable;                                          // 0x00F7
    bool DLAAEnable;                                           // 0x00F8
    bool UseResolutionScaleFromNGX;                            // 0x00F9
    bool DLSSDebugDrawEnable;                                  // 0x00FA
    bool DLAACaptureEnable;                                    // 0x00FB
    bool DLISPOverrideSharpnessPerResolution;                  // 0x00FC
    bool DLAAReset;                                            // 0x00FD
    bool DLAAEvaluateFeature;                                  // 0x00FE
    bool DLISPEvaluateFeature;                                 // 0x00FF
    bool Gen4aEsramEnable;                                     // 0x0100
    bool Gen4bColorRemap;                                      // 0x0101
    bool GpuTextureCompressorEnable;                           // 0x0102
    bool EmittersEnable;                                       // 0x0103
    bool EntityRenderEnable;                                   // 0x0104
    bool DebugRendererEnable;                                  // 0x0105
    bool DebugRenderServiceEnable;                             // 0x0106
    bool InitialClearEnable;                                   // 0x0107
    bool ForceOrthoViewEnable;                                 // 0x0108
    bool ForceSquareOrthoView;                                 // 0x0109
    bool DestructionVolumeDrawEnable;                          // 0x010A
    bool EdgeModelsEnable;                                     // 0x010B
    bool EdgeModelCastShadowsEnable;                           // 0x010C
    bool EdgeModelDepthBiasEnable;                             // 0x010D
    bool EdgeModelShadowDepthBiasEnable;                       // 0x010E
    bool EdgeModelUseMainLodEnable;                            // 0x010F
    bool EdgeModelUseLodBox;                                   // 0x0110
    bool EdgeModelCullEnable;                                  // 0x0111
    bool EdgeModelFrustumCullEnable;                           // 0x0112
    bool EdgeModelDrawBoxes;                                   // 0x0113
    bool EdgeModelDrawStats;                                   // 0x0114
    bool StaticModelEnable;                                    // 0x0115
    bool StaticModelMeshesEnable;                              // 0x0116
    bool StaticModelZPassEnable;                               // 0x0117
    bool StaticModelPartCullEnable;                            // 0x0118
    bool StaticModelPartFrustumCullEnable;                     // 0x0119
    bool StaticModelPartOcclusionCullEnable;                   // 0x011A
    bool StaticModelPartShadowCullEnable;                      // 0x011B
    bool StaticModelDrawBoxes;                                 // 0x011C
    bool StaticModelDrawStats;                                 // 0x011D
    bool StaticModelCullSpuJobEnable;                          // 0x011E
    bool StaticModelSurfaceShaderTerrainAccessEnable;          // 0x011F
    bool LockView;                                             // 0x0120
    bool ResetLockedView;                                      // 0x0121
    bool InfiniteProjectionMatrixEnable;                       // 0x0122
    bool SecondaryStreamingViewEnable;                         // 0x0123
    bool FadeEnable;                                           // 0x0124
    bool FadeWaitingEnable;                                    // 0x0125
    bool RenderPlanesEnable;                                   // 0x0126
    bool RenderPlaneMainEnable;                                // 0x0127
    bool RenderPlaneOverlayEnable;                             // 0x0128
    bool DedicatedDebugTexture;                                // 0x0129
    bool RenderPlanesAutoDisable;                              // 0x012A
    bool ColorBlindEnable;                                     // 0x012B
    bool RenderScaleResampleEnable;                            // 0x012C
    bool BlurEnable;                                           // 0x012D
    bool HdrGradingEnable;                                     // 0x012E
    bool DisplayMappingEnable;                                 // 0x012F
    bool HdrOutputPreferCs;                                    // 0x0130
    bool DrawHdrCalibrationScreen;                             // 0x0131
    bool DolbyVisionMetadataLuminanceOverrideEnable;           // 0x0132
    bool DolbyVisionMetadataDebugOverlayEnable;                // 0x0133
    bool FrameSynthesis;                                       // 0x0134
    bool UIShadeInLinearSpaceEnabled;                          // 0x0135
    bool RvmEnable;                                            // 0x0136
    bool RvmTestMode;                                          // 0x0137
    bool RvmOnDemandBuildingEnable;                            // 0x0138
    bool LoadShaderDatabases;                                  // 0x0139
    char _0x013A[6];                                           // 0x013A
};

class GlobalPostProcessSettings : public DataContainer
{
public:
    Vec2 ForceVignetteScale;                             // 0x0018
    Vec3 ForceBloomScale;                                // 0x0020
    Vec4 ForceVignetteColor;                             // 0x0030
    Vec3 FilmGrainColorScale;                            // 0x0040
    Vec3 Brightness;                                     // 0x0050
    Vec3 Contrast;                                       // 0x0060
    Vec3 Saturation;                                     // 0x0070
    Vec2 FilmGrainTextureScale;                          // 0x0080
    uint32_t DebugMode;                                  // 0x0088
    uint32_t DebugModeStep;                                  // 0x008C
    float ForceEVCompensation;                               // 0x0090
    float ForceEV;                                           // 0x0094
    uint32_t BlurPyramidFinalLevel;                          // 0x0098
    float BlurPyramidLdrRange;                               // 0x009C
    float DebugColorGraphMinValue;                           // 0x00A0
    float DebugColorGraphMaxValue;                           // 0x00A4
    int32_t DebugColorGraphLineNumber;                       // 0x00A8
    uint32_t AutoExposureMethod;                             // 0x00AC
    uint32_t AutoExposureHistogramBinCount;                  // 0x00B0
    uint32_t AutoExposureHistogramMipUsed;                   // 0x00B4
    float AutoExposureHistogramMinValue;                     // 0x00B8
    float AutoExposureHistogramMaxValue;                     // 0x00BC
    uint32_t DownsampleAverageStartMipmap;                   // 0x00C0
    int32_t ForceDofEnable;                                  // 0x00C4
    float ForceDofBlurFactor;                                // 0x00C8
    float ForceDofBlurAdd;                                   // 0x00CC
    float ForceDofFocusDistance;                             // 0x00D0
    float ForceSimpleDofNearStart;                           // 0x00D4
    float ForceSimpleDofNearEnd;                             // 0x00D8
    float ForceSimpleDofFarStart;                            // 0x00DC
    float ForceSimpleDofFarEnd;                              // 0x00E0
    float ForceSimpleDofBlurMax;                             // 0x00E4
    float ForceSpriteDofNearStart;                           // 0x00E8
    float ForceSpriteDofNearEnd;                             // 0x00EC
    float ForceSpriteDofFarStart;                            // 0x00F0
    float ForceSpriteDofFarEnd;                              // 0x00F4
    float ForceSpriteDofBlurMax;                             // 0x00F8
    float ForceVignetteExponent;                             // 0x00FC
    float FxaaComputeSubPixelRemoval;                        // 0x0100
    float FxaaComputeContrastThreshold;                      // 0x0104
    int32_t ForceTonemapMethod;                              // 0x0108
    uint32_t ColorGradingHighQualityMode;                    // 0x010C
    int32_t ForceChromostereopsisEnable;                     // 0x0110
    int32_t ForceChromostereopsisOffset;                     // 0x0114
    float ForceChromostereopsisScale;                        // 0x0118
    float LensScopeColorScale;                               // 0x011C
    float HalfResEdgeDetectThreshold;                        // 0x0120
    float Hue;                                               // 0x0124
    float UIBrightnessNorm;                                  // 0x0128
    float UserBrightnessMin;                                 // 0x012C
    float UserBrightnessMax;                                 // 0x0130
    float UserBrightnessAddScale;                            // 0x0134
    float UserBrightnessMulScale;                            // 0x0138
    float LUTGammaR;                                         // 0x013C
    float LUTGammaG;                                         // 0x0140
    float LUTGammaB;                                         // 0x0144
    float LUTGammaCurbOffset;                                // 0x0148
    uint32_t BlurMethod;                                     // 0x014C
    float SpriteDofMinRadiusLayer1;                          // 0x0150
    float SpriteDofMinRadiusLayer2;                          // 0x0154
    float SpriteDofMaxRadiusGatherPass;                      // 0x0158
    float SpriteDofMergeColorThreshold;                      // 0x015C
    float SpriteDofMergeRadiusThreshold;                     // 0x0160
    float SpriteDofDepthDiscontinuityThreshold;              // 0x0164
    uint32_t SpriteDofActiveLayer;                           // 0x0168
    float SpriteDofInfocusMultiplier;                        // 0x016C
    float SpriteDofMaxBlurScale;                             // 0x0170
    float SpriteDofEnergyScaler;                             // 0x0174
    uint32_t SpriteDofMultilayerForegroundCount;             // 0x0178
    float SpriteDofMultilayerForegroundCocSpan;              // 0x017C
    float SpriteDofForegroundReweightExponent;               // 0x0180
    float SpriteDofMultilayerForegroundLayerExtension;       // 0x0184
    float SpriteDofWeightThreshold;                          // 0x0188
    uint32_t SpriteDofMultilayerForegroundActiveLayer;       // 0x018C
    float CircularDofNearBlendingSpeed;                      // 0x0190
    float CircularDofFarBlendingSpeed;                       // 0x0194
    uint32_t DynamicAOMethod;                                // 0x0198
    int32_t ScreenSpaceRaytraceDebug;                        // 0x019C
    int32_t ScreenSpaceRaytraceQuality;                      // 0x01A0
    uint32_t IronsightsDofResolutionFactor;                  // 0x01A4
    uint32_t IronsightsBlurFilter;                           // 0x01A8
    uint32_t IronsightsBlurFilter720p;                       // 0x01AC
    float IronsightsHDRCompression;                          // 0x01B0
    float IronsightsCoCScale;                                // 0x01B4
    float OverrideIronsightsHipFade;                         // 0x01B8
    float OverrideIronsightsStartFade;                       // 0x01BC
    float OverrideIronsightsFocalDistance;                   // 0x01C0
    float OverrideIronsightsDofCircleDistance;               // 0x01C4
    float OverrideIronsightsDofCircleFadeDistance;           // 0x01C8
    uint32_t DynamicAOSampleTemporalCount;                   // 0x01CC
    uint32_t DynamicAOSampleStepCount;                       // 0x01D0
    uint32_t DynamicAOSampleDirCount;                        // 0x01D4
    float DynamicAOMaxFootprintRadius;                       // 0x01D8
    uint32_t DynamicAOBilateralBlurRadius;                   // 0x01DC
    float DynamicAOBilateralBlurSharpness;                   // 0x01E0
    float DynamicAONormalInfluence;                          // 0x01E4
    uint32_t DynamicAOEdgeBlurType;                          // 0x01E8
    uint32_t DynamicAOEdgeBlurGroups;                        // 0x01EC
    uint32_t AdvancedAOLocalSamples;                         // 0x01F0
    uint32_t AdvancedAODistantSamples;                       // 0x01F4
    float DynamicAOTemporalDisocclusionRejectionFactor;      // 0x01F8
    float DynamicAOTemporalMotionSharpeningFactor;           // 0x01FC
    float DynamicAOTemporalResponsiveness;                   // 0x0200
    float DynamicAOTemporalAntiflickerStrength;              // 0x0204
    uint32_t DrawDebugDynamicAOTemporalAccumulationCount;    // 0x0208
    uint32_t DrawDebugDynamicAOTemporalDebugMode;            // 0x020C
    float DrawDebugDynamicAOTemporalMaxDistance;             // 0x0210
    bool HdrBlurEnable;                                      // 0x0214
    bool EVClampEnable;                                      // 0x0215
    bool AdaptationTimeEnable;                               // 0x0216
    bool ForceEVCompensationEnable;                          // 0x0217
    bool ForceEVEnable;                                      // 0x0218
    bool DrawDebugInfo;                                      // 0x0219
    bool DrawExposureDebugInfo;                              // 0x021A
    bool RenderTargetLoadOptsEnable;                         // 0x021B
    bool BlurEnable;                                         // 0x021C
    bool QuarterDownsamplingEnable;                          // 0x021D
    bool BlurBlendEnable;                                    // 0x021E
    bool BloomEnable;                                        // 0x021F
    bool BloomTestEnable;                                    // 0x0220
    bool BlurPyramidEnable;                                  // 0x0221
    bool BlurPyramidQuarterResEnable;                        // 0x0222
    bool BlurPyramidHdrEnable;                               // 0x0223
    bool BlurPyramidFastHdrEnable;                           // 0x0224
    bool BlurPyramidSinglePassEnable;                        // 0x0225
    bool DebugColorGraphEnable;                              // 0x0226
    bool DownsampleLogAverageEnable;                         // 0x0227
    bool DownsampleBeforeBlurEnable;                         // 0x0228
    bool VignetteEnable;                                     // 0x0229
    bool FxaaComputeDebug;                                   // 0x022A
    bool ColorGradingEnable;                                 // 0x022B
    bool ColorGradingDebugEnable;                            // 0x022C
    bool ColorTransformEnable;                               // 0x022D
    bool ColorGradingForceUpdateAlways;                      // 0x022E
    bool FilmGrainEnable;                                    // 0x022F
    bool FilmGrainLinearFilteringEnable;                     // 0x0230
    bool FilmGrainRandomEnable;                              // 0x0231
    bool LensScopeEnable;                                    // 0x0232
    bool UserBrightnessLUTEnable;                            // 0x0233
    bool DrawDebugUserBrightnessLUT;                         // 0x0234
    bool SpriteDofEnable;                                    // 0x0235
    bool SpriteDofMergeEnable;                               // 0x0236
    bool SpriteDofForegroundEnable;                          // 0x0237
    bool SpriteDofDepthFilterEnable;                         // 0x0238
    bool SpriteDofBuffer32bitEnable;                         // 0x0239
    bool SpriteDofHalfResolutionEnable;                      // 0x023A
    bool SpriteDofNearGatherEnable;                          // 0x023B
    bool SpriteDofBestUpsamplingEnable;                      // 0x023C
    bool SpriteDofMultilayerForegroundEnable;                // 0x023D
    bool SpriteDofPackedBokehEnable;                         // 0x023E
    bool SpriteDofBicubicSampleEnable;                       // 0x023F
    bool SpriteDofDebugEnable;                               // 0x0240
    bool SpriteDofUseAsyncCompute;                           // 0x0241
    bool SpriteDofOpticalVignettingEnable;                   // 0x0242
    bool CircularDofEnable;                                  // 0x0243
    bool CircularDofEnableHighRes;                           // 0x0244
    bool CircularDofEnableFarBlurHighQuality;                // 0x0245
    bool CircularDofEnableAntiBanding;                       // 0x0246
    bool DynamicAOEnable;                                    // 0x0247
    bool SsaoBlurEnable;                                     // 0x0248
    bool ScreenSpaceRaytraceEnable;                          // 0x0249
    bool ScreenSpaceRaytraceDeferredResolveEnable;           // 0x024A
    bool ScreenSpaceRaytraceUseVelocityVectorsForTemporal;   // 0x024B
    bool ScreenSpaceRaytraceSeparateCoverageEnable;          // 0x024C
    bool ScreenSpaceRaytraceFullresEnable;                   // 0x024D
    bool ScreenSpaceRaytraceCameraCutEnable;                 // 0x024E
    bool ScreenSpaceRaytraceAsyncComputeEnable;              // 0x024F
    bool IronsightsDofEnable;                                // 0x0250
    bool ForceIronsightsDofActive;                           // 0x0251
    bool OverrideIronsightsDofParams;                        // 0x0252
    bool OverrideIronsightsDofCircleBlur;                    // 0x0253
    bool ForceLensScopeActive;                               // 0x0254
    bool DynamicAOHorizonBased;                              // 0x0255
    bool DynamicAOBilateralBlurEnable;                       // 0x0256
    bool DynamicAONormalEnable;                              // 0x0257
    bool DynamicAOUseAsyncCompute;                           // 0x0258
    bool DynamicAOHalfResEnable;                             // 0x0259
    bool DynamicAOUpscaleEnable;                             // 0x025A
    bool DynamicAOEdgeBlurEnable;                            // 0x025B
    bool DynamicAOTemporalFilterEnable;                      // 0x025C
    bool DynamicAOTemporalHistorySharpening;                 // 0x025D
    bool DrawDebugDynamicAOTemporalEnable;                   // 0x025E
    bool ChromaticAberrationAllowed;                         // 0x025F
    bool LensDistortionAllowed;                              // 0x0260
    char _0x0261[15];                                        // 0x0261
};

class VisualEnvironmentSettings : public DataContainer
{
public:
    float SunRotationX;        // 0x0018
    float SunRotationY;        // 0x001C
    float SkyRotationPhi;      // 0x0020
    int32_t DrawStats;         // 0x0024
    bool DrawOnlyVisibleStats; // 0x0028
    bool HdrGradingEnable;     // 0x0029
    char _0x002A[6];           // 0x002A
};

class BaseDisplaySettings : public SystemSettings
{
public:
    uint32_t FullscreenHeight;                   // 0x0020
    uint32_t FullscreenWidth;                    // 0x0024
    float FullscreenRefreshRate;                 // 0x0028
    uint32_t PreferredAdapterIndex;              // 0x002C
    int32_t FullscreenOutputIndex;               // 0x0030
    int32_t PresentInterval;                     // 0x0034
    uint32_t PresentImmediateThreshold;          // 0x0038
    int32_t RenderAheadLimit;                    // 0x003C
    float GpuTimeoutTime;                        // 0x0040
    uint32_t GpuTimerCount;                      // 0x0044
    uint32_t FrameResourceSegmentSize;           // 0x0048
    uint32_t FrameResourceNonSegmentSize;        // 0x004C
    uint32_t FrameResourceFreeFrameCount;        // 0x0050
    float FrameResourceFreeFactor;               // 0x0054
    uint32_t DisplayDynamicRange;                // 0x0058
    bool GpuProfilerEnable;                      // 0x005C
    bool NullDriverEnable;                       // 0x005D
    bool CreateMinimalWindow;                    // 0x005E
    bool FullscreenModeEnable;                   // 0x005F
    bool Fullscreen;                             // 0x0060
    bool PresentEnable;                          // 0x0061
    bool WindowBordersEnable;                    // 0x0062
    bool VSyncEnable;                            // 0x0063
    bool TripleBufferingEnable;                  // 0x0064
    bool AutomaticComputeSyncEnable;             // 0x0065
    bool FrameResourceFreeEnable;                // 0x0066
    bool DrawFrameMemoryStats;                   // 0x0067
    bool DrawFrameMemoryAllocations;             // 0x0068
    bool Framebuffer10BitEnable;                 // 0x0069
    bool CpuHeapStompEnable;                     // 0x006A
    bool GpuHeapStompEnable;                     // 0x006B
    char _0x006C[4];                             // 0x006C
};

struct QueryEntityResult
{
    union
    {
        uint64_t QueryEntityResultUniquID; // 0x0000
        void** ResultPtr;                   // 0x0000
    };
    uint32_t Unused;                       // 0x0008
    char _0x000C[4];                       // 0x000C
};
} // namespace Kyber