import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_downloader/background_downloader.dart';
import 'package:dio/dio.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/services/download_link_resolver.dart';
import 'package:kyber_launcher/features/download_manager/services/download_post_processor.dart';
import 'package:kyber_launcher/features/download_manager/services/incremental_updater.dart';
import 'package:kyber_launcher/features/download_manager/services/platform/download_platform_integration.dart';
import 'package:kyber_launcher/features/download_manager/services/platform/windows_taskbar_integration.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/nexusmods/dialogs/nexusmods_login.dart';
import 'package:kyber_launcher/features/settings/dialogs/update_dialog.dart';
import 'package:kyber_launcher/gen/rust/frb_generated.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class ProgressUpdate {
  ProgressUpdate(this.extracted, this.total);

  final int extracted;
  final int total;
}

@pragma('vm:entry-point')
Future<Task?> _onTaskStart(Task task) async {
  final caFile = File(
    join(FileHelper.getModuleDirectory().path, 'ca_root.pem'),
  );
  final certificate = caFile.readAsBytesSync();
  SecurityContext.defaultContext.setTrustedCertificatesBytes(certificate);

  return task;
}

@pragma('vm:entry-point')
Future<void> _onTaskDone(
  TaskStatusUpdate taskStatusUpdate, [
  SendPort? sendPort,
]) async {
  if (taskStatusUpdate.status != TaskStatus.complete) {
    return;
  }

  await MaximaLib.init();
  await DownloadOrchestrator._processCompletedDownloadInIsolate(
    taskStatusUpdate,
    (count, total) {
      sendPort?.send({'extracted': count, 'total': total});
    },
  );
}

@pragma('vm:entry-point')
Future<TaskStatusUpdate?> _onBeforeStart(Task task) {
  final parsed = Uri.parse(task.url);
  if (parsed.queryParameters.containsKey('expires')) {
    final expires = int.tryParse(parsed.queryParameters['expires']!);
    if (expires == null) {
      return Future.value();
    }

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expires < now) {
      return Future.value(
        TaskStatusUpdate(
          task,
          TaskStatus.canceled,
          TaskException('Download link expired'),
        ),
      );
    }
  }

  return Future.value();
}

@pragma('vm:entry-point')
class DownloadOrchestrator with ChangeNotifier {
  DownloadOrchestrator._({
    required DownloadLinkResolver linkResolver,
    required DownloadPlatformIntegration platformIntegration,
  }) : _linkResolver = linkResolver,
       _platformIntegration = platformIntegration;

  final DownloadLinkResolver _linkResolver;
  final DownloadPlatformIntegration _platformIntegration;
  final Logger _logger = Logger('download_orchestrator');

  final StreamController<TaskStatusUpdate> _statusUpdates =
      StreamController<TaskStatusUpdate>.broadcast();
  final StreamController<TaskProgressUpdate> _progressUpdates =
      StreamController<TaskProgressUpdate>.broadcast();
  final StreamController<ProgressUpdate> _extractionProgressUpdates =
      StreamController<ProgressUpdate>.broadcast();

  Stream<TaskStatusUpdate> get statusUpdates => _statusUpdates.stream;

  Stream<TaskProgressUpdate> get progressUpdates => _progressUpdates.stream;

  Stream<ProgressUpdate> get extractionProgressUpdates =>
      _extractionProgressUpdates.stream;

  static Future<DownloadOrchestrator> getInstance({
    DownloadLinkResolver? linkResolver,
    DownloadPlatformIntegration? platformIntegration,
  }) async {
    final now = DateTime.now();

    final platform =
        platformIntegration ??
        switch (Platform.operatingSystem) {
          'windows' => const WindowsTaskbarIntegration(),
          _ => const NoOpPlatformIntegration(),
        };

    final orchestrator = DownloadOrchestrator._(
      linkResolver: linkResolver ?? DownloadLinkResolver(),
      platformIntegration: platform,
    );

    Localstore.instance.databaseDirectory = Future.value(
      Directory(join(FileHelper.getLauncherDirectory().path, 'Downloads')),
    );

    PluginUtilities.getCallbackHandle(_onTaskDone)?.toRawHandle();
    PluginUtilities.getCallbackHandle(_onBeforeStart)?.toRawHandle();

    await FileDownloader().configure(
      globalConfig: (Config.holdingQueue, (1, 1, 1)),
    );

    await FileDownloader().ready;

    FileDownloader().receivePort.listen((message) {
      sl.get<DownloadOrchestrator>()._extractionProgressUpdates.add(
        ProgressUpdate(
          (message as Map)['extracted'] as int,
          message['total'] as int,
        ),
      );
    });

    FileDownloader().registerCallbacks(
      taskStatusCallback: orchestrator._taskStatusCallback,
      taskProgressCallback: orchestrator._taskProgressCallback,
    );

    await FileDownloader().start();

    final tasks = await FileDownloader().database.allRecords();
    orchestrator._logger.info(
      'Download orchestrator initialized. '
      'Loaded ${tasks.length} tasks '
      '(Took ${DateTime.now().difference(now).inMilliseconds}ms)',
    );

    return orchestrator;
  }

  Future<bool> enqueueDownload(DownloadRequest request) async {
    try {
      final moduleUpdate = await ModuleVersionService().updateAvailable(
        module: VersionModule.module,
      );
      if (moduleUpdate) {
        await showKyberDialog(
          context: navigatorKey.currentContext!,
          builder: (_) => const UpdateDialog(
            module: VersionModule.module,
            forceInstall: true,
          ),
        );
      }

      final resolved = await _linkResolver.resolve(request);
      final tasks = await FileDownloader().database.allRecords();
      if (tasks.any(
        (e) => e.task.url == resolved.url && e.status.isNotFinalState,
      )) {
        _logger.info('Download already in progress: ${resolved.filename}');
        return false;
      }

      final isZipFile = extension(resolved.filename) == '.zip';
      final useIncrementalUpdate =
          Preferences.general.incrementalDownloadsEnabled;

      if (useIncrementalUpdate && isZipFile) {
        final updater = IncrementalUpdater();
        final isEligible = await updater.checkEligibility(resolved.url);
        if (isEligible) {
          _logger.info('Using incremental update for ${request.displayName}');

          return enqueueIncrementalUpdate(
            resolved.url,
            request: request,
          );
        }
      }

      final result = await FileDownloader().enqueue(
        DownloadTask(
          url: resolved.url,
          directory:
              '${Platform.isMacOS ? '/' : ''}${ModService.getBasePath()}',
          filename: resolved.filename,
          displayName: request.displayName,
          updates: Updates.statusAndProgress,
          retries: 1,
          priority: request.priority,
          allowPause: true,
          baseDirectory: BaseDirectory.root,
          metaData: _encodeMetadata(request.metadata),
          options: TaskOptions(
            beforeTaskStart: _onBeforeStart,
            onTaskStart: _onTaskStart,
            onTaskFinished: _onTaskDone,
          ),
        ),
      );

      if (!result) {
        NotificationService.error(message: 'Failed to queue download');
        return false;
      }

      _logger.info('Enqueued download: ${request.displayName}');
      return true;
    } on Exception catch (e, s) {
      if (e.toString().contains('LoginError')) {
        await showKyberDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => const NexusmodsLogin(),
        );
        if (!Preferences.nexusMods.isLoggedIn) {
          NotificationService.error(
            title: 'Failed to download mod',
            message: 'Could not login to NexusMods',
          );
          _logger.severe('Could not prepare download', e, s);
          return false;
        }

        return enqueueDownload(request);
      } else {
        NotificationService.error(
          title: 'Failed to prepare download',
          message: e.toString(),
        );
        _logger.severe('Could not prepare download', e, s);
        return false;
      }
    } catch (e, s) {
      _logger.severe(
        'Could not enqueue download: ${request.displayName}',
        e,
        s,
      );
      NotificationService.error(
        message: 'Failed to start download: $e',
      );
      return false;
    }
  }

  Future<bool> pauseDownload(String taskId) async {
    try {
      final record = await FileDownloader().database.recordForId(taskId);
      if (record == null || record.task is! DownloadTask) {
        return false;
      }

      return await FileDownloader().pause(record.task as DownloadTask);
    } catch (e, s) {
      _logger.warning('Failed to pause download', e, s);
      return false;
    }
  }

  Future<bool> resumeDownload(String taskId) async {
    try {
      final record = await FileDownloader().database.recordForId(taskId);
      if (record == null || record.task is! DownloadTask) {
        return false;
      }

      return await FileDownloader().resume(record.task as DownloadTask);
    } catch (e, s) {
      _logger.warning('Failed to resume download', e, s);
      return false;
    }
  }

  Future<bool> cancelDownload(String taskId) async {
    try {
      return await FileDownloader().cancelTaskWithId(taskId);
    } catch (e, s) {
      _logger.warning('Failed to cancel download', e, s);
      return false;
    }
  }

  Future<bool> enqueueIncrementalUpdate(
    String downloadUrl, {
    required DownloadRequest request,
  }) async {
    final task = CallbackTask(
      execute: (controller) async {
        final updater = IncrementalUpdater();
        final result = await updater.update(
          downloadUrl: downloadUrl,
          controller: controller,
          onPhaseChanged: (phase) {
            if (phase != .downloadingMissingMods) {
              controller.updateProgress(1);
            } else if (phase == .downloadingMissingMods) {
              controller.updateProgress(0);
            }
          },
          onProgress: (current, total) {
            sl.get<DownloadOrchestrator>()._extractionProgressUpdates.add(
              .new(current, total),
            );
          },
          onDownloadProgress: (bytes, totalBytes) {
            controller.updateBytesTransferred(
              bytes,
              totalBytes,
              interval: const Duration(milliseconds: 500),
            );
          },
        );

        if (result) {
          await sl.isReady<ModService>();
          await sl.get<ModService>().refresh();
          controller.complete();
        } else {
          controller.fail('Failed to apply incremental update');
        }
      },
      displayName: request.displayName,
      priority: 1,
      metaData: _encodeMetadata(request.metadata),
    );

    final enqueued = await FileDownloader().enqueue(task);
    if (!enqueued) {
      _logger.warning('Failed to enqueue incremental update');
      return false;
    }

    _logger.info('Enqueued incremental update: ${task.displayName}');
    return true;
  }

  Future<void> _taskStatusCallback(TaskStatusUpdate update) async {
    _logger.fine(
      'Task status update: ${update.task.taskId} - ${update.status}',
    );

    if (update.status == .complete) {
      await sl.isReady<ModService>();
      await sl.get<ModService>().refresh();

      await _checkAndCancelDuplicates(update);
    } else if (update.status == .failed) {
      await _handleFailedDownload(update);
    } else if (update.status == .running) {
      await _platformIntegration.updateProgress(0);
    }

    if (update.status == .canceled ||
        update.status == .complete ||
        update.status == .failed ||
        update.status == .paused) {
      await _platformIntegration.clear();
    }

    _statusUpdates.add(update);
    notifyListeners();
  }

  Future<void> _taskProgressCallback(TaskProgressUpdate update) async {
    _logger.finest(
      'Task progress: ${update.task.taskId} - ${(update.progress * 100).toStringAsFixed(1)}%',
    );

    if (update.progress > 0 && update.progress < 1) {
      await _platformIntegration.updateProgress(update.progress);
    }

    _progressUpdates.add(update);
  }

  Future<void> _checkAndCancelDuplicates(TaskStatusUpdate update) async {
    final tasks = await FileDownloader().database.allRecords();
    final queuedTasks = tasks.where(
      (e) =>
          (e.status == .enqueued || e.status == .running) &&
          e.task.priority == 1,
    );

    for (final task in queuedTasks) {
      final metadata = _decodeMetadata(task.task.metaData);
      if (metadata == null || metadata.isEmpty) {
        continue;
      }

      try {
        final mod = ServerMod.fromJson(task.task.metaData);
        _logger.info(
          'Processing queued download for ${mod.name} (${mod.version})',
        );

        if (ModHelper.isInstalled(mod.name, mod.version)) {
          _logger.info(
            'Mod ${mod.name} is already installed. Skipping download.',
          );
          await FileDownloader().cancelTaskWithId(task.task.taskId);
        }
      } catch (e) {
        continue;
      }
    }
  }

  Future<void> _handleFailedDownload(TaskStatusUpdate update) async {
    final exception = update.exception;
    if (exception != null) {
      _logger.severe('Download failed: ${update.task.displayName}', exception);
    }

    final errorDescription = exception?.description.toLowerCase();
    if (errorDescription != null) {
      if (errorDescription.endsWith('link expired') ||
          errorDescription.contains('requested range')) {
        await FileDownloader().cancelTaskWithId(update.task.taskId);
        NotificationService.error(
          message:
              'Download failed: Link expired. Try starting the download again.',
        );
      } else {
        NotificationService.error(
          message: 'Download failed: $errorDescription',
        );
      }
    } else {
      NotificationService.error(
        message: 'Download failed: ${update.task.displayName}',
      );
    }
  }

  static Future<void> _processCompletedDownloadInIsolate(
    TaskStatusUpdate update,
    ProgressCallback? onProgress,
  ) async {
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      print('[${record.loggerName}] ${record.level.name}: ${record.message}');
    });

    final postProcessor = DownloadPostProcessor();
    await postProcessor.processCompletedDownload(
      update,
      onProgress: onProgress,
    );
  }

  String _encodeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) {
      return '';
    }

    try {
      final serverMod = ServerMod(
        name: metadata['name'] as String? ?? '',
        version: metadata['version'] as String? ?? '',
        link: metadata['link'] as String? ?? '',
        fileSize: Int64(metadata['fileSize'] as int? ?? 0),
      );
      return serverMod.writeToJson();
    } catch (e) {
      _logger.warning('Failed to encode metadata: $e');
      return '';
    }
  }

  Map<String, dynamic>? _decodeMetadata(String metaDataString) {
    if (metaDataString.isEmpty) {
      return null;
    }

    try {
      final serverMod = ServerMod.fromJson(metaDataString);
      return {
        'name': serverMod.name,
        'version': serverMod.version,
        'link': serverMod.link,
        'fileSize': serverMod.fileSize.toInt(),
      };
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _statusUpdates.close();
    _progressUpdates.close();
    super.dispose();
  }
}
