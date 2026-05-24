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
Kyber.dll server -> directed subnet broadcast (e.g. 192.168.1.255:25201) per eligible interface -> Launcher LAN browser
```

For each eligible IPv4 subnet, the Module binds the beacon socket to the interface address and sends one UDP packet to that subnet's broadcast address. Subnets are deduplicated (Ethernet is preferred over Wi-Fi on the same `/24`). Virtual adapters (WSL, Hyper-V, Docker, VPN overlays, and similar) are excluded by default.

This works for both Launcher-hosted LAN servers and dedicated servers started from the CLI with `start_server --lan`, because both paths load the Module.

Each discovery UDP datagram starts with a four-byte magic prefix `KYBR`, followed by a UTF-8 JSON body. Clients reject packets that do not match this prefix before parsing JSON.

The beacon payload is compatible with the Launcher LAN browser and currently includes:

- `type = kyber_lan_server`;
- server name;
- game port;
- max player count;
- password requirement;
- first map and mode in the rotation;
- an empty `mods` list.

Clients derive the join address from the UDP packet source IP (there is no `ip` field in the Module beacon). The host Launcher reads `preferredLanAddress` from `Common.GetInfo` when the Module is connected.

### Interface selection

Eligible adapters must be up and have a usable IPv4 unicast address (not loopback, not APIPA `169.254.x.x`, not `/32`).

By default, only physical Ethernet and Wi-Fi adapters are used. Adapter friendly names or descriptions matching common virtual patterns (for example `WSL`, `Hyper-V`, `Docker`, `Hamachi`, `VPN`) are ignored.

When multiple adapters share the same subnet, only one beacon is sent for that subnet. The preferred address for display and for `CommonState.preferredLanAddress` follows this order:

1. `192.168.0.0/16`
2. `10.0.0.0/8`
3. `172.16.0.0/12` (private range, after virtual adapters are filtered out)

Set `KYBER_LAN_INCLUDE_VIRTUAL=1` to include virtual adapters when debugging discovery on WSL or VPN interfaces.

`Common.GetInfo` always includes `preferredLanAddress` when the Module can resolve a usable IPv4 interface, even if no server is running yet.

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
