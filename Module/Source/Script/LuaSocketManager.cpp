// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

#include <winsock2.h>
#define _WINSOCKAPI_
#include <Script/LuaSocketManager.h>
#include <Hook/HookManager.h>

#include <Core/Program.h>
#include <SDK/Funcs.h>

#include <winerror.h>
#include <winsock.h>

namespace Kyber
{
template<>
void LuaUtils::Push<SOCKET>(lua_State* L, SOCKET value)
{
    LuaSocketManager::WrapSocket(L, value);
    luaL_getmetatable(L, "WinSocket");
    lua_setmetatable(L, -2);
}

SOCKET LuaSocketManager::GetSocket(lua_State* L, int index)
{
    if (!lua_isuserdata(L, index))
    {
        luaL_error(L, "Expected userdata for socket, got %s", lua_typename(L, lua_type(L, index)));
        return NULL;
    }

    SOCKET* userdata = (SOCKET*)lua_touserdata(L, index);
    if (userdata == NULL)
    {
        luaL_error(L, "Expected userdata for socket");
        return NULL;
    }

    return *userdata;
}

const SOCKET* LuaSocketManager::WrapSocket(lua_State* L, const SOCKET socket)
{
    SOCKET* userdata = (SOCKET*)lua_newuserdata(L, sizeof(SOCKET));
    *userdata = socket;
    return userdata;
}

static int WinSocketCreate(lua_State* L)
{
    if (!lua_isinteger(L, 1))
    {
        luaL_error(L, "Expected integer for port");
        return 0;
    }
    int port = luaL_checknumber(L, 1);

    SOCKET winSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (winSock == INVALID_SOCKET)
    {
        luaL_error(L, "Failed to create socket");
        return 0;
    }

    u_long mode = 1;
    ioctlsocket(winSock, FIONBIO, &mode);

    sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(winSock, (sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR)
    {
        closesocket(winSock);
        luaL_error(L, "Failed to bind socket");
        return 0;
    }

    if (listen(winSock, SOMAXCONN) == SOCKET_ERROR)
    {
        closesocket(winSock);
        luaL_error(L, "Failed to listen on socket");
        return 0;
    }

    LuaUtils::Push(L, winSock);
    return 1;
}
static int WinSocketCreateConnect(lua_State* L)
{
    if (!lua_isstring(L, 1))
    {
        luaL_error(L, "Expected string for uri");
        return 0;
    }
    std::string uri = luaL_checkstring(L, 1);

    // For now, we only let plugins connect to local servers
    if (uri != "127.0.0.1")
    {
        luaL_error(L, "Provided uri must be 127.0.0.1");
        return 0;
    }

    if (!lua_isinteger(L, 2))
    {
        luaL_error(L, "Expected integer for port");
        return 0;
    }
    int port = luaL_checkinteger(L, 2);

    // resolve target host
    addrinfo hints;
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    addrinfo* result = nullptr;
    
    // not technically needed rn afaik since we do localhost only, but for future use
    int errorCode = getaddrinfo(uri.c_str(), std::to_string(port).c_str(), &hints, &result);
    if (errorCode != 0)
    {
        luaL_error(L, "Failed to get address info of given uri: %d", errorCode);
        return 0;
    }

    SOCKET winSock = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
    if (winSock == INVALID_SOCKET)
    {
        freeaddrinfo(result);
        luaL_error(L, "Failed to create socket");
        return 0;
    }

    u_long mode = 1;
    ioctlsocket(winSock, FIONBIO, &mode);

    if (connect(winSock, result->ai_addr, result->ai_addrlen) == SOCKET_ERROR)
    {
        int errorCode = WSAGetLastError();
        if (errorCode != WSAEWOULDBLOCK)
        {
            closesocket(winSock);
            freeaddrinfo(result);
            luaL_error(L, "Failed to connect on socket: %d", errorCode);
            return 0;
        }
    }

    freeaddrinfo(result);

    LuaUtils::Push(L, winSock);
    return 1;
}

enum ConnectStatus
{
    Pending = 0,
    Connected = 1,
    Failed = 2
};

static int WinSocketPollConnectionStatus(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);

    fd_set writeSet, exceptSet;
    FD_ZERO(&writeSet);
    FD_ZERO(&exceptSet);
    FD_SET(socket, &writeSet);
    FD_SET(socket, &exceptSet);

    timeval timeout{ 0, 0 }; // zero timeout, no blocking

    int selResult = select(0, nullptr, &writeSet, &exceptSet, &timeout);
    if (selResult == 0)
    {
        lua_pushinteger(L, ConnectStatus::Pending);
        return 1;
    }

    if (selResult == SOCKET_ERROR || FD_ISSET(socket, &exceptSet))
    {
        lua_pushinteger(L, ConnectStatus::Failed);
        return 1;
    }

    if (FD_ISSET(socket, &writeSet))
    {
        int sockErr = 0;
        int optLen = sizeof(sockErr);
        getsockopt(socket, SOL_SOCKET, SO_ERROR, (char*)&sockErr, &optLen);
        lua_pushinteger(L, (sockErr == 0) ? ConnectStatus::Connected : ConnectStatus::Failed);
        return 1;
    }

    lua_pushinteger(L, ConnectStatus::Pending);
    return 1;
}

static int WinSocketIsOutgoingConnectionUsable(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);

    int sockErr = 0;
    int optLen = sizeof(sockErr);
    lua_pushboolean(L, getsockopt(socket, SOL_SOCKET, SO_ERROR, (char*)&sockErr, &optLen) == 0);
    return 1;
}

static int WinSocketAccept(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);

    SOCKET clientSocket = accept(socket, nullptr, nullptr);
    if (clientSocket == INVALID_SOCKET)
    {
        if (WSAGetLastError() == WSAEWOULDBLOCK)
        {
            lua_pushnil(L);
            return 1;
        }

        luaL_error(L, "Failed to accept client socket");
        return 0;
    }

    LuaUtils::Push(L, clientSocket);
    return 1;
}

static int WinSocketRecv(lua_State* L)
{
    MemoryArena* const bufferArena = FB_GLOBAL_ARENA;

    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    int length = luaL_checkinteger(L, 2);

    char stackbuf[2048];
    char* arenaBuffer = length > 2048 ? static_cast<char*>(bufferArena->alloc(length)) : nullptr;
    char* buffer = arenaBuffer != nullptr ? arenaBuffer : stackbuf;

    int result = recv(socket, buffer, length, 0);
    int errorStatus = WSAGetLastError();
    if (result == SOCKET_ERROR && errorStatus != WSAEWOULDBLOCK)
    {
        bufferArena->free(arenaBuffer);
        luaL_error(L, "Failed to recv from socket: %d", errorStatus);
        return 0;
    }
    else if (result == SOCKET_ERROR && errorStatus == WSAEWOULDBLOCK)
    {
        // Intentionally push nil to signify it isn't ready yet
        bufferArena->free(arenaBuffer);
        lua_pushnil(L);
        return 1;
    }
    else if (result == 0)
    {
        bufferArena->free(arenaBuffer);
        lua_pushlstring(L, nullptr, 0);
        return 1;
    }

    lua_pushlstring(L, buffer, result);
    bufferArena->free(arenaBuffer);
    return 1;
}

static int WinSocketSend(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    const char* data = luaL_checkstring(L, 2);

    int result = send(socket, data, strlen(data), 0);
    if (result == SOCKET_ERROR)
    {
        luaL_error(L, "Failed to send to socket: %d", WSAGetLastError());
        return 0;
    }

    lua_pushinteger(L, result);
    return 1;
}

static int WinSocketClose(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    closesocket(socket);
    return 0;
}

static int WinSocketShutdown(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);

    int result = shutdown(socket, SD_BOTH);
    if (result == SOCKET_ERROR)
    {
        KYBER_LOG(Error, "Socket failed to shutdown");
        closesocket(socket);
        WSACleanup();
    }

    return 0;
}

static int WinSocketShutdownSend(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);

    int result = shutdown(socket, SD_SEND);
    if (result == SOCKET_ERROR)
    {
        KYBER_LOG(Error, "Socket failed to shutdown");
        closesocket(socket);
        WSACleanup();
    }

    return 0;
}

static int WinSocketIndex(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    std::string key = luaL_checkstring(L, 2);

    if (key == "Accept")
    {
        lua_pushcfunction(L, WinSocketAccept);
        return 1;
    }
    else if (key == "Recv")
    {
        lua_pushcfunction(L, WinSocketRecv);
        return 1;
    }
    else if (key == "Send")
    {
        lua_pushcfunction(L, WinSocketSend);
        return 1;
    }
    else if (key == "Close")
    {
        lua_pushcfunction(L, WinSocketClose);
        return 1;
    }
    else if (key == "Shutdown")
    {
        lua_pushcfunction(L, WinSocketShutdown);
        return 1;
    }
    else if (key == "PollConnectionStatus")
    {
        lua_pushcfunction(L, WinSocketPollConnectionStatus);
        return 1;
    }
    else if (key == "IsOutgoingConnectionUsable")
    {
        lua_pushcfunction(L, WinSocketIsOutgoingConnectionUsable);
        return 1;
    }
    else if (key == "ShutdownSend")
    {
        lua_pushcfunction(L, WinSocketShutdownSend);
        return 1;
    }

    return 0;
}

static const luaL_Reg s_winSocketMeta[] = { { "__index", WinSocketIndex }, { "__gc", WinSocketClose }, { NULL, NULL } };
static const luaL_Reg s_socketManagerFuncs[] = { { "Create", WinSocketCreate }, { "CreateConnect", WinSocketCreateConnect }, { NULL, NULL } };

void LuaSocketManager::Register(lua_State* L)
{
    luaL_newmetatable(L, "WinSocket");
    luaL_setfuncs(L, s_winSocketMeta, 0);

    KB_LUA_NEW_GLOBAL_LIB(L, "SocketManager", s_socketManagerFuncs);
}

KB_REGISTER_LUA_CONTENT_MANAGER(LuaSocketManager);
} // namespace Kyber
