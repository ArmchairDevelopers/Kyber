import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class IngameViewCubit extends Cubit<IngameViewState> {
  IngameViewCubit() : super(const IngameViewState());

  final _logger = Logger('ingame_view_cubit');
  Timer? _keepAliveTimer;

  WebSocketChannel? _channel;

  int _loadId = 0;

  @override
  Future<void> close() {
    unloadServer();
    return super.close();
  }

  void unloadServer() {
    _logger.info('Unloading server');

    _loadId++;
    _channel?.sink.close();
    _channel = null;
    _keepAliveTimer?.cancel();

    emit(const IngameViewState());

    if (isClosed) {
      return;
    }
  }

  Future<void> loadServer(Server server) async {
    emit(IngameViewState(id: server.id, server: server));
    await selectServer(serverId: server.id);
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
      emit(IngameViewState(id: id));
      final service = sl.get<KyberGRPCService>();
      final server = await service.serverBrowserClient.getServer(
        ServerRequest(id: id),
      );
      if (loadId != _loadId || isClosed) {
        return;
      }
      emit(state.copyWith(id: id, server: server));

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

      await Future<void>.delayed(const Duration(seconds: 3));
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

class IngameViewState {
  const IngameViewState({
    this.id,
    this.server,
    this.players = const [],
    this.commands = const [],
  });

  final String? id;
  final Server? server;
  final List<ServerPlayer> players;
  final List<String> commands;

  IngameViewState copyWith({
    String? id,
    Server? server,
    List<ServerPlayer>? players,
    List<String>? commands,
  }) {
    return IngameViewState(
      id: id ?? this.id,
      server: server ?? this.server,
      players: players ?? this.players,
      commands: commands ?? this.commands,
    );
  }
}
