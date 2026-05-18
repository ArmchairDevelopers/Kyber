# Moderation Differences Between Online and LAN Servers

This document describes the Launcher moderation differences between a regular online Kyber server and an offline LAN server.

## General Principle

An online server is controlled through the Kyber API:

```text
Launcher -> API ServerManagement -> server WebSocket -> Module
```

An offline LAN server is controlled locally by the Launcher on the host machine:

```text
Host Launcher -> local gRPC -> Kyber.dll -> server console
```

Only the Launcher on the hosting machine can control the LAN server. Other Launchers on the LAN can discover and join the server, but they do not have access to the local management channel.

## LAN Discovery

LAN discovery is emitted by the server-side Module, not by the host Launcher. When a server runs in offline LAN mode, `Kyber.dll` starts a UDP broadcast beacon on discovery port `25201`.

```text
Kyber.dll server -> UDP broadcast 255.255.255.255:25201 -> Launcher LAN browser
```

This works for both Launcher-hosted LAN servers and dedicated servers started from the CLI with `start_server --lan`, because both paths load the Module.

The beacon payload is compatible with the Launcher LAN browser and currently includes:

- `type = kyber_lan_server`;
- server name;
- game port;
- max player count;
- password requirement;
- first map and mode in the rotation;
- an empty `mods` list.

The game server port defaults to `25200` and can be overridden with `KYBER_SERVER_PORT` in LAN mode. The discovery port remains `25201`.

## Features Preserved in LAN Mode

Actions based on console commands remain available from the host Launcher:

- start the match with `START GAME`;
- skip or reload the map with `SKIP MAP`;
- change the map with `CHANGE MAP`;
- pause or resume the timer;
- change bot settings;
- enable or disable team shuffle;
- move players between teams through commands;
- send console commands;
- send broadcast messages through the console;
- display the player list, refreshed through `Common.GetInfo()`.

These features work because they can be translated into commands sent directly to the local Module with `Common.RunCommand`.

## Features Unavailable or Reduced in LAN Mode

Features that depend on the Kyber API are not available in offline LAN mode:

- adding Kyber moderators;
- removing Kyber moderators;
- moderator list;
- persistent Kyber bans;
- punishment list;
- unban;
- kick/ban through API endpoints;
- online share link based on `server_id`;
- server metadata updates through the API.

These limitations exist because an offline LAN server:

- does not register with the API;
- has no public `server.id`;
- does not connect to the `ServerManagement` WebSocket gateway;
- has no Kyber moderator permissions tied to online accounts.

## Host Tab Behavior

For an online server:

- the Launcher detects `KyberStatusHosting` with a non-empty `serverState.id`;
- it loads the server through the API;
- it opens the moderation WebSocket;
- commands go through `ServerManagement`.

For an offline LAN server:

- the Launcher detects `KyberStatusHosting` with an empty `serverState.id`;
- it selects a local `isLocalLanHost` state;
- it does not open an API WebSocket;
- it refreshes players through local gRPC;
- commands go through `Common.RunCommand`.

## User Impact

There is no feature loss for online servers: the existing path is still used when a `server.id` is available.

In offline LAN mode, moderation is intentionally limited to what the host Launcher can do locally. Features tied to the Kyber API are unavailable because there is no registered online server to support them.

## Quick Summary

| Feature | Online | Offline LAN |
| --- | --- | --- |
| Console commands | Yes | Yes, through local gRPC |
| Start game / skip map / bots | Yes | Yes |
| Player list | Yes, through WebSocket/API | Yes, through `Common.GetInfo()` |
| Kyber moderators | Yes | No |
| Persistent Kyber bans | Yes | No |
| API kick/ban | Yes | No |
| API metadata update | Yes | No |
| Control from remote Launchers | Yes, if allowed by API permissions | No |
| Control from host Launcher | Yes | Yes |
