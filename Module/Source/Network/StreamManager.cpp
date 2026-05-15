// Copyright Armchair Developers. Licensed under GPLv3.

#include <Network/StreamManager.h>

#include <Base/Log.h>
#include <Core/Program.h>
#include <Hook/HookManager.h>

#include <bit>

namespace Kyber
{
TL_DECLARE_FUNC(0x146C38B40, void, StreamManagerEngine_addManager, void* engine, void* manager)

uint32_t GetRequiredBits(uint32_t value)
{
    return 31 - std::countl_zero(value);
}

uint32_t GetRequiredBits(uint64_t value)
{
    return 63 - std::countl_zero(value);
}

uint64_t BitStreamRead::ReadUnsignedLimit64(uint64_t lowerBound, uint64_t upperBound)
{
    const int neededBits = GetRequiredBits(upperBound - lowerBound);
    if (!neededBits)
    {
        return 0;
    }

    uint64_t out = ReadStream(neededBits > 32 ? 32 : neededBits);
    if (neededBits > 32)
    {
        out |= uint64_t(ReadStream(neededBits - 32)) << 32;
    }

    return lowerBound + out;
}

void BitStreamWrite::WriteUnsignedLimit64(uint64_t value, uint64_t lowerBound, uint64_t upperBound)
{
    KYBER_ASSERT(upperBound >= lowerBound);

    const int neededBits = GetRequiredBits(upperBound - lowerBound);
    if (!neededBits)
    {
        return;
    }

    uint64_t outValue = value - lowerBound;
    uint32_t loValue = uint32_t(outValue & UINT32_MAX);
    uint32_t hiValue = (outValue & loValue) >> 32;
    WriteStream(loValue, neededBits > 32 ? 32 : neededBits);
    if (neededBits > 32)
    {
        WriteStream(hiValue, neededBits - 32);
    }
}

void ServerConnectionOnInitManagersHk(ServerConnection* connection, __int64 a2, __int64 a3)
{
    static const auto trampoline = HookManager::Call(ServerConnectionOnInitManagersHk);

    StreamManagerKyberEvent* manager = new (FB_SERVER_ARENA) StreamManagerKyberEvent(g_program->m_server->m_eventManager);
    StreamManagerEngine_addManager(&connection->m_streamManagerEngine, manager);

    trampoline(connection, a2, a3);
}

void ClientConnectionOnInitManagersHk(ClientConnection* connection)
{
    static const auto trampoline = HookManager::Call(ClientConnectionOnInitManagersHk);

    StreamManagerKyberEvent* manager = new (FB_CLIENT_ARENA) StreamManagerKyberEvent(g_program->m_client->m_eventManager);
    StreamManagerEngine_addManager(&connection->m_streamManagerEngine, manager);

    trampoline(connection);
}

void StreamManagerKyberEvent::InitializeHooks()
{
    HookManager::CreateHook(HOOK_OFFSET(0x14688F550), ServerConnectionOnInitManagersHk);
    HookManager::CreateHook(HOOK_OFFSET(0x1469F4CB0), ClientConnectionOnInitManagersHk);
}

void ServerStreamedEventManager::SendInternal(ServerConnection* connection, std::type_index typeId, KyberStreamedEvent* event)
{
    auto streamManager = static_cast<StreamManagerKyberEvent*>(connection->GetStreamManagerByName(StreamManagerKyberEvent::Name));
    if (streamManager == nullptr)
    {
        KYBER_LOG(Error, "Kyber event manager not found");
        return;
    }

    streamManager->AddEvent(typeId, event);
}

void ServerStreamedEventManager::BroadcastInternal(std::type_index typeId, KyberStreamedEvent* event)
{
    for (auto& player : g_program->m_server->m_playerManager->m_players)
    {
        ServerConnection* connection = g_program->m_server->GetServerGameContext()->serverPeer->GetConnectionForPlayer(player);
        SendInternal(connection, typeId, event);
    }

    // for (auto& connection : g_program->m_server->GetServerGameContext()->serverPeer->m_connections)
    //{
    //     SendInternal(connection, typeId, event);
    // }
}

void ClientStreamedEventManager::SendInternal(std::type_index typeId, KyberStreamedEvent* event)
{
    OnlineManager* onlineManager = ClientGameContext::Get()->GetOnlineManager();
    if (onlineManager == nullptr)
    {
        KYBER_LOG(Error, "Client online manager not found on streamed event send attempt");
        return;
    }

    ClientConnection* clientConnection = onlineManager->GetClientConnection();
    if (clientConnection == nullptr)
    {
        KYBER_LOG(Error, "Client connection not found on streamed event send attempt");
        return;
    }

    auto streamManager = static_cast<StreamManagerKyberEvent*>(clientConnection->GetStreamManagerByName(StreamManagerKyberEvent::Name));

    streamManager->AddEvent(typeId, event);
}

KyberStreamedEvent* KyberStreamedEventRegistry::Construct(MemoryArena* arena, HashCode hashCode)
{
    const auto it = m_registry.find(hashCode);
    if (it == m_registry.end())
    {
        KYBER_LOG(Debug, "Constructed event that does not exist with hash code: " << std::hex << hashCode);
        return nullptr;
    }

    return it->second(arena);
}

StreamManagerKyberEvent::StreamManagerKyberEvent(EventManager* eventManager)
    : m_eventManager(eventManager)
    , m_statusAcknowledged(true)
{}

void StreamManagerKyberEvent::AddEvent(std::type_index index, KyberStreamedEvent* event)
{
    m_eventQueue.push_back(EventRecord(index, event));
}

bool StreamManagerKyberEvent::ProcessReceivedPacket(BitStreamRead* stream)
{
    uint32_t hashCode = stream->ReadUnsigned(32);
    KyberStreamedEvent* event = KyberStreamedEventRegistry::Get().Construct(FB_GLOBAL_ARENA, hashCode);
    if (event == nullptr)
    {
        return false;
    }

    event->Read(stream);
    m_eventManager->QueueEvent(event);
    return true;
}

void StreamManagerKyberEvent::HandlePacketStatus(PacketDeliveryStatus status, TransmissionRecord* record)
{
    if (record == nullptr)
    {
        return;
    }

    m_statusAcknowledged = true;

    if (status == PacketDeliveryStatus_Failed)
    {
        return;
    }

    EventRecord* eventRecord = static_cast<EventRecord*>(record);
    if (eventRecord != &m_eventQueue.front())
    {
        KYBER_LOG(Warning, "Invalid event ordering");
        return;
    }

    m_eventQueue.pop_front();
}

TransmitResult StreamManagerKyberEvent::TransmitPacket(BitStreamWrite* stream, TransmissionRecord** record)
{
    if (!m_statusAcknowledged || m_eventQueue.empty())
    {
        return TransmitResult_Nothing;
    }

    EventRecord& eventRecord = m_eventQueue.front();

    KYBER_LOG(Debug, "Trasmitting event record of type " << eventRecord.typeId.name());
    uint32_t hashCode = StringUtils::HashQuick(eventRecord.typeId.name());
    stream->WriteUnsigned(hashCode, 32);
    eventRecord.event->Write(stream);

    *record = &eventRecord;
    m_statusAcknowledged = false;

    return TransmitResult_Whole;
}
} // namespace Kyber
