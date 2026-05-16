// Copyright Armchair Developers / MagixGames. Licensed under GPLv3.

#pragma once

#include <Network/StreamManager.h>

namespace Kyber
{
class KyberSetGroupMembersEvent : public KyberStreamedEvent
{
public:
    void Write(BitStreamWrite* stream) override
    {
        stream->WriteUnsignedLimit(m_groupMembers.size(), 0, 64);
        for (int i = 0; i < m_groupMembers.size(); i++)
        {
            stream->WriteUnsigned64(m_groupMembers[i], 64);
        }
    }

    void Read(BitStreamRead* stream) override
    {
        int32_t memberCount = stream->ReadUnsignedLimit(0, 64);
        m_groupMembers.reserve(memberCount);
        for (int i = 0; i < memberCount; i++)
        {
            m_groupMembers.push_back(stream->ReadUnsigned64(64));
        }
    }

    eastl::vector<uint64_t> m_groupMembers;
};

KB_REGISTER_STREAMED_EVENT(KyberSetGroupMembersEvent);
} // namespace Kyber