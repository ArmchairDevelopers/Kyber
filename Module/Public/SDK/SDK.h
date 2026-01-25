// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#pragma once

#include <Base/Log.h>

#include <SDK/Transform.h>
#include <Utilities/StringUtils.h>

#include <ByteBuffer/ByteBuffer.hpp>

#include <ToolLib/Func.h>

#include <EASTL/string.h>
#include <EASTL/fixed_vector.h>

#include <cstdint>
#include <glm/glm.hpp>

#include <rpc.h>
#include <rpcdce.h>

#include <Windows.h>

#define OFFSET_GAME_RENDERER 0x143FFBE10

namespace Kyber
{
enum Realm
{
    Realm_Client,          // 0x0000
    Realm_Server,          // 0x0001
    Realm_ClientAndServer, // 0x0002
    Realm_None,            // 0x0003
    Realm_Pipeline,        // 0x0004
    Realm_Count
};

class GameWorld
{
public:
    char pad_0000[8];                   // 0x0000
    void* m_arena;                      // 0x0008
    float halfSizeXZ;                   // 0x0010
    float minY;                         // 0x0014
    void* m_firstRemovedEntity;         // 0x0018
    void* m_lastRemovedEntity;          // 0x0020
    class SubLevel* m_rootLevel;        // 0x0028
    void** m_entitySpatialQueryManager; // 0x0030
    Realm m_realm;                      // 0x0038
    bool N0000021E;                     // 0x003C
    bool N0000024E;                     // 0x003D
    bool N00000251;                     // 0x003E
    char pad_003F[9];                   // 0x003F
    void* m_physicsSpatialQueryManager; // 0x0048
    void* m_physicsManager;             // 0x0050
    char pad_0058[48];                  // 0x0058
}; // Size: 0x0088

// Index these by Realm
extern void** g_entityWorld;
extern GameWorld** g_gameWorld;
extern void** g_gameContext;

class TypeInfo;

#define KB_DECLARE_TYPEINFO(type, addr) inline const TypeInfo* typeInfo_##type = (const TypeInfo*)addr

KB_DECLARE_TYPEINFO(ReferenceObjectData, 0x1445803E0);
KB_DECLARE_TYPEINFO(Asset, 0x1443F9370);
KB_DECLARE_TYPEINFO(CharacterStateOwnerData, 0x144485E30);
KB_DECLARE_TYPEINFO(PlayerAbilityAsset, 0x144480C50);
KB_DECLARE_TYPEINFO(DataBusPeer, 0x1443F91F0);
KB_DECLARE_TYPEINFO(SpatialEntity, 0x14456DB60);
KB_DECLARE_TYPEINFO(ComponentEntity, 0x144583E80);
KB_DECLARE_TYPEINFO(Component, 0x144585130);
KB_DECLARE_TYPEINFO(WSClientSoldierEntity, 0x144664FB0);
KB_DECLARE_TYPEINFO(WSServerSoldierHealthComponent, 0x144677530);
KB_DECLARE_TYPEINFO(QueryEntityResult, 0x14446A0A0);

#define STRIP_PARENS(...) __VA_ARGS__
#define KB_DECLARE_GAMEMEMBERFUNC(ptr, returnType, name, args, ...)                                                                        \
    returnType name(__VA_ARGS__)                                                                                                           \
    {                                                                                                                                      \
        return reinterpret_cast<returnType(__fastcall*)(void*, __VA_ARGS__)>(ptr)(this, STRIP_PARENS args);                                \
    }

#define KB_DECLARE_GAMEMEMBERFUNC_NOARGS(ptr, returnType, name)                                                                            \
    returnType name()                                                                                                                      \
    {                                                                                                                                      \
        return reinterpret_cast<returnType(__thiscall*)(void*)>(ptr)(this);                                                                \
    }

struct TypeObject
{
    virtual class TypeInfo* getType() const = 0;

protected:
    virtual ~TypeObject() = default;
};

struct ResourceRef
{
    union
    {
        void* object;
        uint64_t rid;
    };
};

struct Sha1
{
    uint8_t data[20];
};

struct Guid
{
    union
    {
        uint8_t data[16];

        struct
        {
            uint32_t data1;
            uint16_t data2;
            uint16_t data3;
            uint8_t data4[8];
        };
    };

    std::string ToString() const
    {
        char buffer[37];
        sprintf_s(buffer, "%08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x", data1, data2, data3, data4[0], data4[1], data4[2], data4[3],
            data4[4], data4[5], data4[6], data4[7]);
        return std::string(buffer);
    }

    __forceinline bool Equals(const Guid& guid) const
    {
        return memcmp(data, guid.data, 16) == 0;
    }

    __forceinline bool IsZero() const
    {
        for (int i = 0; i < 16; ++i)
        {
            if (data[i] == 0)
            {
                continue;
            }

            return false;
        }

        return true;
    }

    __forceinline bool operator==(const Guid& guid) const
    {
        return Equals(guid);
    }

    __forceinline bool operator!=(const Guid& guid) const
    {
        return !Equals(guid);
    }

    __forceinline bool operator<(const Guid& guid) const
    {
        return memcmp(this, &guid, sizeof(Guid)) < 0;
    }

    static Guid FromString(const char* str)
    {
        Guid guid{};
        sscanf_s(str, "%08x-%04hx-%04hx-%02hhx%02hhx-%02hhx%02hhx%02hhx%02hhx%02hhx%02hhx", &guid.data1, &guid.data2, &guid.data3,
            &guid.data4[0], &guid.data4[1], &guid.data4[2], &guid.data4[3], &guid.data4[4], &guid.data4[5], &guid.data4[6], &guid.data4[7]);
        return guid;
    }

    static Guid FromString(const std::string& str)
    {
        return FromString(str.c_str());
    }

    static Guid FromString(const eastl::string& str)
    {
        return FromString(str.c_str());
    }

    static Guid FromFrostyLE(uint8_t* b)
    {
        Guid guid{};
        memcpy(guid.data, b, 16);
        return guid;
    }

    static Guid FromFrostyLE(bb::ByteBuffer& buf)
    {
        uint8_t guidBytes[16];
        buf.getBytes(guidBytes, 16);
        return FromFrostyLE(guidBytes);
    }

    static Guid FromFrostyBE(uint8_t* b)
    {
        Guid guid{};
        guid.data[0] = b[3];
        guid.data[1] = b[2];
        guid.data[2] = b[1];
        guid.data[3] = b[0];
        guid.data[4] = b[5];
        guid.data[5] = b[4];
        guid.data[6] = b[7];
        guid.data[7] = b[6];
        guid.data[8] = b[8];
        guid.data[9] = b[9];
        guid.data[10] = b[10];
        guid.data[11] = b[11];
        guid.data[12] = b[12];
        guid.data[13] = b[13];
        guid.data[14] = b[14];
        guid.data[15] = b[15];
        return guid;
    }

    static Guid FromFrostyBE(bb::ByteBuffer& buf)
    {
        uint8_t guidBytes[16];
        buf.getBytes(guidBytes, 16);
        return FromFrostyBE(guidBytes);
    }

    void ToFrostyLE(uint8_t* b) const
    {
        memcpy(b, data, 16);
    }

    void ToFrostyBE(uint8_t* b) const
    {
        b[0] = data[3];
        b[1] = data[2];
        b[2] = data[1];
        b[3] = data[0];

        b[4] = data[5];
        b[5] = data[4];

        b[6] = data[7];
        b[7] = data[6];

        for (int i = 0; i < 8; i++)
        {
            b[8 + i] = data[8 + i];
        }
    }
    static Guid Generate()
    {
        UUID uuid;
        RPC_CSTR uuid_str;
        std::string uuid_out;

        if (UuidCreate(&uuid) != RPC_S_OK)
            std::cout << "couldn't create uuid\nError code" << GetLastError() << std::endl;

        if (UuidToStringA(&uuid, &uuid_str) != RPC_S_OK)
            std::cout << "couldn't convert uuid to string\nError code" << GetLastError() << std::endl;

        uuid_out = (char*)uuid_str;
        RpcStringFreeA(&uuid_str);
        return FromString(uuid_out);
    }
};

enum ResourceCompartment : uint16_t
{
    ResourceCompartment_Static = 0,
    ResourceCompartment_Frontend = 1,
    ResourceCompartment_LoadingScreen = 2,
    ResourceCompartment_GameStatic = 3,
    ResourceCompartment_Game = 4,
    ResourceCompartment_Dynamic_Begin_,
    ResourceCompartment_Synchronized_Begin_ = ResourceCompartment_Dynamic_Begin_,
    ResourceCompartment_Synchronized_End_ = ResourceCompartment_Synchronized_Begin_ + 2000,
    ResourceCompartment_NonSynchronized_Begin_,
    ResourceCompartment_NonSynchronized_End_ = ResourceCompartment_NonSynchronized_Begin_ + 1000,
    ResourceCompartment_Count_ = ResourceCompartment_NonSynchronized_End_,
    ResourceCompartment_Forbidden_ = ResourceCompartment_Count_,
};

enum ResourceCompartmentType
{
    ResourceCompartmentType_NonDynamic,
    ResourceCompartmentType_SynchronizedDynamic,
    ResourceCompartmentType_NonSynchronizedDynamic,
    ResourceCompartmentType_Count_,
};

#pragma pack(push, 1)
class DataContainer : public TypeObject
{
public:
    struct GuidEntry
    {
        Guid guid;
    };

    enum
    {
        Exported = 0x1000,
        HasGuid = 0x0100,
    };

    inline uint32_t IsExported() const
    {
        return m_dcFlags & Exported;
    }

    inline const Guid* GetInstanceGuid() const
    {
        if ((m_dcFlags & HasGuid) == 0)
        {
            return nullptr;
        }

        const GuidEntry* guidEntry = reinterpret_cast<const GuidEntry*>(this) + -1;
        return &guidEntry->guid;
    }

    inline void SetInstanceGuid(Guid& guid)
    {
        if ((m_dcFlags & HasGuid) == 0)
        {
            m_dcFlags |= HasGuid;
        }

        GuidEntry* guidEntry = reinterpret_cast<GuidEntry*>(this) + -1;
        guidEntry->guid = guid;
    }

    inline int addRef() const
    {
        return InterlockedIncrement((volatile unsigned __int32*)&m_refCount);
    }

    void release();

    // Override this when necessary, this is just the base DataContainer TypeInfo
    TypeInfo* getType() const override
    {
        return m_dcType != nullptr ? m_dcType : (TypeInfo*)0x1443F5020;
    }

    TypeInfo* m_dcType = nullptr;
    uint32_t m_refCount = 1;
    uint16_t m_dcFlags = 0;
    ResourceCompartment m_compartment = ResourceCompartment_Static;
};

class GameDataContainer : public DataContainer
{};

class DataBusPeer : public GameDataContainer
{
public:
    uint32_t Flags;  // 0x0018
    char _0x001C[4]; // 0x001C
};

class GameObjectData : public DataBusPeer
{};

class Asset : public DataContainer
{
public:
    char* Name; // 0x0018
};

struct ArrayBase
{
    static void* emptyArrayBegin();
};

template<typename T>
class FBArray : public ArrayBase
{
public:
    T* m_data = nullptr;

    FBArray()
    {
        reset();
    }

    void reset()
    {
        m_data = (T*)emptyArrayBegin();
    }

    inline void cloneFromVec(const std::vector<T>& vec)
    {
        init(vec.size());
        for (int i = 0; i < vec.size(); i++)
        {
            m_data[i] = vec[i];
        }
    }

    inline void init(uint32_t size)
    {
        if (size == 0)
        {
            reset();
            return;
        }
        uint64_t headerSize = sizeof(uint32_t) > __alignof(T) ? sizeof(uint32_t) : __alignof(T);
        m_data = (T*)(reinterpret_cast<uint8_t*>(FB_GLOBAL_ARENA->alloc(headerSize + size * sizeof(T))) + headerSize);

        uint32_t* data = reinterpret_cast<uint32_t*>(reinterpret_cast<char*>(m_data));
        data[-1] = size;
    }

    inline void extend(uint32_t amount)
    {
        uint32_t prevSize = size();
        uint64_t headerSize = sizeof(uint32_t) > __alignof(T) ? sizeof(uint32_t) : __alignof(T);

        T* dest = (T*)(reinterpret_cast<uint8_t*>(FB_GLOBAL_ARENA->alloc(headerSize + ((prevSize + amount) * sizeof(T)))) + headerSize);
        memcpy(dest, m_data, prevSize * sizeof(T));

        // @TODO: free previous array (requires proper padding when alloc-ing tho) 
        // FB_GLOBAL_ARENA->free(reinterpret_cast<uint8_t*>(m_data) - headerSize);
        m_data = dest;

        uint32_t* data = reinterpret_cast<uint32_t*>(reinterpret_cast<char*>(m_data));
        data[-1] = prevSize + amount;
    }

    inline uint32_t size() const
    {
        auto* data = reinterpret_cast<uint32_t*>(m_data);
        if (!data)
        {
            return 0;
        }

        return reinterpret_cast<uint32_t*>(m_data)[-1];
    }

    inline T& at(uint32_t index)
    {
        return m_data[index];
    }

    inline T& operator[](uint32_t index)
    {
        return m_data[index];
    }

    class Iterator
    {
    public:
        using iterator_category = std::forward_iterator_tag;
        using value_type = T;
        using difference_type = std::ptrdiff_t;
        using pointer = T*;
        using reference = T&;

        Iterator(pointer ptr)
            : ptr(ptr)
        {}

        reference operator*() const
        {
            return *ptr;
        }
        pointer operator->()
        {
            return ptr;
        }

        Iterator& operator++()
        {
            ptr++;
            return *this;
        }

        Iterator operator++(int)
        {
            Iterator tmp = *this;
            ++(*this);
            return tmp;
        }

        friend bool operator==(const Iterator& a, const Iterator& b)
        {
            return a.ptr == b.ptr;
        };
        friend bool operator!=(const Iterator& a, const Iterator& b)
        {
            return a.ptr != b.ptr;
        };

    private:
        pointer ptr;
    };

    Iterator begin()
    {
        return Iterator(m_data);
    }
    Iterator end()
    {
        return Iterator(m_data + size());
    }

    Iterator begin() const
    {
        return Iterator(m_data);
    }
    Iterator end() const
    {
        return Iterator(m_data + size());
    }
};
#pragma pack(pop)

struct LevelSetupOption
{
    void* vtable;
    char* Criterion;
    char* Value;
};

class LevelSetup
{
public:
    KB_DECLARE_GAMEMEMBERFUNC(0x14C53D220, void, Init, (a2, a3, a4), __int64 a2, __int64 a3, __int64 a4)
    KB_DECLARE_GAMEMEMBERFUNC(0x141136820, void, SetInclusionOptions, (inclusionOptions), const char* inclusionOptions)
    KB_DECLARE_GAMEMEMBERFUNC(0x141136690, void, SetInclusionOption, (key, value), const char* key, const char* value)
    KB_DECLARE_GAMEMEMBERFUNC(0x1470C3010, const char*, GetInclusionOption, (key), const char* key)

    void* vtable;            // 0x0000
    char* Name;              // 0x0008
    char pad_0010[16];       // 0x0010
    char* InitialDSubLevel;  // 0x0020
    char* InitialStartPoint; // 0x0028
    char pad_0030[200];      // 0x0030
};

struct SaveGameData : public FBArray<uint8_t>
{};

struct ServerSpawnInfo
{
    ServerSpawnInfo(LevelSetup& setup)
        : levelSetup(setup)
    {}

    void* fileSystem = nullptr;
    void* damageArbitrator = nullptr;
    class ServerPlayerManager* playerManager = nullptr;
    LevelSetup& levelSetup;
    unsigned int tickFrequency = 0;
    bool isSinglePlayer = false;
    bool isLocalHost = false;
    bool isDedicated = false;
    bool isEncrypted = false;
    bool isCoop = false;
    bool isMenu = false;
    bool keepResources = false;
    char N000004A2[5]; // 0x002B
    SaveGameData saveData;
    void* serverCallbacks = nullptr;
    void* runtimeModules = nullptr;

    mutable void* loadInfo = nullptr;
    unsigned int serverPort = 0;
    unsigned int validLocalPlayersMask = 1;
};

struct SocketSpawnInfo
{
    SocketSpawnInfo()
        : isProxied(false)
    {}

    SocketSpawnInfo(bool isProxied, const std::string& proxyAddress, const std::string& serverName, const std::string& password)
        : isProxied(isProxied)
        , proxyAddress(proxyAddress)
        , serverName(serverName)
        , password(password)
    {}

    bool isProxied;
    std::string proxyAddress;
    std::string serverName;
    std::string password;
};

class ServerGameContext
{
public:
    char pad_0000[16];                        // 0x0000
    void* messageManager;                     // 0x0010
    char pad_0018[64];                        // 0x0018
    ServerPlayerManager* serverPlayerManager; // 0x0058
    void* serverPeer;                         // 0x0060
}; // Size: 0x0890

class VehicleEntityData
{
public:
    char pad_0000[568]; // 0x0000
    char* VehicleName;  // 0x0238
    char pad_0240[520]; // 0x0240

    char* GetName()
    {
        if (this != nullptr && this->VehicleName != nullptr)
        {
            return this->VehicleName;
        }
        return (char*)"\0";
    }
}; // Size: 0x0448

class AttachedControllable
{
public:
    char pad_0000[48];                      // 0x0000
    class VehicleEntityData* vehicleEntity; // 0x0030
    char pad_0038[560];                     // 0x0038

    VehicleEntityData* GetVehicleEntityData()
    {
        if (this != nullptr && this->vehicleEntity != nullptr)
        {
            return this->vehicleEntity;
        }
    }

}; // Size: 0x1058

class SoldierBlueprint
{
public:
    char pad_0000[24]; // 0x0000
    char* Name;        // 0x0018
    char pad_0020[40]; // 0x0020
    char* GetName()
    {
        if (this != nullptr && this->Name != nullptr)
        {
            return this->Name;
        }
        return (char*)"\0";
    }
}; // Size: 0x0048

class ClientSoldierPrediction
{
public:
    char pad_0000[32];  // 0x0000
    Vec3 Location;      // 0x0020
    Vec3 Velocity;      // 0x0020
    char pad_002C[104]; // 0x002C
}; // Size: 0x0094

class CharacterEntityNetState
{
public:
    char pad_0000[16];           // 0x0000
    uint8_t m_dirtyStates;       // 0x0010
    char pad_0011[15];           // 0x0011
    LinearTransform m_transform; // 0x0020
};

class HealthComponent : public TypeObject
{
public:
    char pad_0008[24];              // 0x0008
    float m_health;                 // 0x0020
    float m_unkLastHealthMaybe;     // 0x0020

    KB_DECLARE_GAMEMEMBERFUNC(0x148E65FF0, void, SetHealth, (health), float health)

    float GetHealth()
    {
        return m_health;
    }
};

class WSServerSoldierHealthComponent : public HealthComponent
{
public:
    char pad_0028[16];           // 0x0028
    float health2;               // 0x0038
    char pad_003C[188];          // 0x003C
    float m_totalTimer;          // 0x00F8
    char pad_00FC[540];          // 0x00FC
    float health4;               // 0x0318
    char pad_031C[596];          // 0x031C
    uint32_t N0000010D;          // 0x0570
    char pad_0574[16];           // 0x0574
    float m_displayHealth;       // 0x0584
    float m_displayMaxHealth;    // 0x0588
    char pad_058C[220];          // 0x058C
    float m_regenTimer;          // 0x0668
    float m_regenMaxHealth;      // 0x066C
    float m_calculatedMaxHealth; // 0x0670
    float m_regenPerSec;         // 0x0674
    float m_regenDelay;          // 0x0678
    char pad_067C[372];          // 0x067C

    void SetStateChanged(int index);
    void SetMaxHealth(float value);
    void SetRegenerationPerSecond(float value);
    void SetRegenerationDelay(float value);
};

class ClientSoldierHealthComponent : public HealthComponent {};

class ClientSoldierEntity : public TypeObject
{
public:
    char pad_0000[704];                                               // 0x0000
    ClientSoldierHealthComponent* clientSoldierHealthComponent;       // 0x02C8
    char pad_02D0[104];                                               // 0x02D0
    class SoldierBlueprint* soldierBlueprint;                         // 0x0338
    char pad_0340[632];                                               // 0x0340
    float N000001AE;                                                  // 0x05B8
    float Yaw;                                                        // 0x05BC
    float Pitch;                                                      // 0x05C0
    char pad_05C4[404];                                               // 0x05C4
    ClientSoldierPrediction* clientSoldierPrediction;                 // 0x0758
    char pad_0760[2488];                                              // 0x0760

    SoldierBlueprint* GetSoldierBlueprint()
    {
        if (this != nullptr && this->soldierBlueprint != nullptr)
        {
            return this->soldierBlueprint;
        }
    }

    void Teleport(const LinearTransform& transform);
}; // Size: 0x0840

class AimingData3
{
public:
    char pad_0000[104]; // 0x0000
    float m_yaw;        // 0x0068
    float m_pitch;      // 0x006C
};

class AimingData2
{
public:
    char pad_0000[168];  // 0x0000
    float m_yaw;         // 0x00A8
    float m_pitch;       // 0x00AC
    char pad_00B0[2264]; // 0x00B0
}; // Size: 0x0988

class AimingData1
{
public:
    char pad_0000[56];    // 0x0000
    AimingData2* m_data2; // 0x0038
    char pad_0040[72];    // 0x0040
}; // Size: 0x0088

class StateStreamAiming
{
public:
    char pad_0000[152];   // 0x0000
    AimingData1* m_data1; // 0x0098
    char pad_00A0[40];    // 0x00A0

    static StateStreamAiming* Get()
    {
        return *(StateStreamAiming**)0x14406E610;
    }
}; // Size: 0x00C8

enum LocalPlayerId
{
    LocalPlayerId_0 = 0,          // 0x0000
    LocalPlayerId_1,              // 0x0001
    LocalPlayerId_2,              // 0x0002
    LocalPlayerId_3,              // 0x0003
    LocalPlayerId_4,              // 0x0004
    LocalPlayerId_5,              // 0x0005
    LocalPlayerId_6,              // 0x0006
    LocalPlayerId_7,              // 0x0007
    LocalPlayerId_Any,            // 0x0008
    LocalPlayerId_All,            // 0x0009
    LocalPlayerId_Invalid = 0xFF, // 0x000A
};

class OnlineId
{
public:
    uint64_t m_nativeData; // 0x0000
    char m_id[16];         // 0x0008
}; // Size: 0x0018

class ClientPlayer
{
public:
    virtual void unk1() {};
    class PlayerData* m_data;         // 0x0008
    class MemoryArena* m_memoryArena; // 0x0010
    const char* m_name;               // 0x0018
    char pad_0020[24];                // 0x0020
    LocalPlayerId m_localPlayerId;
    uint32_t m_analogInputEnableMask;
    uint64_t m_digitalInputEnableMask;
    char pad_0048[16]; // 0x0048
    int32_t m_teamId;  // 0x0058
    char pad[4];
    OnlineId m_onlineId;
    char pad_005C[392];                               // 0x005C
    class AttachedControllable* attachedControllable; // 0x0200
    char pad_0208[8];                                 // 0x0208

    // Beware that this may not actually be a soldier entity.
    // Always check if the type equals "WSClientSoldierEntity"
    // before using fields specific to that type.
    class ClientSoldierEntity* controlledControllable; // 0x0210

    char pad_0218[16];                                // 0x0218
    class ClientCameraViewManager* cameraViewManager; // 0x0228
};

class ClientPlayerManager
{
public:
    char pad_0000[8];                                      // 0x0000
    class PlayerData* m_playerData;                        // 0x0008
    uint32_t m_maxPlayerCount;                             // 0x0010
    uint32_t m_playerCountBitCount;                        // 0x0014
    uint32_t m_playerIdBitCount;                           // 0x0018
    char pad_001C[212];                                    // 0x001C
    eastl::fixed_vector<ClientPlayer*, 64> m_players;      // 0x00F0
    eastl::fixed_vector<ClientPlayer*, 64> m_spectators;   // 0x00C8
    eastl::fixed_vector<ClientPlayer*, 64> m_localPlayers; // 0x00C8

    ClientPlayer* GetLocalPlayer(LocalPlayerId localPlayerId)
    {
        for (const auto& player : m_localPlayers)
        {
            if (player && player->m_localPlayerId == localPlayerId)
            {
                return player;
            }
        }

        return nullptr;
    }

    ClientPlayer* GetPlayer(uint64_t playerId)
    {
        for (const auto& player : m_players)
        {
            if (player && player->m_onlineId.m_nativeData == playerId)
            {
                return player;
            }
        }

        return nullptr;
    }

}; // Size: 0x2258

class FreeCamera
{
public:
    struct State
    {
        float rotateLeftRight;
        float rotateUpDown;
        char gap8[4];
        float moveLeftRight;
        float moveUpDown;
        float moveReverseForward;
    };

    char pad_0000[224]; // 0x0000
    LinearTransform transform;
    char pad_0120[96]; // 0x0120
    Vec3 targetPos;
};

class ClientGameView
{
public:
    char pad[0xB8];
    FreeCamera* freeCamera;
};

class ClientGameContext
{
public:
    char pad_0000[56];                  // 0x0000
    void* clientLevel;                  // 0x0038
    char pad_0040[24];                  // 0x0040
    ClientPlayerManager* playerManager; // 0x0058
    void* onlineManager;                // 0x0060
    ClientGameView* gameViews[2];       // 0x0068
    char pad_0060[232];                 // 0x0068

    ClientPlayerManager* GetPlayerManager()
    {
        if (this != nullptr && this->playerManager != nullptr)
        {
            return this->playerManager;
        }

        return nullptr;
    }

    static ClientGameContext* Get()
    {
        return *(ClientGameContext**)0x143EE7858;
    }
};

#pragma pack(push, 1)
enum TypeCodeEnum : uint16_t
{
    kTypeCode_Void = 0,
    kTypeCode_DbObject = 1,
    kTypeCode_ValueType = 2,
    kTypeCode_Class = 3,
    kTypeCode_Array = 4,
    kTypeCode_CString = 7,
    kTypeCode_Enum = 8,
    kTypeCode_Boolean = 10,
    kTypeCode_Int8 = 11,
    kTypeCode_Uint8 = 12,
    kTypeCode_Int16 = 13,
    kTypeCode_Uint16 = 14,
    kTypeCode_Int32 = 15,
    kTypeCode_Uint32 = 16,
    kTypeCode_Int64 = 17,
    kTypeCode_Uint64 = 18,
    kTypeCode_Float32 = 19,
    kTypeCode_Float64 = 20,
};

class TypeInfo
{
public:
    class TypeInfoData* typeInfoData; // 0x0000
    TypeInfo* next;

    char pad[0x28];
    // ClassInfo ONLY
    const TypeInfo* m_super;
    const TypeObject* m_defaultInstance;
    uint16_t m_classId;
    uint16_t m_lastClassId;
    // End - ClassInfo ONLY

    TypeCodeEnum getBasicType() const;
    const char* getName() const;

    std::string toString(const void* data) const;

    bool isKindOf(const TypeInfo* other) const;
}; // Size: 0x0008

class MemberInfoData
{
public:
    char* name;     // 0x0000
    uint16_t flags; // 0x0008

    static const uint32_t kFlagIsBlittable = 1 << 15;

    bool IsBlittable() const
    {
        return (flags & kFlagIsBlittable) == kFlagIsBlittable;
    }
}; // Size: 0x000A

class TypeInfoData : public MemberInfoData
{
public:
    uint16_t totalSize;            // 0x000A
    uint32_t guid;                 // 0x000C
    class ModuleInfo* module;      // 0x0010
    class TypeInfo* arrayTypeInfo; // 0x0018
    uint16_t alignment;            // 0x0020
    uint16_t fieldCount;           // 0x0022
    uint32_t signature;            // 0x0024
}; // Size: 0x0028

class FieldInfoData : public MemberInfoData
{
public:
    uint16_t fieldOffset;         // 0x000A
    uint32_t N00000636;           // 0x000C
    class TypeInfo* fieldTypePtr; // 0x0010
}; // Size: 0x0018

class ModuleInfo
{
public:
    char* moduleName;             // 0x0000
    class ModuleInfo* nextModule; // 0x0008
    class TestList* testList;     // 0x0010
}; // Size: 0x0018

class TestList
{
public:
    char pad_0000[136]; // 0x0000
}; // Size: 0x0088

class ClassInfoData : public TypeInfoData
{
public:
    class ClassInfo* superClass; // 0x0028
    class FieldInfoData* fields; // 0x0030
}; // Size: 0x0038

class EnumTypeInfoData : public TypeInfoData
{
public:
    class FieldInfoData* fields; // 0x0030
}; // Size: 0x0038

struct ValueTypeCreationInfo
{
    MemoryArena* arena;
    const TypeInfo* typeInfo;
};

typedef void*(__fastcall* ValueTypeInfoCreate_t)(void* mem, const ValueTypeCreationInfo& info);

class ValueTypeInfoData : public TypeInfoData
{
public:
    ValueTypeInfoCreate_t createFunc; // 0x0028
    void* N000005D8;                  // 0x0030
    char pad_0038[8];                 // 0x0038
    void* N000005AC;                  // 0x0040
    char pad_0048[8];                 // 0x0048
    class FieldInfoData* fields;      // 0x0030
}; // Size: 0x0038

class ArrayTypeInfoData : public TypeInfoData
{
public:
    class TypeInfo* elementType; // 0x0028
}; // Size: 0x0038

class ClassInfo
{
public:
    class ClassInfoData* typeInfoData; // 0x0000

    const char* getName() const
    {
        return typeInfoData->name;
    }

    void Init(void* obj)
    {
        typedef __int64(__fastcall * tINIT)(void*);
        tINIT fINIT = *(tINIT*)(this + 0x38);
        fINIT(obj);
    }
}; // Size: 0x0008

class ArrayTypeInfo : public TypeInfo
{};
#pragma pack(pop)

enum Platform
{
    Win32
};

typedef int EventId;
class EntityEvent : TypeObject
{
public:
    enum Sender
    {
        Sender_External,
        Sender_Parent,
        Sender_Child
    };

    EntityEvent(const char* event);

    EntityEvent(EventId eventId)
        : eventId(eventId)
        , sender(Sender_Child)
    {}

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x14456F0A0;
    }

    bool Is(const char* event) const
    {
        return eventId == StringUtils::HashQuick(event);
    }

    mutable EventId eventId;
    mutable Sender sender;
};

class PlayerEventBase : public EntityEvent
{
public:
    PlayerEventBase(EventId eventId)
        : EntityEvent(eventId)
    {}

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1445250B0;
    }

    virtual const void* getPlayer() const;
};

enum ChatChannel
{
    ChatChannel_All,
    ChatChannel_Group,
    ChatChannel_Team,
    ChatChannel_Admin
};

class ServerCharacterEntity;
class ServerVehicleEntity;

struct PlayerExtentRegistration
{
    uint32_t offset;
    uint32_t size;
    uint32_t alignment;
};

// Extent research

// Some server extents are named, most arent.
// We will make due with just numbering the generic ones
// and describing what is in each.

class ServerPlayerExtent : public TypeObject
{};

class ServerGamePlayerExtent : public ServerPlayerExtent
{
public:
    static PlayerExtentRegistration* s_registration;

    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x14686AC80, TypeObject*, GetCharacter)
    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x1468843B0, TypeObject*, GetVehicle)
    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x146875A70, bool, IsInVehicle)
    KB_DECLARE_GAMEMEMBERFUNC(0x140BE2C60, void, LeaveVehicle, (forceLeave, useExitPoint), bool forceLeave, bool useExitPoint)
    KB_DECLARE_GAMEMEMBERFUNC(0x140BDDFE0, bool, EnterVehicle, (vehicle, seatIndex), void* vehicle, unsigned int seatIndex)
    KB_DECLARE_GAMEMEMBERFUNC(0x146881270, void*, SetSelectedCustomizationAsset, (asset), DataContainer* asset)
};

class PersistenceServerPlayerExtent : public ServerPlayerExtent
{
public:
    static PlayerExtentRegistration* s_registration;

    KB_DECLARE_GAMEMEMBERFUNC(0x1483F2A60, void, SetScore, (amount), unsigned int amount);
    KB_DECLARE_GAMEMEMBERFUNC(0x1483F26C0, void, SetKills, (amount), unsigned int amount);
    KB_DECLARE_GAMEMEMBERFUNC(0x1483F2590, void, SetAssists, (amount), unsigned int amount);
    KB_DECLARE_GAMEMEMBERFUNC(0x1483F1B10, void, SetDeaths, (amount), unsigned int amount);

    char pad_008[0x40];
    int32_t unk1;
    int32_t m_score;
    int32_t unk2;
    int32_t m_kills;
    int32_t m_assists;
    int32_t m_deaths;
    int32_t unk3;
    int32_t unk4;
    int32_t m_longestKillstreak;
};

class WSServerPlayerAbilityExtent : public ServerPlayerExtent
{
public:
    static PlayerExtentRegistration* s_registration;

    KB_DECLARE_GAMEMEMBERFUNC(0x14199F370, bool, SetAbility, (abilityId, replacePassive), uint32_t abilityId, bool replacePassive);

    struct ActiveKitAbiityData
    {
        void* vtable;
        Asset* ability;
        void* back;
    };

    struct ActiveKitAbilityContainer
    {
        void* vtable;
        ActiveKitAbiityData** abilityList; // null terminated?
        void* garbage[3];
    };

    void* vtable2; // idk
    char pad_010[0x30];
    ActiveKitAbilityContainer* m_abilityContainer;
};

class ServerPlayerExtent4 : public ServerPlayerExtent
{
public:
    static PlayerExtentRegistration* s_registration;

    KB_DECLARE_GAMEMEMBERFUNC(0x141BCE620, void, SetBattlepoints, (amount), unsigned int amount);
    KB_DECLARE_GAMEMEMBERFUNC(0x148E4EF60, void, AddBattlepoints, (amount), int amount);
    KB_DECLARE_GAMEMEMBERFUNC(0x141BCE400, void, SetActiveKit, (gpId, unk0, vurId, skinInfoId), uint32_t gpId, uint32_t unk0,
        uint32_t vurId, uint32_t skinInfoId);

    char gap0[0x113C];
    uint32_t m_battlepoints;
};

#define KB_DECLARE_SERVERPLAYEREXTENT(name)                                                                                                \
    name* Get##name() const                                                                                                                \
    {                                                                                                                                      \
        return reinterpret_cast<name*>(GetExtent(name::s_registration));                                                                   \
    }

class ServerPlayer
{
public:
    virtual void unk1() {};
    class PlayerData* m_data;         // 0x0008
    class MemoryArena* m_memoryArena; // 0x0010
    const char* m_name;               // 0x0018
    char pad_0020[24];                // 0x0020
    LocalPlayerId m_localPlayerId;
    uint32_t m_analogInputEnableMask;
    uint64_t m_digitalInputEnableMask;
    char pad_0048[16]; // 0x0048
    int32_t m_teamId;  // 0x0058
    char pad_005C[4];  // 0x005C
    OnlineId m_onlineId;
    char pad_0078[72];  // 0x0078
    bool m_isSpectator; // 0x00C0

    void SendChatMessage(ChatChannel channel, const char* message) const;

    bool IsAIPlayer()
    {
        return static_cast<uint32_t>(m_localPlayerId) == 0xFF || (m_onlineId.m_nativeData >= 133700 && m_onlineId.m_nativeData <= 133799);
    }

    bool IsSpectator()
    {
        return m_isSpectator;
    }

    KB_DECLARE_GAMEMEMBERFUNC(0x140BE9C10, void, SetTeam, (teamId), int teamId)

    ServerCharacterEntity* GetCharacterEntity();
    ServerVehicleEntity* GetVehicleEntity();
    bool Teleport(const LinearTransform& transform);
    void ForceSendChatMessage(ChatChannel channel, const char* message);

    ServerPlayerExtent* GetExtent(const PlayerExtentRegistration* registrar) const
    {
        return reinterpret_cast<ServerPlayerExtent*>(reinterpret_cast<uintptr_t>(this) + registrar->offset);
    }

    TypeObject* GetExtent(const char* name)
    {
        int* v16 = (int*)0x143AB6FA0;
        while (v16)
        {
            __int64 v17 = (__int64)this + (unsigned int)*v16;
            v16 = *((int**)v16 + 7);
            TypeObject* extent = (TypeObject*)v17;
            if (strcmp(name, extent->getType()->getName()) == 0)
            {
                return extent;
            }
        }

        return nullptr;
    }

    KB_DECLARE_SERVERPLAYEREXTENT(ServerGamePlayerExtent)
    KB_DECLARE_SERVERPLAYEREXTENT(ServerPlayerExtent4)
    KB_DECLARE_SERVERPLAYEREXTENT(WSServerPlayerAbilityExtent)
    KB_DECLARE_SERVERPLAYEREXTENT(PersistenceServerPlayerExtent)
}; // Size: 0x024C

class ServerPlayerManager
{
public:
    char pad_0000[8];                                    // 0x0000
    class PlayerData* m_playerData;                      // 0x0008
    uint32_t m_maxPlayerCount;                           // 0x0010
    uint32_t m_playerCountBitCount;                      // 0x0014
    uint32_t m_playerIdBitCount;                         // 0x0018
    char pad_001C[172];                                  // 0x001C
    eastl::fixed_vector<ServerPlayer*, 64> m_players;    // 0x00C8
    eastl::fixed_vector<ServerPlayer*, 64> m_spectators; // 0x00C8

    ServerPlayer* GetPlayerOrSpectator(uint64_t id);
    ServerPlayer* GetPlayerOrSpectator(const char* name);

    ServerPlayer* GetPlayer(const char* name);
    ServerPlayer* GetSpectator(const char* name);

    ServerPlayer* GetPlayer(uint64_t id, bool includeAI = false);
    ServerPlayer* GetSpectator(uint64_t id);
}; // Size: 0x07EC

class ServerPlayerEvent : public PlayerEventBase
{
public:
    KB_DECLARE_GAMEMEMBERFUNC(0x140C0CD10, void, init, (player, eventId), const ServerPlayer* player, EventId eventId)

    TypeInfo* getType() const override
    {
        return (TypeInfo*)0x1444E6210;
    }

    const void* getPlayer() const override
    {
        return m_playerRef; // Invalid! Need to retrieve from the WeakPtr
    }

    bool m_sendToPlayerOnly;
    bool m_sendToHostOnly;
    bool m_sendToTeamOnly;
    bool m_invertPlayerFilter;
    bool m_invertTeamFilter;
    bool m_forwardToSpectators;
    uint32_t m_team;
    void* m_playerRef;
    char buf[200];
};

enum SecureReason;

class EngineConnection
{
public:
};

class ServerConnection : EngineConnection
{
public:
    KB_DECLARE_GAMEMEMBERFUNC(0x140BF6460, ServerPlayer*, GetPlayer, (playerId, allowFail), LocalPlayerId playerId, bool allowFail)
    KB_DECLARE_GAMEMEMBERFUNC(0x140BFA820, void*, ValidateLocalPlayer, (playerId, allowFail), LocalPlayerId playerId, bool allowFail)
    void SafeDisconnect(const char* reasonText, SecureReason reason);
    void SafeDisconnect(const char* reasonText);

private:
    char pad_0000[0x5FAD];              // 0x0000
    bool m_shouldDisconnect;            // 0x5FAD
    char pad_5FAD[0x2];                 // 0x5FAE
    uint32_t m_disconnectReason;        // 0x5FB0
    char pad_5FB4[0x4];                 // 0x5FB4
    char* m_disconnectText;             // 0x5FB8
};

class ClientConnection : EngineConnection
{
public:
};

class Message : public TypeObject
{
public:
    const int category;             // 0x08
    const int type;                 // 0x0C
    LocalPlayerId localPlayerId;    // 0x10
    char pad_0014[0x1C];            // 0x14

    bool Is(const char* messageType) const
    {
        return type == StringUtils::HashQuick(messageType);
    }
}; // Size: 0x30

class NetworkableMessage : public Message
{
public:
    ServerConnection* serverConnection; // 0x30
    void* clientConnection;             // 0x38
    int32_t unk1;                       // 0x40
    int32_t initiator;                  // 0x44
    int32_t messageStream;              // 0x48
    int32_t unk2;                       // 0x4C
    bool hasNetworkedResources;         // 0x50
    char pad_0051[0x7];                 // 0x51
}; // Size: 0x58

class NetworkPlayerSpawnMessage : public NetworkableMessage
{};

class EventSyncReachedClientMessage : public NetworkableMessage
{
public:
    uintptr_t ghostPtr;             // 0x58
    uint32_t data;                  // 0x60
    uint32_t bus;                   // 0x64
};

class ServerPlayerChatMessage : public Message
{
public:
    char pad_0030[8];             // 0x0030
    class ServerPlayer* m_sender; // 0x0038
    char pad_0040[8];             // 0x0040
    char* m_message;              // 0x0048
    char pad_0050[304];           // 0x0050
}; // Size: 0x0180

class ServerPlayerDisconnectMessage : public Message
{
public:
    class ServerPlayer* m_player; // 0x0030
    char pad_0038[328];           // 0x0038
}; // Size: 0x0180

class ServerPlayerAboutToCreateForConnectionMessage : public Message
{
public:
    char pad_0030[8];             // 0x0030
    char* requestedName; // 0x0038
};

class NetworkCreatePlayerMessage : public NetworkableMessage
{
public:
    char* playerName;  // 0x0058
    bool isSpectator;  // 0x0060
}; // Size: 0x68

struct Win32Buffer
{
    char pad_0000[256]; // 0x0000
    int64_t available;  // 0x0100
};

class PartitionInitData
{
public:
    MemoryArena* arena;             // 0x0000
    Guid partitionGuid;             // 0x0008
    DataContainer* primaryInstance; // 0x0018
    eastl::vector<DataContainer*> instances;
    void* blob;
    bool immutable;
};

class EbxPartitionReader
{
public:
    void* m_domain;               // 0x0000
    void* m_lazyResolver;         // 0x0008
    char* m_partitionName;        // 0x0010
    MemoryArena* m_fixupArena;    // 0x0018
    uint16_t m_compartment;       // 0x0020
    uint16_t N00000108;           // 0x0022
    uint32_t m_bytesRemain;       // 0x0024
    PartitionInitData m_initData; // 0x0028
    uint32_t m_currentState;      // 0x0078
    char pad_00B0[184];           // 0x00B0
}; // Size: 0x0168

struct StringBuilder
{
    uint64_t a1;
    uint64_t a2;
    uint64_t a3;
};

std::string ToString(Realm realm);

class EntityBase : public TypeObject
{
public:
    void* m_linkPrev;
    void* m_linkNext;
    uint64_t m_flags;

    bool IsSpatial() const;
    bool IsComponent() const;

    class EntityBus* GetEntityBus() const;
    const GameObjectData* GetData() const;

    void FireEvent(EntityEvent* event);
    void Event(EntityEvent* event);

    Realm GetRealm() const
    {
        return Realm(m_flags & (1 << 0));
    }
};

class NativeEntity : public EntityBase
{
public:
    class EntityBus* m_entityBus;
    const GameObjectData* m_data;

    // Research:
    // isAIPlayer: vtable 14
    // isAlive: vtable 6

    void Init();
};

class SpatialEntity : public EntityBase
{
public:
    char pad_0020[16]; // 0x0020

    class EntityBus* m_entityBus;
    const GameObjectData* m_data;

    void GetTransform(LinearTransform& transform) const;
    void SetTransform(const LinearTransform& transform);
};

struct EntityOwner
{
    void* qword0;
    void* qword8;
    void* qword10;
    EntityOwner* m_parent;
    NativeEntity* m_owner;
    EntityOwner* m_firstChild;
    EntityOwner* m_nextSibling;
    uintptr_t m_prevSibling;
    void* m_subLevel;
    void* qword48;
    void* dword50;

    NativeEntity* GetOwnedEntity(const DataContainer* entityData, EntityBus* bus = nullptr);

    eastl::vector<NativeEntity*> GetOwnedEntities(EntityBus* bus = nullptr);
    eastl::vector<NativeEntity*> GetOwnedEntitiesRecursively();

    void DestroyEntity(NativeEntity* entity);

    void DeinitOwnedEntities(void* info);

    void DestroyOwnedEntities(Realm realm);
    void DestroyOwnedEntitiesRecursively(Realm realm);
};

class EntityBus : public TypeObject
{
public:
    EntityOwner* m_owner;
    EntityBus* m_parentBus;
    void* m_transformSpace;
    EntityBus* m_prevSibling;
    EntityBus* m_nextSibling;
    EntityBus* m_firstChild;
    int m_refCount;
    Realm realm;
    NativeEntity** m_peers;
    char pad[0x30];
    uintptr_t m_entityBusBridgeOrExposedObject;

    Realm GetRealm() const
    {
        return (Realm)(((realm & 0xF7FFFFFF) >> 0x1C) & 1);
    }

    eastl::vector<EntityBus*> GetAllChildBusses() const;

    EntityBase* GetExposedPeer() const;
    DataContainer* GetExposedPeerData() const;
    
    uintptr_t GetEntityBusBridge() const
    {
        return (m_entityBusBridgeOrExposedObject & 1) == 0 ? m_entityBusBridgeOrExposedObject : 0;
    }

    DataContainer* GetExposedObject() const
    {
        return reinterpret_cast<DataContainer*>(
            (m_entityBusBridgeOrExposedObject & 1) != 0 ? (m_entityBusBridgeOrExposedObject & (~uintptr_t(1))) : 0);
    }
};

class SubLevel : public EntityOwner
{
public:
    MemoryArena* m_arena;       // 0x0058
    Asset* m_subLevelData;      // 0x0060
    uint16_t m_subLevelId;      // 0x0068
    char pad_006A[6];           // 0x006A
    SubLevel* m_child;          // 0x0070
    SubLevel* m_sibling;        // 0x0078
    EntityBus* m_rootEntityBus; // 0x0080
};

struct EntityInitInfo
{
    char pad[64];
};

class RenderView
{
public:
    LinearTransform transform;      // 0x0000
    char pad_0040[112];             // 0x0040
    float fovRad;                   // 0x00B0
    char pad_00B4[76];              // 0x00B4
    glm::mat4 viewMatrix;           // 0x0100
    glm::mat4 N000006BC;            // 0x0140
    glm::mat4 N000006BD;            // 0x0180
    glm::mat4 N000006BE;            // 0x01C0
    glm::mat4 N000006BF;            // 0x0200
    glm::mat4 N000006C0;            // 0x0240
    glm::mat4 N000006C1;            // 0x0280
    glm::mat4 N000006C2;            // 0x02C0
    char pad_0300[32];              // 0x0300
    glm::vec3 cameraPos;            // 0x0320
    char pad_032C[148];             // 0x032C
    glm::mat4 projectionMatrix;     // 0x03C0
    char pad_0400[48];              // 0x0400
    glm::mat4 viewProjectionMatrix; // 0x0430

    char pad_0470[7328]; // 0x0470
}; // Size: 0x2110

class GameRenderer
{
public:
    char pad_0008[1288];          // 0x0008
    void* gameRenderSettings;     // 0x0510
    char pad_0518[32];            // 0x0518
    class RenderView* renderView; // 0x0538
    char pad_0540[2880];          // 0x0540

    virtual void Function0();

    static GameRenderer* Get()
    {
        return *reinterpret_cast<GameRenderer**>(OFFSET_GAME_RENDERER);
    }
};

class Camera : public TypeObject
{
public:
    char pad_0000[96];           // 0x0000
    DataContainer* m_data;       // 0x0068
    char pad_0070[176];          // 0x0070
    LinearTransform m_transform; // 0x0120
}; // Size: 0x0480

class WeaponFiring : public TypeObject
{
public:
    void SetPrimaryAmmoMags(int mags) const;
};

class ServerSoldierWeapon : public TypeObject
{
public:
    WeaponFiring* GetWeaponFiring() const
    {
        return *reinterpret_cast<WeaponFiring**>(reinterpret_cast<intptr_t>(this) + 0xDB8);
    }
};

class ServerCharacterEntity : public TypeObject 
{
public:
    HealthComponent* GetHealthComponent() const
    {
        return *reinterpret_cast<HealthComponent**>(reinterpret_cast<intptr_t>(this) + 0x2C0);
    }

    KB_DECLARE_GAMEMEMBERFUNC(0x140C25490, void*, Teleport, (transform, a3), const LinearTransform& transform, bool a3)
    KB_DECLARE_GAMEMEMBERFUNC(0x147ECBEC0, void, ForceInvisible, (forceInvisible), bool forceInvisible)
    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x147ECA8E0, ServerSoldierWeapon*, GetCurrentWeapon)

    void Teleport(const LinearTransform& trans)
    {
        Teleport(trans, false);
    }
};

class ServerVehicleEntity : public TypeObject
{
public:
    void Teleport(const LinearTransform& trans);
};

// Messages Below

struct PlayerKilledMessage_Info
{
    char gap0[0x28];
    Asset* killerWeapon;
    char gap30[0x30];
    Asset* killerKit;
};

class ServerPlayerKilledMessage : public Message
{
public:
    char gap30[0x04]; // 0x30
    unsigned int m_reviveePlayerId; // 0x34
    char gap38[0x08]; // 0x38
    ServerPlayer* m_victimPlayer; // 0x40
    PlayerKilledMessage_Info* m_deathInfo; // 0x48
    ServerPlayer* m_inflictorPlayer;       // 0x50
    char* m_weaponName;                    // 0x58 // not full path, name of asset. Literally just "U_Ability_B1_E5_AI"
    char gap60[0x18]; // 0x60
    void* pointlessPtrToNetworkableMessage; // 0x78 // literally a ptr to NetworkableMessage::NetworkableMessage
}; // Size: 0x80

enum WeaponSlot
{
    WeaponSlot_0,         // 0x0000
    WeaponSlot_1,         // 0x0001
    WeaponSlot_2,         // 0x0002
    WeaponSlot_3,         // 0x0003
    WeaponSlot_4,         // 0x0004
    WeaponSlot_5,         // 0x0005
    WeaponSlot_6,         // 0x0006
    WeaponSlot_7,         // 0x0007
    WeaponSlot_8,         // 0x0008
    WeaponSlot_9,         // 0x0009
    WeaponSlot_NumSlots,  // 0x000A
    WeaponSlot_NotDefined // 0x000B
};


struct SoldierServerPlayerExtent : ServerPlayerExtent
{
    struct PlayerWeapon
    {
        Asset* asset;
    };

    char gap0[1928];
    eastl::fixed_vector<PlayerWeapon, WeaponSlot_NumSlots> m_weapons;
};

struct WSServerSoldierSpawnDoneMessage : public Message
{
    void* wsServerSoldierEntity; // :(
};

struct ServerPlayerRespawnMessage : public Message
{
    ServerPlayer* player; // 0x0030 // :D
}; // Size: 0x38

struct WSServerBattlepointsChangedMessage : public Message
{
    ServerPlayer* player; // 0x0030
    int32_t changeAmount; // 0x0038
    uint32_t pad1;        // 0x003C
}; // Size: 0x40

struct PlayerAbilityPickedUpMessage : public Message
{
    char pad_030[0x28];   // 0x0030
    uint32_t abilityId;   // 0x0058
    uint32_t unk1;        // 0x005C
    uint64_t playerId;    // 0x0060
    uint32_t playerAbilityCategory; // 0x0068
    uint32_t alwaysOne; // 0x006C
}; // Size: 0x38

struct NetworkSettingsMessage : public NetworkableMessage
{
    uint32_t N000008D6;                // 0x0058
    float N000008DC;                   // 0x005C
    char pad_0060[24];                 // 0x0060
}; // Size: 0x00C8

// note to all those who attempt to look into it: NetworkChangeGameSettingMessage is a scam. 
// it does nothing. its for unused profile options.

} // namespace Kyber
