import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/services/rich_presence.dart';
import 'package:kyber_launcher/core/services/voip_service.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';

class KyberStatusCubit extends Cubit<KyberStatusState> {
  bool joined = false;

  KyberStatusCubit() : super(KyberStatusInitial()) {
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) async => onTick(),
    );

    _rpcServerTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (!sl.isRegistered<MaximaGameInstance>()) {
        return;
      }

      final info = await sl
          .get<MaximaGameInstance>()
          .clientService
          .commonClient
          .getInfo(Empty());
      if (!info.hasServer() && !info.client.hasServerId()) {
        sl.get<RichPresence>().clearPresence();
        return;
      }

      final id = info.hasServer() ? info.server.id : info.client.serverId;
      final client = sl.get<KyberGRPCService>();
      final server = await client.serverBrowserClient.getServer(
        ServerRequest(id: id),
      );

      // Refresh server metadata for the current state without transitioning
      // out of it. `info` is a CommonState proto from getInfo(); it must not
      // be confused with the cubit's `state`. Never emit KyberStatusNormal()
      // from here — a transient/anomalous getInfo() result shouldn't tear
      // down the hosted-server connection and reset all configured values.
      if (state is KyberStatusHosting) {
        emit(
          KyberStatusHosting(
            serverState: (state as KyberStatusHosting).serverState,
            server: server,
          ),
        );
      } else if (state is KyberStatusPlaying) {
        emit(
          KyberStatusPlaying(
            serverState: (state as KyberStatusPlaying).serverState,
            server: server,
            joined: joined,
          ),
        );
      }

      sl.get<RichPresence>().updatePresenceKyber(info, server);
    });
  }

  Future<void> onTick() async {
    final isRegistered = sl.isRegistered<MaximaGameInstance>();
    if (!isRegistered) {
      final rp = sl.get<RichPresence>();
      if (state is! KyberStatusInitial || rp.started != null) {
        sl.get<RichPresence>().clearPresence();
      }

      joined = false;

      return emit(KyberStatusInitial());
    }

    try {
      final client = sl.get<MaximaGameInstance>();
      final data = await client.clientService.commonClient.getInfo(Empty());
      if (data.vivoxInitialized && client.voipSettings == null) {
        sl.get<VoipService>().setGameVoipSettings();
      }

      final isKyber = data.hasClient() || data.hasServer();
      var server = (state is KyberStatusPlaying || state is KyberStatusHosting)
          ? ((state as dynamic).server as Server?)
          : null;
      if (isKyber &&
          (state is KyberStatusInitial ||
              ((state is KyberStatusPlaying || state is KyberStatusHosting) &&
                  (state as dynamic).server == null))) {
        final id = data.hasServer() ? data.server.id : data.client.serverId;
        final client = sl.get<KyberGRPCService>();
        server = await client.serverBrowserClient.getServer(
          ServerRequest(id: id),
        );
        sl.get<RichPresence>().updatePresenceKyber(data, server);
      }

      if (data.hasClient()) {
        emit(
          KyberStatusPlaying(
            serverState: data.server,
            server: server,
            joined: joined,
          ),
        );
      } else if (data.hasServer()) {
        emit(KyberStatusHosting(serverState: data.server, server: server));
      } else {
        // getInfo() reported no client and no server, but the game instance
        // is still registered (we passed the isRegistered guard above).
        // If we're already hosting or playing, stay in the current state
        // rather than transitioning to Normal — a single anomalous
        // getInfo() response shouldn't tear down the hosted-server
        // connection and reset all configuration.
        if (state is KyberStatusHosting || state is KyberStatusPlaying) {
          return;
        }
        emit(KyberStatusNormal());
      }
    } catch (e) {
      if (e is GrpcError) {
        if (e.code == StatusCode.unavailable) {
          _logger.severe('Kyber gRPC server is unavailable...');
          return;
        }
      }

      print(e);
      rethrow;
    }
  }

  final _logger = Logger('status_cubit');

  @override
  Future<void> close() {
    _statusTimer.cancel();
    _rpcServerTimer.cancel();
    return super.close();
  }

  late Timer _statusTimer;
  late Timer _rpcServerTimer;
}

class KyberStatusState {}

class KyberStatusInitial extends KyberStatusState {}

class KyberStatusNormal extends KyberStatusState {}

class KyberStatusPlaying extends KyberStatusState {
  KyberStatusPlaying({
    required this.serverState,
    this.server,
    this.joined = false,
  });

  final ServerState serverState;
  final Server? server;
  final bool joined;
}

class KyberStatusHosting extends KyberStatusState {
  KyberStatusHosting({required this.serverState, this.server});

  final ServerState serverState;
  final Server? server;
}
