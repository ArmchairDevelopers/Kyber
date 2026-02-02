import 'dart:io';
import 'dart:isolate';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/strings.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/models/download_link_type.dart' as dl;
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/features/maxima/helper/maxima_helper.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:window_manager/window_manager.dart';

class ProtocolHelper {
  static const List<String> _supportedUrls = [
    'join_server',
    'start_game',
    'deep_link',
    'discord_linked',
  ];

  static Future<void> register() async {
    await protocolHandler.register(Strings.protocolName);
    await protocolHandler.register('nxm');
  }

  static Future<void> initialize() async {
    if (!Platform.isWindows) {
      return;
    }

    final initialUrl = await protocolHandler.getInitialUrl();
    if (Preferences.general.setup && initialUrl != null) {
      await ProtocolHelper.handleCall(initialUrl);
    }
  }

  static Future<void> handleCall(String url) async {
    try {
      if (!Preferences.general.setup) {
        Logger.root.severe('Received protocol url but setup is not complete');
        return;
      }

      if (await windowManager.isMinimized()) {
        await windowManager.restore();
      }

      final file = File(url);
      if (file.existsSync()) {
        const allowedExtensions = ['.kbcollection', '.kbrotation', '.kbplugin'];
        final fileExtension = extension(file.path);
        if (!allowedExtensions.contains(fileExtension)) {
          Logger.root.severe(
            'error: unsupported file extension: $fileExtension',
          );
          return;
        }

        if (fileExtension == '.kbrotation' || fileExtension == '.kbplugin') {
          Logger.root.info('Not implemented. (fileExtension: $fileExtension)');
          return;
        }

        final collection = await ModCollection.readCollection(file);

        Logger.root.info(
          'Received mod collection ${collection.localId} from protocol url',
        );

        NotificationService.showNotification(
          message:
              'Importing Collections without mod data is currently not supported',
        );

        await router.pushNamed(
          'collection_import',
          queryParameters: {'path': file.path},
        );

        return;
      }

      final uri = Uri.parse(url);
      if (uri.scheme == 'nxm') {
        Logger.root.info('Received nxm protocol url: $url');

        final gameId = uri.host;
        if (gameId != 'starwarsbattlefront22017') {
          Logger.root.severe(
            'error: unsupported game id: $gameId... trying to redirect to vortex',
          );

          if (!Platform.isWindows) {
            return NotificationService.error(
              message: 'Vortex is only supported on Windows',
            );
          }

          final vortexExe = File(
            r'C:\Program Files\Black Tree Gaming Ltd\Vortex\Vortex.exe',
          );
          if (!vortexExe.existsSync()) {
            return NotificationService.error(
              message: 'Vortex is not installed or the path is incorrect',
            );
          }

          await Process.start(vortexExe.path, [
            '-i',
            url,
          ], mode: ProcessStartMode.detached);
          return;
        }

        final modId = uri.pathSegments[1];
        final fileId = uri.pathSegments.last;
        final service = sl.get<NexusModsService>();
        if (service.apiToken == null) {
          NotificationService.showNotification(
            message: 'You need to login to download mods',
            severity: InfoBarSeverity.error,
          );
          Logger.root.severe('error: api token is null');
          return;
        }

        try {
          final mod = await service.nexusBridge.apiClient.getMod(
            gameId,
            int.parse(modId),
          );

          final request = DownloadRequest(
            link: url,
            displayName: mod.name,
            linkType: dl.DownloadLinkType.nxm,
          );
          Logger.root.info('Adding download to queue: ${mod.name}');
          await sl.get<DownloadOrchestrator>().enqueueDownload(request);
        } catch (exception, stackTrace) {
          Logger.root.severe(
            'error: failed to get download link',
            exception,
            stackTrace,
          );
          return;
        }

        return;
      }

      if (uri.queryParameters.containsKey('type')) {
        if (uri.queryParameters['type'] == 'deep_link') {
          await router.push(
            '/${uri.host}${uri.path}?${uri.queryParameters.entries.map((e) => '${e.key}=${e.value}').join('&')}',
            extra: uri.queryParameters,
          );
          return;
        }
      }

      if (!_supportedUrls.contains(uri.host)) {
        Logger.root.severe('error: unsupported protocol: $uri');
        return;
      }

      switch (uri.host) {
        case 'discord_linked':
          await navigatorKey.currentContext?.read<MaximaCubit>().verifyToken();
          return;
        case 'join_server':
          if (uri.queryParameters.isEmpty ||
              uri.queryParameters['server_id'] == null) {
            Logger.root.severe('Received protocol url but server_id is null');
            return;
          }

          var forceJoin = false;
          if (uri.queryParameters['force_join'] != null) {
            forceJoin = uri.queryParameters['force_join'] == '1';
          }

          await _joinServer(
            uri.queryParameters['server_id']!,
            forceJoin: forceJoin,
          );
        case 'start_game':
          if (!navigatorKey.currentContext!
              .read<MaximaCubit>()
              .state
              .loggedIn) {
            NotificationService.showNotification(
              message: 'You need to login to start a game',
              severity: InfoBarSeverity.error,
            );

            Logger.root.severe('Received protocol url but token is null');
            return;
          }

          final query = uri.queryParameters;
          ModCollectionMetaData? collection;
          if (query.containsKey('collection')) {
            collection = collectionBox.values
                .where((e) => e.title == query['collection'])
                .firstOrNull;
            if (collection == null) {
              NotificationService.showNotification(
                message: 'Collection "${query['collection']}" not found',
                severity: InfoBarSeverity.error,
              );
            }
          }

          await sl.isReady<ModService>();
          await MaximaHelper.requestGameLaunch(
            navigatorKey.currentContext!,
            modCollection: collection,
            showCollectionSelector: false,
          );
      }

      Logger.root.info('Received protocol url: $url');
    } catch (e, s) {
      Logger.root.severe('error: failed to handle protocol url', e, s);
    }
  }

  static Future<void> _joinServer(
    String serverId, {
    bool forceJoin = false,
  }) async {
    if (serverId.isEmpty) {
      Logger.root.severe('Received protocol url but server_id is null');
      return;
    }

    router.goNamed('home');
    final server = await sl
        .get<KyberGRPCService>()
        .serverBrowserClient
        .getServer(ServerRequest(id: serverId));
    if (!server.hasName()) {
      Logger.root.severe('error: server not found');
      return;
    }

    final context = shellNavigatorKey.currentContext;
    if (context == null) {
      Logger.root.severe('error: shellNavigator context is null');
      return;
    }

    if (context.mounted) {
      context.read<ServerBrowserCubit>().selectServer(server);

      if (forceJoin) {
        context.read<ServerBrowserCubit>().joinServer();
        return;
      }

      final mods = server.mods;
      if (mods.every((m) => ModHelper.isInstalled(m.name, m.version))) {
        context.read<ServerBrowserCubit>().joinServer();
      } else {
        context.read<ServerBrowserCubit>().selectServer(server);
      }
    }
  }
}
