// Copyright Armchair Developers / Sean Kahler. Licensed under GPLv3.

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

static int WinSocketCreateConnect(lua_State* L)
{
    const char* ipAddress = luaL_checkstring(L, 1);
    if (strcmp(ipAddress, "127.0.0.1") != 0)
    {
        KYBER_LOG(Fatal, ScriptManager::GetPlugin(L)->LogPrefix()
                             << " Plugin attempted to create an unsafe socket (address was not '127.0.0.1', found " << ipAddress << ")");
        return 0;
    }

    int port = luaL_checknumber(L, 2);

    SOCKET winSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (winSock == INVALID_SOCKET)
    {
        luaL_error(L, "Failed to create socket");
        return 0;
    }

    u_long mode = 1;
    ioctlsocket(winSock, FIONBIO, &mode);

    SocketAddr socketAddr(ipAddress, port);
    const sockaddr_in* addr = reinterpret_cast<const sockaddr_in*>(socketAddr.Data());

    if (connect(winSock, (sockaddr*)addr, sizeof(sockaddr_in)) == SOCKET_ERROR && WSAGetLastError() != WSAEWOULDBLOCK)
    {
        luaL_error(L, "Failed to connect to remote address %d", WSAGetLastError());
        closesocket(winSock);
        return 0;
    }

    LuaUtils::Push(L, winSock);
    return 1;
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
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    int length = luaL_checkinteger(L, 2);

    char* buffer = new char[length];
    int result = recv(socket, buffer, length, 0);
    if (result == SOCKET_ERROR)
    {
        if (WSAGetLastError() == WSAEWOULDBLOCK)
        {
            delete[] buffer;
            lua_pushnil(L);
            return 1;
        }

        delete[] buffer;
        luaL_error(L, "Failed to recv from socket: %d", WSAGetLastError());
        return 0;
    }
    else if (result == 0)
    {
        lua_pushlstring(L, "", 0);
        return 1;
    }

    lua_pushlstring(L, buffer, result);
    delete[] buffer;
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
static int WinSocketShutdownSend(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    shutdown(socket, SD_SEND);
    return 0;
}

static int WinSocketClose(lua_State* L)
{
    SOCKET socket = LuaSocketManager::GetSocket(L, 1);
    shutdown(socket, SD_BOTH);
    closesocket(socket);
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
    else if (key == "ShutdownSend")
    {
        lua_pushcfunction(L, WinSocketShutdownSend);
        return 1;
    }

    return 0;
}

static const luaL_Reg s_winSocketMeta[] = { { "__index", WinSocketIndex }, { "__gc", WinSocketClose }, { NULL, NULL } };

void LuaSocketManager::Register(lua_State* L)
{
    luaL_newmetatable(L, "WinSocket");
    luaL_setfuncs(L, s_winSocketMeta, 0);

    luaL_Reg funcs[] = { { "Create", WinSocketCreate }, { "CreateConnect", WinSocketCreateConnect }, { NULL, NULL } };
    LuaUtils::RegisterFunctionTable(L, "SocketManager", funcs);
}
} // namespace Kyber
