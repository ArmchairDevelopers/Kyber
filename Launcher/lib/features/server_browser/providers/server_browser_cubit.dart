import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/gen/Proto/mod_bridge.pb.dart' as mb;
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/models/download_link_type.dart'
    as dl;
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/download_manager/repositories/download_repository.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/features/download_manager/services/mod_bridge_service.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_server_helper.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/nexusmods/dialogs/nexusmods_login.dart';
import 'package:kyber_launcher/features/nexusmods/exceptions/missing_nexus_auth_exception.dart';
import 'package:kyber_launcher/features/nexusmods/services/mod_finder_service.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/join_server_dialog.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_list_cubit.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';

part 'server_browser_state.dart';

class ServerBrowserCubit extends Cubit<ServerBrowserState> {
  ServerBrowserCubit() : super(const .new());

  Timer? _downloadChecker;
  bool _running = false;

  @override
  Future<void> close() {
    _downloadChecker?.cancel();
    return super.close();
  }

  void selectServer(ServerEntry? server) {
    emit(state.copyWith(selectedServer: server));
  }

  void clearServer() {
    emit(.new(joiningServer: state.joiningServer));
  }

  Future<void> joinServer({bool enabledDownload = true}) async {
    final context = navigatorKey.currentContext;
    if (context != null) {
      final sessionState = context.read<SessionCubit>().state;
      if (sessionState is InParty) {
        final userId = context.read<MaximaCubit>().state.servicePlayer?.id;
        if (userId == null) {
          return;
        }

        if (sessionState.party.leaderId != userId) {
          NotificationService.showNotification(
            message: 'Only the party leader can join a server!',
            severity: InfoBarSeverity.warning,
          );
          return;
        }

        await _startPartyJoinGame();
        return;
      }
    }

    if (hasAllRequiredMods()) {
      _joinServer();
    } else if (enabledDownload) {
      emit(
        state.copyWith(
          joiningServer: state.selectedServer!.serverInfo,
        ),
      );
      _startDownloads();
    }
  }

  Future<void> _startPartyJoinGame() async {
    final server = state.selectedServer;
    if (server == null) return;

    final serverInfo = server.serverInfo;

    try {
      // TODO: handle password protected servers
      await navigatorKey.currentContext!.read<SessionCubit>().startJoinGame(
        serverId: serverInfo.id,
        password: '',
      );
    } catch (e) {
      Logger('server_browser').severe('Error starting party join game', e);
      NotificationService.error(
        message: 'Failed to start party join: $e',
      );
    }
  }

  bool hasAllRequiredMods() {
    final server = state.joiningServer ?? state.selectedServer?.serverInfo;
    if (server == null) return false;

    return server.mods.every(
      (mod) => ModHelper.isInstalled(mod.name, mod.version),
    );
  }

  Future<void> _joinServer() async {
    try {
      final dialogCompleted = Completer<JoinDialogResult?>();
      final server = state.selectedServer!;
      final initialServerData = state.selectedServer!.serverInfo;

      showKyberDialog<JoinDialogResult?>(
        context: navigatorKey.currentContext!,
        builder: (context) => CosmeticModsDialog(
          server: server,
        ),
      ).then(dialogCompleted.complete);

      await sl
          .get<KyberGRPCService>()
          .serverBrowserClient
          .getServer(ServerRequest(id: initialServerData.id))
          .then((_) => null)
          .onError((e, s) {
            if (dialogCompleted.isCompleted) {
              return;
            }

            if (e is GrpcError && e.code == StatusCode.notFound) {
              BlocProvider.of<ServerListCubit>(
                navigatorKey.currentContext!,
              ).loadServers();
              Navigator.pop(navigatorKey.currentContext!);
              NotificationService.showNotification(
                message: 'Server not found!',
                severity: InfoBarSeverity.error,
              );
            } else {
              Navigator.pop(navigatorKey.currentContext!);
              NotificationService.showNotification(
                title: 'Error joining server!',
                message: e.toString(),
                severity: InfoBarSeverity.error,
              );
            }
          });

      await dialogCompleted.future;
      final result = await dialogCompleted.future;

      if (result == null) {
        emit(.new(selectedServer: server));
        return;
      }

      final selectedServer = switch (server) {
        SingleServer(:final server) => server,
        GroupedServer(:final group) => group.servers.firstWhere(
          (e) => e.meta['instance_id'] == result.instanceId,
        ),
      };
      await KyberServerHelper.joinServer(
        selectedServer,
        selectedCollection: result.collection,
        spectator: result.spectator,
        password: result.password,
        queueIfFull: true,
      );

      emit(ServerBrowserState(selectedServer: server));
    } catch (e, s) {
      Logger('server_browser').severe('Error joining server!', e, s);
      emit(const ServerBrowserState());
      if (e is GrpcError) {
        if (e.code == StatusCode.notFound) {
          return NotificationService.showNotification(
            message: 'Server not found!',
            severity: InfoBarSeverity.error,
          );
        }
      }

      NotificationService.showNotification(
        title: 'Error joining server!',
        message: e.toString(),
        severity: InfoBarSeverity.error,
      );
    }
  }

  Future<bool> _nexusLogin() async {
    if (!Preferences.nexusMods.isLoggedIn) {
      final result = await showKyberDialog<bool?>(
        context: navigatorKey.currentContext!,
        routeSettings: const RouteSettings(name: 'nexusmods_login'),
        builder: (_) => const NexusmodsLogin(),
      );

      if (result == null || !result) {
        NotificationService.showNotification(
          message: 'You need to login to NexusMods to download mods!',
        );
        return false;
      }
    }

    return true;
  }

  Future<void> _handleDownload(
    mb.Mod mod, {
    required ServerMod serverMod,
  }) async {
    try {
      final downloadUrl = mod.link.contains('https://www.nexusmods')
          ? '${mod.link}&file_id=${mod.fileId}'
          : mod.link;
      final filename = mod.link.split('/').last.split('?').first;

      if (downloadUrl.startsWith('https://www.nexusmods')) {
        final result = await _nexusLogin();
        if (!result) {
          throw MissingNexusAuthException();
        }
      }

      const repository = DownloadRepository();
      final tasks = await repository.getActiveTasks();
      final existingTask = tasks.firstWhereOrNull(
        (e) => e.task.displayName == mod.name,
      );
      if (existingTask != null) {
        if (existingTask.status == TaskStatus.paused) {
          await sl.get<DownloadOrchestrator>().resumeDownload(
            existingTask.taskId,
          );
        }
        return;
      }

      final request = DownloadRequest(
        link: downloadUrl,
        displayName: mod.name,
        linkType: downloadUrl.startsWith('https://www.nexusmods')
            ? dl.DownloadLinkType.nexus
            : dl.DownloadLinkType.direct,
        size: mod.fileSize.toInt(),
        filename: filename,
        priority: 1,
        metadata: {
          'name': serverMod.name,
          'version': serverMod.version,
          'link': serverMod.link,
          'fileSize': serverMod.fileSize.toInt(),
        },
      );

      await sl.get<DownloadOrchestrator>().enqueueDownload(request);
    } on MissingNexusAuthException {
      rethrow;
    } catch (e, s) {
      Logger(
        'server_browser',
      ).severe('Error finding download for ${mod.name}', e, s);
      NotificationService.showNotification(
        message: 'Error finding download for ${mod.name}',
      );
    }
  }

  Future<void> _startDownloads() async {
    final server = state.selectedServer;
    if (server == null) {
      return;
    }

    var failedMods = 0;

    const repository = DownloadRepository();
    final currentDownload = await repository.getRunningTask();
    if (currentDownload != null) {
      await sl.get<DownloadOrchestrator>().pauseDownload(
        currentDownload.taskId,
      );
      final name = currentDownload.task.displayName;
      NotificationService.info(message: 'Paused download for $name');
    }

    final serverInfo = server.serverInfo;

    final missingMods = serverInfo.mods
        .where((mod) => !ModHelper.isInstalled(mod.name, mod.version))
        .map(
          (m) => mb.BridgeMod(
            name: m.name,
            version: m.version,
            id: serverInfo.mods.indexOf(m).toString(),
          ),
        );

    final chunks = missingMods.slices(50);
    final modsToDownload = <mb.Mod>[];
    final notFound = <mb.BridgeMod>[];
    for (final chunk in chunks) {
      final resp = await sl
          .get<ModBridgeGRPCService>()
          .searchClient
          .searchMods(
            mb.SearchModsRequest(mods: chunk),
          )
          .catchError((e) {
            Logger('server_browser').severe('Error searching mods', e);
            NotificationService.showNotification(
              message: 'Error searching mods: $e',
            );

            return mb.SearchModsResponse();
          });

      if (resp.mods.isEmpty && resp.notFound.isEmpty) {
        continue;
      }

      modsToDownload.addAll(resp.mods);
      notFound.addAll(resp.notFound);
    }

    final finderService = ModFinderService();
    for (final mod in notFound) {
      final serverMod = serverInfo.mods.firstWhere(
        (e) => e.name == mod.name && e.version == mod.version,
      );

      if (serverMod.link.isEmpty) {
        failedMods++;
        continue;
      }

      final resp = await finderService.searchMod(serverMod.link, mod.version);
      if (resp.$2.isEmpty) {
        failedMods++;
        continue;
      }

      final modId = resp.$1;
      final file = resp.$2.first;
      final link =
          'https://www.nexusmods.com/starwarsbattlefront22017/mods/$modId?tab=files&file_id=${file.fileId}';
      final fMod = mb.Mod(
        name: file.name,
        link: link,
        modId: .parse(modId),
        fileId: .parse(file.fileId),
        id: serverInfo.mods.indexOf(serverMod).toString(),
      );

      modsToDownload.add(fMod);
    }

    var nexusLoginPrompted = false;
    for (final mod in modsToDownload) {
      final serverMod = serverInfo.mods[int.parse(mod.id)];

      if (mod.link.contains('nexusmods') && nexusLoginPrompted) {
        continue;
      }

      try {
        await _handleDownload(mod, serverMod: serverMod);
      } on MissingNexusAuthException {
        nexusLoginPrompted = true;
        continue;
      }
    }

    if (failedMods > 0) {
      NotificationService.showNotification(
        message:
            "For $failedMods ${failedMods > 1 ? "mods" : "mod"} no download could be found. Some mods can be found in the mod browser.",
      );
    }

    _downloadChecker = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (_running) {
        return;
      }

      _running = true;
      await sl<ModService>().refreshCompleter!.future;
      if (!hasAllRequiredMods()) {
        final cubit = BlocProvider.of<DownloadCubit>(
          navigatorKey.currentContext!,
        );
        final states = <TaskStatus>[.enqueued, .running, .waitingToRetry];
        final tasks = cubit.state is DownloadLoaded
            ? (cubit.state as DownloadLoaded).tasks
            : <TaskRecord>[];
        final runningTasks = tasks
            .where((e) => states.contains(e.status))
            .toList();

        _running = false;

        if (runningTasks.isEmpty) {
          Logger.root.info('No more running downloads, stopping checker.');
          timer.cancel();
          _downloadChecker = null;
          emit(.new(selectedServer: server));
        }

        return;
      }

      NotificationService.showNotification(
        message: 'All mods downloaded! Joining ${serverInfo.name}...',
      );

      timer.cancel();
      _downloadChecker = null;
      _running = false;

      if (router.routeInformationProvider.value.uri.toString() != '/home') {
        await router.pushReplacement('/home');
      }

      if (state.selectedServer != server) {
        selectServer(server);
      }

      await _joinServer();
    });
  }
}
