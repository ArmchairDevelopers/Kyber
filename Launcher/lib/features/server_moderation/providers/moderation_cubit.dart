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

  ReplaySubject<(int, int)>? botChangeStream;

  WebSocketChannel? _channel;

  int _loadId = 0;

  @override
  Future<void> close() {
    unloadServer();
    return super.close();
  }

  Future<void> loadModerators() async {
    final moderators = await sl
        .get<KyberGRPCService>()
        .serverManagementClient
        .getModerators(ModeratorsRequest(serverId: state.id));
    emit(state.copyWith(moderators: moderators.users.toList()));
  }

  Future<void> loadPunishments() async {
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
    _logger.info('Unbanning player $id');
    await sl.get<KyberGRPCService>().serverManagementClient.unbanPlayer(
      UnbanPlayerRequest(userId: id, serverId: state.id),
    );

    await loadPunishments();
  }

  Future<void> promotePlayer(String id) {
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
    if (state.server == null) {
      return;
    }

    final command = switch (input) {
      final command when command.startsWith('/') => command.substring(1),
      _ => 'Kyber.Broadcast $input',
    };

    _logger.info('Sending command: $command');
    sl.get<KyberGRPCService>().serverManagementClient.runCommand(
      ServerRunCommandRequest(
        id: state.id,
        command: command,
      ),
    );
  }

  void unloadServer() {
    _logger.info('Unloading server');

    _loadId++;
    _channel?.sink.close();
    _channel = null;
    _keepAliveTimer?.cancel();

    emit(const ModerationServerState());

    if (isClosed) {
      return;
    }
  }

  Future<void> loadServer(Server server) async {
    emit(ModerationServerState(id: server.id, server: server));
  }

  Future<void> selectServer({String? serverId}) async {
    if (state.server == null && serverId == null) {
      return;
    }

    final loadId = ++_loadId;
    unawaited(_channel?.sink.close());
    _channel = null;
    _keepAliveTimer?.cancel();

    try {
      final id = serverId ?? state.id;
      _logger.info('Loading server $id');
      emit(ModerationServerState(id: id, selected: true));
      final service = sl.get<KyberGRPCService>();
      final server = await service.serverBrowserClient.getServer(
        ServerRequest(id: id),
      );
      if (loadId != _loadId || isClosed) {
        return;
      }
      emit(state.copyWith(id: id, server: server));

      hostingForm.currentState?.fields['serverName']?.didChange(server.name);

      _logger.info('Subscribing to server events');

      final channel = IOWebSocketChannel.connect(
        'wss://api.${Preferences.admin.apiEnv}.kyber.gg/ws/client/${server.id}',
        headers: {
          'Authorization': service.token,
        },
        connectTimeout: const Duration(seconds: 10),
      );

      _channel = channel;

      await channel.ready;
      if (loadId != _loadId || isClosed) {
        unawaited(channel.sink.close());
        return;
      }

      channel.stream.listen(
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
          if (loadId == _loadId) {
            unloadServer();
          }
        },
        onError: (dynamic e, StackTrace s) {
          NotificationService.showNotification(
            title: 'Server error',
            message: 'An error occurred while communicating with the server',
          );
          _logger.severe('Stream error', e, s);
          if (loadId == _loadId) {
            unloadServer();
          }
        },
      );

      _keepAliveTimer = Timer.periodic(
        const Duration(seconds: 10),
        (timer) {
          if (loadId != _loadId || channel.closeCode != null) {
            timer.cancel();
            return;
          }
          channel.sink.add('');
        },
      );

      _logger.info('Fetching moderators');
      await loadModerators();

      _logger.info('Fetching punishments');
      await loadPunishments();

      await Future<void>.delayed(const Duration(seconds: 3));
      if (loadId != _loadId) {
        return;
      }

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
      if (loadId != _loadId) {
        return;
      }
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
      if (loadId != _loadId) {
        return;
      }
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
      if (loadId != _loadId) {
        return;
      }
      _logger.severe('Socket error:', e, s);
      NotificationService.showNotification(
        title: 'Server error',
        message: 'An error occurred while communicating with the server',
        severity: InfoBarSeverity.error,
      );
      unloadServer();
    } catch (e, s) {
      if (loadId != _loadId) {
        return;
      }
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
  });

  final String? id;
  final bool selected;
  final Server? server;
  final List<ServerPlayer> players;
  final List<Punishment> punishments;
  final List<String> commands;
  final List<KyberPlayer> moderators;

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
  }) {
    return ModerationServerState(
      id: id ?? this.id,
      server: server ?? this.server,
      players: players ?? this.players,
      commands: commands ?? this.commands,
      punishments: punishments ?? this.punishments,
      selected: selected ?? this.selected,
      moderators: moderators ?? this.moderators,
    );
  }
}
