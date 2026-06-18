import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/windows_env.dart';
import 'package:kyber_launcher/features/frosty/dialogs/frosty_pack_selector_dialog.dart';
import 'package:kyber_launcher/features/game/dialogs/mod_limit_dialog.dart';
import 'package:kyber_launcher/features/kyber/services/kyber_grpc_service.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_start_game_dialog.dart';
import 'package:kyber_launcher/features/maxima/extensions/server_mod.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/maxima/services/maxima_instance_service.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart' as maxima;
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class MaximaHelper {
  static final Logger _logger = Logger('maxima_helper');

  static Future<void> requestGameLaunch(
    BuildContext context, {
    ModCollectionMetaData? modCollection,
    bool showCollectionSelector = true,
    InitializeRequest? initializeRequest,
  }) async {
    if (modCollection == null && showCollectionSelector) {
      modCollection = await showKyberDialog<ModCollectionMetaData?>(
        context: context,
        builder: (_) => const FrostyPackSelectorDialog(),
      );

      if (modCollection == null) {
        _logger.fine('User cancelled selection. Aborting requestGameLaunch');
        return;
      }
    }

    initializeRequest ??= InitializeRequest();
    if (modCollection != null) {
      if (modCollection.getLocalMods().contains(null)) {
        NotificationService.error(
          message:
              'Some mods in your collection are missing. Please check your mod collection.',
        );
        return;
      }

      final modPaths = modCollection.getModPaths();
      final preloadedMods = await sl
          .get<KyberGRPCService>()
          .launcherClient
          .getPreloadedMods(Empty());
      final modLimit = Preferences.general.enabledPreloadMods
          ? 1739 - preloadedMods.mods.length
          : 1739;
      if (modPaths.length >= modLimit) {
        _logger.warning('Mod limit reached: ${modPaths.length}');

        if (context.mounted) {
          await showKyberDialog(
            context: context,
            builder: (_) => const ModLimitDialog(),
          );
        }

        return;
      }

      initializeRequest.modData = ModData(
        basePath: ModService.getBasePath(),
        modPaths: modPaths,
        mods: modCollection
            .getLocalMods(onlyGameplay: true)
            .whereType<FrostyMod>()
            .map(ServerMod().fromFrostyMod)
            .toList(),
        explodedMods: modCollection
            .getLocalMods(
              onlyGameplay: true,
              expandCollections: true,
            )
            .whereType<FrostyMod>()
            .where((e) => !e.isCollection)
            .map(ServerMod().fromFrostyMod)
            .toList(),
      );
    }

    if (!context.mounted) {
      _logger.warning('Context is not mounted, aborting requestGameLaunch');
      return;
    }

    // final gameConfig = await ConfigParser.parseConfig();
    // if (gameConfig.enableDx12) {
    //   _logger.warning('Launching game with DirectX 12 enabled');
    //   NotificationService.warning(
    //     message:
    //     'DirectX 12 is enabled. This can cause instability and issues with Kyber.',
    //   );
    // }

    if (initializeRequest.startupCommands.isNotEmpty) {
      _logger.fine(
        'Starting game with startup commands: ${initializeRequest.startupCommands}',
      );
    }

    if (!context.mounted) {
      _logger.warning('Context is not mounted, aborting requestGameLaunch');
      return;
    }

    await showKyberDialog(
      context: context,
      builder: (_) => MaximaStartGameDialog(
        initializeRequest: initializeRequest,
        mods: modCollection?.getLocalMods().whereType<FrostyMod>().toList(),
      ),
    );
  }

  static Future<MaximaGameInstance> startGame({
    InitializeRequest? initializeRequest,
    String? gameSlug,
    String? gamePath,
    String? gameDataPath,
    List<FrostyMod>? mods,
  }) async {
    final path = Platform.environment['PATH'];

    if (path == null) {
      throw Exception('PATH environment variable is not set');
    }

    final grpcDebug = Preferences.debug.grpcDebugLogs;
    final moduleDebug = Preferences.debug.moduleDebugLogs;
    final newPath = '$path;${FileHelper.getModuleDirectory().path}';
    final interfacePort = await KyberNetworkHelper.findAvailablePort();
    final kToken = await sl.get<KyberGRPCService>().getAuthToken(
      await maxima.getAuthToken(),
    );
    ProcessEnv.set('KYBER_API_TOKEN', kToken);
    ProcessEnv.set(
      'KYBER_MODULE_VERSION',
      (await VersionModule.module.getCurrentVersion())!,
    );
    ProcessEnv.set('KYBER_INTERFACE_PORT', interfacePort.toString());
    ProcessEnv.set(
      'KYBER_HTTP_HOSTNAME',
      sl.get<KyberGRPCService>().httpHostname,
    );
    ProcessEnv.set('PATH', newPath);
    ProcessEnv.set('KYBER_API_HOSTNAME', sl.get<KyberGRPCService>().host);

    if (grpcDebug) {
      ProcessEnv.set('GRPC_TRACE', 'all');
      ProcessEnv.set('GRPC_VERBOSITY', 'debug');
    } else {
      ProcessEnv.delete('GRPC_TRACE');
      ProcessEnv.delete('GRPC_VERBOSITY');
    }

    if (moduleDebug) {
      ProcessEnv.set('KYBER_LOG_LEVEL', 'debug');
    } else {
      ProcessEnv.delete('KYBER_LOG_LEVEL');
    }

    final gameClient = ClientGRPCService('127.0.0.1', interfacePort);
    final gamePID = await maxima.startGame(
      gameSlug: gameSlug ?? 'star-wars-battlefront-2',
      gamePathOverride: gamePath,
    );
    _logger.info('Started game with PID: $gamePID');

    if (sl.isRegistered<MaximaGameInstance>()) {
      _logger.warning(
        'ClientGRPCService was already registered, unregistering...',
      );

      try {
        Process.killPid(sl.get<MaximaGameInstance>().pid);
      } catch (_) {}

      sl.unregister<MaximaGameInstance>();
    }

    final instance = MaximaGameInstance(
      pid: gamePID,
      clientService: gameClient,
      isDedicated: false,
      mods: mods ?? [],
    );

    try {
      sl.get<KyberGRPCServer>().setInitializeRequest(
        initializeRequest ?? InitializeRequest(),
      );
      await maxima
          .lsxGetEventStream(pid: gamePID, isStartup: true)
          .firstWhere((e) => e == 'RequestLicense');
      await maxima.injectKyber(
        pid: gamePID,
        path: p.join(FileHelper.getModuleDirectory().path, 'Kyber.dll'),
      );
    } catch (e) {
      if (e is AnyhowException) {
        _logger.severe('Failed to inject Kyber into game: ${e.message}');
      }
      rethrow;
    }

    sl.registerSingleton<MaximaGameInstance>(instance);
    sl.get<MaximaInstanceService>().addInstance(instance);

    return instance;
  }
}
