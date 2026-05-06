// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#pragma once

#include <Core/EventManager.h>
#include <SDK/SDK.h>

#include <EASTL/list.h>

#include <cstdint>
#include <functional>
#include <typeindex>

namespace Kyber
{
TL_DECLARE_FUNC(0x14546EB60, uint32_t, BitStream_read, void* stream, uint32_t bitCount);
TL_DECLARE_FUNC(0x145477800, void, BitStream_write, void* stream, uint32_t value, uint32_t bitCount);

uint32_t GetRequiredBits(uint32_t value);
uint32_t GetRequiredBits(uint64_t value);

class InBitStream
{
public:
    bool HasOverflown() const
    {
        return m_overflown;
    }

    char* m_buffer;           // 0x00
    uint32_t m_bufferBitSize; // 0x08
    char pad_00[0x38];        // 0x0C
    bool m_overflown;         // 0x44
};

class BitStreamRead
{
public:
    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x145462FC0, bool, ReadBool)
    KB_DECLARE_GAMEMEMBERFUNC_NOARGS(0x1454721C0, float, ReadFloat)
    KB_DECLARE_GAMEMEMBERFUNC(0x14546EE50, uint32_t, ReadUnsigned, (bitCount), uint32_t bitCount)
    KB_DECLARE_GAMEMEMBERFUNC(0x1454740F0, uint64_t, ReadUnsigned64, (bitCount), uint32_t bitCount)
    KB_DECLARE_GAMEMEMBERFUNC(0x1454722A0, uint32_t, ReadUnsignedLimit, (lowerBound, upperBound), int32_t lowerBound, int32_t upperBound)
    KB_DECLARE_GAMEMEMBERFUNC(0x145472420, void, ReadOctets, (data, size), void* data, uint32_t size)

    template<uint32_t Capacity>
    eastl::string ReadString()
    {
        constexpr int neededBits = GetRequiredBits(Capacity);

        uint32_t size = ReadUnsigned(neededBits);
        eastl::string str(size, ' ');
        ReadOctets(const_cast<char*>(str.data()), size);

        return str;
    }

    uint64_t ReadUnsignedLimit64(uint64_t lowerBound, uint64_t upperBound);

    bool HasOverflown() const
    {
        return m_stream->HasOverflown();
    }

private:
    int32_t ReadStream(int32_t bitCount)
    {
        return BitStream_read(m_stream, bitCount);
    }

    char pad_00[0x18];     // 0x00
    InBitStream* m_stream; // 0x18;
};

class OutBitStream
{
public:
    bool HasOverflown() const
    {
        return m_bufferBitSize < m_position;
    }

    bool WouldOverflowWith(uint32_t additionalBits) const
    {
        return m_position + additionalBits > m_bufferBitSize;
    }

    char* m_buffer;
    uint32_t m_bufferBitSize;
    uint32_t m_position;
    char pad_10[0x20];
};

class BitStreamWrite
{
public:
    KB_DECLARE_GAMEMEMBERFUNC(0x145477BC0, bool, WriteBool, (value), bool value)
    KB_DECLARE_GAMEMEMBERFUNC(0x145478740, void, WriteFloat, (value), float value)
    KB_DECLARE_GAMEMEMBERFUNC(0x145478D90, void, WriteUnsigned, (value, bits), uint32_t value, uint32_t bits)
    KB_DECLARE_GAMEMEMBERFUNC(0x14547ADC0, void, WriteUnsigned64, (value, bits), uint64_t value, uint32_t bits)
    KB_DECLARE_GAMEMEMBERFUNC(
        0x145478E50, void, WriteUnsignedLimit, (value, lowerBound, upperBound), uint32_t value, uint32_t lowerBound, uint32_t upperBound)
    KB_DECLARE_GAMEMEMBERFUNC(0x145479360, void, WriteOctets, (data, size), void* data, uint32_t size)

    template<uint32_t Capacity>
    void WriteString(const eastl::string& str)
    {
        KYBER_ASSERT(str.size() <= Capacity);

        const int neededBits = GetRequiredBits(Capacity);
        WriteUnsigned(str.size(), neededBits);
        WriteOctets(const_cast<char*>(str.data()), str.size());
    }

    void WriteUnsignedLimit64(uint64_t value, uint64_t lowerBound, uint64_t upperBound);

    bool HasOverflown() const
    {
        return m_stream->HasOverflown();
    }

private:
    void WriteStream(uint32_t value, int32_t bitCount)
    {
        BitStream_write(m_stream, value, bitCount);
    }

    char pad_00[0x18];      // 0x00
    OutBitStream* m_stream; // 0x18
};

struct TransmissionRecord
{};

enum PacketDeliveryStatus
{
    PacketDeliveryStatus_Failed,
    PacketDeliveryStatus_Succeeded,
    PacketDeliveryStatus_Discarded
};
enum TransmitResult
{
    TransmitResult_Whole,
    TransmitResult_Incomplete,
    TransmitResult_IncompleteContinue,
    TransmitResult_Nothing
};

class IStreamManager
{
public:
    virtual ~IStreamManager() = default;

    virtual bool ProcessReceivedPacket(BitStreamRead* stream)
    {
        return false;
    }
    virtual bool ProcessReceivedPacket(BitStreamRead* stream, void* ctx)
    {
        return ProcessReceivedPacket(stream);
    }

    virtual void HandlePacketStatus(PacketDeliveryStatus status, TransmissionRecord* record) = 0;

    virtual void PreTransmitPacket() {}
    virtual TransmitResult TransmitPacket(BitStreamWrite* stream, TransmissionRecord** record)
    {
        return TransmitResult_Nothing;
    }
    virtual TransmitResult TransmitPacket(BitStreamWrite* stream, TransmissionRecord** record, void* ctx)
    {
        return TransmitPacket(stream, record);
    }
    virtual void PostTransmitPacket() {}

    virtual const char* GetName() = 0;
    virtual bool BandwidthLimited()
    {
        return false;
    }
};

class KyberStreamedEvent : public Event
{
public:
    virtual void Read(BitStreamRead* stream) = 0;
    virtual void Write(BitStreamWrite* stream) = 0;
};

class KyberStreamedEventRegistry
{
public:
    using HashCode = uint32_t;
    using Func = std::function<KyberStreamedEvent*(MemoryArena*)>;

    static KyberStreamedEventRegistry& Get()
    {
        static KyberStreamedEventRegistry instance;
        return instance;
    }

    void Register(HashCode hashCode, Func func)
    {
        m_registry[hashCode] = func;
    }

    KyberStreamedEvent* Construct(MemoryArena* arena, HashCode hashCode);

private:
    std::unordered_map<HashCode, Func> m_registry;
};

class KyberStreamedEventStaticRegistrar
{
public:
    KyberStreamedEventStaticRegistrar(KyberStreamedEventRegistry::HashCode hashCode, KyberStreamedEventRegistry::Func func)
    {
        KyberStreamedEventRegistry& data = KyberStreamedEventRegistry::Get();
        data.Register(hashCode, func);
    }
};

#define KB_REGISTER_STREAMED_EVENT(type)                                                                                                   \
    static KyberStreamedEventStaticRegistrar _##type##_streamedEventRegistrar(                                                             \
        StringUtils::HashQuick(std::type_index(typeid(type)).name()), [](MemoryArena* arena) { return new (arena) type(); })

class ServerStreamedEventManager
{
public:
    template<typename T>
        requires std::is_base_of_v<KyberStreamedEvent, T>
    static void Send(ServerConnection* connection, T* event)
    {
        SendInternal(connection, typeid(T), event);
    }

    template<typename T>
        requires std::is_base_of_v<KyberStreamedEvent, T>
    static void Broadcast(T* event)
    {
        BroadcastInternal(typeid(T), event);
    }

private:
    static void SendInternal(ServerConnection* connection, std::type_index typeId, KyberStreamedEvent* event);
    static void BroadcastInternal(std::type_index typeId, KyberStreamedEvent* event);
};

class ClientStreamedEventManager
{
public:
    template<typename T>
        requires std::is_base_of_v<KyberStreamedEvent, T>
    static void Send(T* event)
    {
        SendInternal(typeid(T), event);
    }

private:
    static void SendInternal(std::type_index typeId, KyberStreamedEvent* event);
};

class StreamManagerKyberEvent : public IStreamManager
{
public:
    static constexpr const char* Name = "KyberEvent";

    StreamManagerKyberEvent(EventManager* eventManager);
    ~StreamManagerKyberEvent() override = default;

    bool ProcessReceivedPacket(BitStreamRead* stream) override;
    void HandlePacketStatus(PacketDeliveryStatus status, TransmissionRecord* record) override;
    TransmitResult TransmitPacket(BitStreamWrite* stream, TransmissionRecord** record) override;

    const char* GetName() override
    {
        return Name;
    }

    virtual bool BandwidthLimited() override
    {
        return true;
    }

    void AddEvent(std::type_index index, KyberStreamedEvent* event);

    static void InitializeHooks();

private:
    struct EventRecord : TransmissionRecord
    {
        EventRecord(std::type_index typeId, KyberStreamedEvent* event)
            : typeId(typeId)
            , event(event)
        {}

        std::type_index typeId;
        KyberStreamedEvent* event;
    };

    EventManager* m_eventManager;
    eastl::list<EventRecord> m_eventQueue;
    bool m_statusAcknowledged;
};
} // namespace Kyber