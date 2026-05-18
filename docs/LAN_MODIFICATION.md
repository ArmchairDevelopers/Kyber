# LAN Host Changes Summary

This document summarizes the changes added so LAN servers can run without going through the Kyber API. It covers local host control from the Launcher and LAN discovery from the server-side Module.

## Goal

In offline LAN mode, the server does not register with the Kyber API and therefore does not receive a public server id. The usual online control path cannot work:

```text
Launcher -> API ServerManagement -> server WebSocket -> Module
```

The new path directly uses the local interface exposed by `Kyber.dll`:

```text
Host Launcher -> local gRPC -> Kyber.dll -> server console
```

LAN discovery is also server-side:

```text
Kyber.dll server -> UDP broadcast 255.255.255.255:25201 -> Launcher LAN browser
```

This lets dedicated servers started from the CLI with `start_server --lan` appear in the LAN browser even when no Launcher is running on the host machine.

## Modified Files

- `Launcher/lib/features/server_moderation/providers/moderation_cubit.dart`
- `Launcher/lib/features/server_host/screens/server_host.dart`
- `Launcher/lib/features/server_moderation/screens/server_moderation.dart`
- `Launcher/lib/features/server_host/widgets/settings_box/settings_box_header.dart`
- `Module/Public/Network/LanBeacon.h`
- `Module/Source/Network/LanBeacon.cpp`
- `Module/Public/Core/Server.h`
- `Module/Source/Core/Server.cpp`
- `Module/Source/Core/Program.cpp`


## ModerationCubit

Added the `isLocalLanHost` state.

Why: an offline LAN server has no API `server.id` and no `Server` model loaded from the API. This state makes it possible to distinguish a valid local LAN server from a regular online server.

Added `selectLocalLanServer(ServerState serverState)`.

Why: when the local Module reports that the machine is hosting, the Launcher must be able to open the Host tab in management mode even when the API id is empty.

This method:

- closes any existing online WebSocket;
- cancels online timers;
- marks the local LAN server as selected;
- loads the player list from `serverState.playerList`;
- starts a periodic refresh through `Common.GetInfo()`.

Changed `sendCommand()`.

Why: in offline LAN mode, commands must no longer be sent to `ServerManagement`. If `isLocalLanHost` is active, they are sent to the local Module through:

```dart
MaximaGameInstance.clientService.commonClient.runCommand(...)
```

The existing online path is preserved for servers that have an API id.

## ServerHost

Changed `KyberStatusHosting` detection.

Before:

- if `serverState.id` was empty, the Launcher detected hosting but did not select a server in the Host UI.

Now:

- if the id exists, the Launcher uses the online path `selectServer(serverId: ...)`;
- if the id is empty, the Launcher uses `selectLocalLanServer(...)`.

Why: an offline LAN server is a valid local server even without an API id.

## ServerModeration

The screen no longer returns a `Placeholder` when `state.id == null` if `isLocalLanHost == true`.

Why: having no API id is normal for an offline LAN server.

The `MANAGE` tab now displays a message explaining that Kyber moderators and bans require an online server.

Why: these features depend on Kyber accounts, the API, and online moderation permissions.

## SettingsBoxHeader

Blocked `UPDATE SERVER` for a local LAN server.

Why: offline LAN server metadata is not updated through the API. To change the name, password, or information published by the LAN beacon, the LAN server must be restarted.

The host Launcher no longer emits the LAN beacon itself. In LAN mode it still displays the local address and firewall guidance, but discovery broadcasts now come from the Module.

## Module LAN Beacon

Added `LanBeacon`.

Why: Launcher-side discovery did not cover dedicated servers. A dedicated server can be started by the CLI without a host Launcher process, so the beacon must live in the server runtime itself.

This component:

- builds the same `kyber_lan_server` JSON payload consumed by the Launcher LAN browser;
- sends UDP broadcast packets to `255.255.255.255:25201` every 3 seconds;
- starts only when the server is running in offline LAN mode;
- stops when the server stops or the Module is destroyed;
- uses the configured game port from `KYBER_SERVER_PORT`, defaulting to `25200`.

The dedicated-server path in `Program.cpp` now applies the same configured port before spawning the server and starts the beacon after the dedicated server is spawned.

## Verification

Targeted diagnostics were run on the modified files:

- `ReadLints`: no errors.
- targeted `dart analyze`: no blocking errors; only existing style/deprecation info messages.
- `bazelisk --output_user_root="C:\bz" build --config=release Kyber`: successful.
