import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber/gen/Proto/kyber_interface.pbgrpc.dart'
    hide CustomLevelDataRequest, CustomLevelDataResponse, InitializeRequest;
import 'package:kyber/kyber.dart' hide Server;
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mods/services/level_declaration_service.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';

class LauncherService extends LauncherCommonServiceBase {
  @override
  Future<InitializeRequest> initialize(ServiceCall _, Empty __) {
    return Future.value(sl.get<KyberGRPCServer>().getInitializeRequest());
  }

  @override
  Future<CustomLevelDataResponse> getCustomLevelData(
    ServiceCall call,
    CustomLevelDataRequest req,
  ) {
    if (!sl.isRegistered<MaximaGameInstance>()) {
      throw Exception(
        'MaximaGameInstance is not registered in the service locator',
      );
    }

    final instance = sl.get<MaximaGameInstance>();
    final levelService = sl.get<LevelDeclarationService>();
    final collection = ModCollectionMetaData(
      localId: '',
      title: '',
      mods: instance.mods.map((e) => e.toCollectionMod()).toList(),
    );
    final map = levelService.getMapByMode(
      map: req.map,
      mode: req.mode,
      collection: collection,
    );
    final mode = levelService.getModeName(
      mode: req.mode,
      collection: collection,
    );

    return Future.value(
      CustomLevelDataResponse(mapName: map?.name, modeName: mode),
    );
  }

  @override
  Future<Empty> onServerJoined(ServiceCall call, Empty request) async {
    navigatorKey.currentContext!.read<KyberStatusCubit>()
      ..joined = true
      ..onTick();

    final context = navigatorKey.currentContext!;
    final sessionCubit = context.read<SessionCubit>();
    final kyberCubit = context.read<KyberStatusCubit>().state;
    String? serverId;

    if (kyberCubit is KyberStatusPlaying) {
      serverId = kyberCubit.server?.id;
    } else if (kyberCubit is KyberStatusHosting) {
      serverId = kyberCubit.server?.id;
    }

    if (serverId != null) {
      await sessionCubit.onJoined(serverId: serverId);
    } else {
      Logger.root.warning(
        'Server joined notification received but server ID is null',
      );
    }

    Logger.root.info('Server joined notification received');
    return Future.value(Empty());
  }

  @override
  Future<Empty> onServerLeft(ServiceCall call, Empty request) {
    navigatorKey.currentContext!.read<KyberStatusCubit>()
      ..joined = false
      ..onTick();

    final context = navigatorKey.currentContext!;
    final stateCubit = context.read<SessionCubit>();
    if (stateCubit.gameJoined) {
      stateCubit.leaveGame();
    }

    Logger.root.info('Server left notification received');
    return Future.value(Empty());
  }
}

class KyberGRPCServer {
  final _logger = Logger('grpc_server');

  Server? _server;
  InitializeRequest? _initializeRequest;

  InitializeRequest getInitializeRequest() {
    final request = _initializeRequest;
    if (request == null) {
      throw Exception('Initialize request is not set');
    }

    return _initializeRequest!;
  }

  void setInitializeRequest(InitializeRequest request) {
    _initializeRequest = request;
  }

  Future<void> start() async {
    _logger.info('Starting gRPC server');
    _server = Server.create(
      services: [
        LauncherService(),
      ],
      errorHandler: (error, trace) {
        _logger.severe('An error occurred: $error', error, trace);
      },
    );

    final port = await KyberNetworkHelper.findAvailablePort();
    await _server?.serve(port: port);
    ProcessEnv.set('KYBER_LAUNCHER_PORT', port.toString());

    _logger.info('Server listening on port $port');
  }

  void dispose() {
    _server?.shutdown();
  }
}
