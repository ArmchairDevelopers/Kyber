// Copyright BattleDash. All Rights Reserved.

#pragma once

#include <string>

namespace Kyber
{
class UDPSocket;

class SocketCreator
{
public:
    virtual void Close(UDPSocket* socket) = 0;
};

enum class ProtocolDirection
{
    Serverbound,
    Clientbound
};
} // namespace Kyber