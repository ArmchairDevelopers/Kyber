import 'dart:async';
import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/server_settings_box.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ModerationCubit extends Cubit<ModerationServerState> {
  ModerationCubit() : super(const ModerationServerState()) {
    botChangeStream = ReplaySubject<(int, int)>();
    botChangeStream!
        .debounceTime(const Duration(milliseconds: 300))
        .listen(
          (event) => sendCommand(
            '/AutoPlayers.ForceFillGameplayBotsTeam${event.$1} ${event.$2}',
          ),
        );
  }

  final _logger = Logger('moderation_cubit');
  Timer? _keepAliveTimer;
  Timer? _localLanRefreshTimer;

  ReplaySubject<(int, int)>? botChangeStream;

  WebSocketChannel? _channel;

  @override
  Future<void> close() {
    unloadServer();
    return super.close();
  }

  Future<void> loadModerators() async {
    if (state.isLocalLanHost) {
      return;
    }

    final moderators = await sl
        .get<KyberGRPCService>()
        .serverManagementClient
        .getModerators(ModeratorsRequest(serverId: state.id));
    emit(state.copyWith(moderators: moderators.users.toList()));
  }

  Future<void> loadPunishments() async {
    if (state.isLocalLanHost) {
      return;
    }

    final punishments = await sl
        .get<KyberGRPCService>()
        .serverManagementClient
        .getPunishments(PunishmentsRequest(serverId: state.id));
    punishments.punishments.sort((a, b) {
      final isAExpired = DateTime.fromMillisecondsSinceEpoch(
        a.expiresAt.toInt(),
      );
      final isBExpired = DateTime.fromMillisecondsSinceEpoch(
        b.expiresAt.toInt(),
      );

      if (isAExpired.isBefore(DateTime.now()) &&
          isBExpired.isBefore(DateTime.now())) {
        return 0;
      }

      if (isAExpired.isBefore(DateTime.now())) {
        return 1;
      }

      if (isBExpired.isBefore(DateTime.now())) {
        return -1;
      }

      return isAExpired.compareTo(isBExpired);
    });
    emit(state.copyWith(punishments: punishments.punishments));
  }

  Future<void> unbanPlayer(String id) async {
    if (state.isLocalLanHost) {
      NotificationService.info(
        message: 'LAN servers do not use Kyber bans.',
      );
      return;
    }

    _logger.info('Unbanning player $id');
    await sl.get<KyberGRPCService>().serverManagementClient.unbanPlayer(
      UnbanPlayerRequest(userId: id, serverId: state.id),
    );

    await loadPunishments();
  }

  Future<void> promotePlayer(String id) {
    if (state.isLocalLanHost) {
      NotificationService.info(
        message: 'LAN servers do not use Kyber moderators.',
      );
      return Future.value();
    }

    _logger.info('Promoting player $id');
    return sl
        .get<KyberGRPCService>()
        .serverManagementClient
        .addModerator(
          AddModeratorRequest(id: id),
        )
        .then((_) => loadModerators());
  }

  Future<void> demotePlayer(String id) {
    if (state.isLocalLanHost) {
      NotificationService.info(
        message: 'LAN servers do not use Kyber moderators.',
      );
      return Future.value();
    }

    _logger.info('Demoting player $id');
    return sl
        .get<KyberGRPCService>()
        .serverManagementClient
        .removeModerator(
          RemoveModeratorRequest(id: id),
        )
        .then((_) => loadModerators());
  }

  Future<void> banPlayer({
    required String id,
    required String reason,
    required Duration duration,
  }) {
    if (state.isLocalLanHost) {
      NotificationService.info(
        message: 'LAN servers do not use Kyber bans.',
      );
      return Future.value();
    }

    _logger.info('Banning player $id');
    return sl.get<KyberGRPCService>().serverManagementClient.banPlayer(
      ServerBanPlayerRequest(
        id: state.id,
        userId: id,
        reason: reason.isEmpty ? 'Banned by moderator' : reason,
        duration: Int64(duration.inSeconds),
      ),
    );
  }

  void swapTeam(ServerPlayer player) {
    _logger.info('Swapping team for player ${player.id}');

    final team = player.teamId == 1 ? 2 : 1;
    sendCommand('/Kyber.SetTeamById ${player.id} $team');
  }

  Future<void> kickPlayer(String id, {String? reason = 'Kicked by moderator'}) {
    if (state.isLocalLanHost) {
      NotificationService.info(
        message: 'Kicking LAN players from the Host tab is not supported yet.',
      );
      return Future.value();
    }

    _logger.info('Kicking player $id');
    return sl.get<KyberGRPCService>().serverManagementClient.kickPlayer(
      ServerKickPlayerRequest(
        id: state.id,
        userId: id,
        reason: reason,
      ),
    );
  }

  void sendCommand(String input) {
    if (!state.isLocalLanHost && state.server == null) {
      return;
    }

    final command = switch (input) {
      final command when command.startsWith('/') => command.substring(1),
      _ => 'Kyber.Broadcast $input',
    };

    _logger.info('Sending command: $command');
    if (state.isLocalLanHost) {
      if (!sl.isRegistered<MaximaGameInstance>()) {
        NotificationService.error(message: 'No local Kyber instance found');
        return;
      }

      unawaited(
        sl
            .get<MaximaGameInstance>()
            .clientService
            .commonClient
            .runCommand(RunCommandRequest(command: command))
            .catchError((Object e, StackTrace s) {
              _logger.severe('Failed to send local LAN command', e, s);
              NotificationService.error(
                message: 'Failed to send LAN command: $e',
              );
              return Empty();
            }),
      );
      return;
    }

    unawaited(
      sl.get<KyberGRPCService>().serverManagementClient.runCommand(
        ServerRunCommandRequest(
          id: state.id,
          command: command,
        ),
      ),
    );
  }

  void unloadServer() {
    _logger.info('Unloading server');

    final channel = _channel;
    if (channel != null) {
      unawaited(channel.sink.close());
    }
    _keepAliveTimer?.cancel();
    _localLanRefreshTimer?.cancel();

    emit(const ModerationServerState());

    if (isClosed) {
      return;
    }
  }

  Future<void> loadServer(Server server) async {
    emit(ModerationServerState(id: server.id, server: server));
  }

  Future<void> selectLocalLanServer(ServerState serverState) async {
    _logger.info('Loading local LAN server');

    await _channel?.sink.close();
    _keepAliveTimer?.cancel();
    _localLanRefreshTimer?.cancel();

    emit(
      ModerationServerState(
        selected: true,
        isLocalLanHost: true,
        players: serverState.playerList,
        commands: const ['Connected to local LAN server management.'],
      ),
    );

    _localLanRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshLocalLanServer(),
    );
  }

  Future<void> _refreshLocalLanServer() async {
    if (!state.isLocalLanHost || !sl.isRegistered<MaximaGameInstance>()) {
      return;
    }

    try {
      final data = await sl
          .get<MaximaGameInstance>()
          .clientService
          .commonClient
          .getInfo(Empty());
      if (!data.hasServer()) {
        unloadServer();
        return;
      }

      emit(state.copyWith(players: data.server.playerList));
    } on GrpcError catch (e, s) {
      _logger.warning('Failed to refresh local LAN server state', e, s);
    }
  }

  Future<void> selectServer({String? serverId}) async {
    if (state.server == null && serverId == null) {
      return;
    }

    await _channel?.sink.close();
    _keepAliveTimer?.cancel();
    _localLanRefreshTimer?.cancel();

    try {
      final id = serverId ?? state.id;
      _logger.info('Loading server $id');
      emit(ModerationServerState(id: id, selected: true));
      final service = sl.get<KyberGRPCService>();
      final server = await service.serverBrowserClient.getServer(
        ServerRequest(id: id),
      );
      emit(state.copyWith(id: id, server: server));

      hostingForm.currentState!.fields['serverName']?.didChange(server.name);

      _logger.info('Subscribing to server events');

      _channel = IOWebSocketChannel.connect(
        'wss://api.${Preferences.admin.apiEnv}.kyber.gg/ws/client/${server.id}',
        headers: {
          'Authorization': service.token,
        },
        connectTimeout: const Duration(seconds: 10),
      );

      await _channel?.ready;

      _channel?.stream.listen(
        (event) {
          try {
            final data = ServerManagementAPIEvent.fromBuffer(
              event as List<int>,
            );
            if (data.hasPlayers()) {
              _logger.fine('Received players event');
              emit(state.copyWith(players: data.players.players));
            } else if (data.hasConsole()) {
              _logger.fine('Received console event');
              final commands = List<String>.from(state.commands)
                ..add(data.console.message);
              emit(state.copyWith(commands: commands));
            }
          } catch (e, s) {
            _logger.severe('Error parsing event', e, s);
          }
        },
        onDone: () {
          _logger.info('Stream done');
          unloadServer();
        },
        onError: (dynamic e, StackTrace s) {
          NotificationService.showNotification(
            title: 'Server error',
            message: 'An error occurred while communicating with the server',
          );
          _logger.severe('Stream error', e, s);
          unloadServer();
        },
      );

      _keepAliveTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) async => _channel?.sink.add(''),
      );

      _logger.info('Fetching moderators');
      await loadModerators();

      _logger.info('Fetching punishments');
      await loadPunishments();

      await Future<void>.delayed(const Duration(seconds: 3));

      if (sl.isRegistered<MaximaGameInstance>() && state.players.isEmpty) {
        final client = sl.get<MaximaGameInstance>().clientService;
        final data = await client.commonClient.getInfo(Empty());
        if (data.hasServer() &&
            state.players.isEmpty &&
            data.server.playerList.isNotEmpty) {
          _logger.info('Received players from game instance');
          emit(state.copyWith(players: data.server.playerList));
        }
      }
    } on WebSocketException catch (e, s) {
      var error = 'Failed to connect to websocket';
      switch (e.httpStatusCode ?? 0) {
        case 401:
          error = 'Failed to connect to websocket: Unauthorized';
        case 404:
          error = 'The specified server was not found';
      }

      _logger.severe('Failed to connect to websocket', e, s);
      NotificationService.error(message: error);
      unloadServer();
    } on GrpcError catch (e, s) {
      _logger.severe('Error loading server:', e, s);
      NotificationService.showNotification(
        title: 'Server error',
        message:
            e.message ??
            'An error occurred while communicating with the server',
        severity: InfoBarSeverity.error,
      );
      unloadServer();
    } on SocketException catch (e, s) {
      _logger.severe('Socket error:', e, s);
      NotificationService.showNotification(
        title: 'Server error',
        message: 'An error occurred while communicating with the server',
        severity: InfoBarSeverity.error,
      );
      unloadServer();
    } catch (e, s) {
      _logger.severe('Error loading server:', e, s);
      NotificationService.showNotification(
        title: 'Server error',
        message: 'An error occurred while communicating with the server',
        severity: InfoBarSeverity.error,
      );
      unloadServer();
    }
  }
}

class ModerationServerState {
  const ModerationServerState({
    this.id,
    this.server,
    this.players = const [],
    this.commands = const [],
    this.moderators = const [],
    this.punishments = const [],
    this.selected = false,
    this.isLocalLanHost = false,
  });

  final String? id;
  final bool selected;
  final Server? server;
  final List<ServerPlayer> players;
  final List<Punishment> punishments;
  final List<String> commands;
  final List<KyberPlayer> moderators;
  final bool isLocalLanHost;

  bool isModerator(String userId) {
    return moderators.any((moderator) => moderator.id == userId);
  }

  ModerationServerState copyWith({
    String? id,
    Server? server,
    List<KyberPlayer>? moderators,
    List<ServerPlayer>? players,
    List<String>? commands,
    List<Punishment>? punishments,
    bool? selected,
    bool? isLocalLanHost,
  }) {
    return ModerationServerState(
      id: id ?? this.id,
      server: server ?? this.server,
      players: players ?? this.players,
      commands: commands ?? this.commands,
      punishments: punishments ?? this.punishments,
      selected: selected ?? this.selected,
      moderators: moderators ?? this.moderators,
      isLocalLanHost: isLocalLanHost ?? this.isLocalLanHost,
    );
  }
}
