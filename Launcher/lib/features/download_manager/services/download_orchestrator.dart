import 'dart:async';
import 'dart:convert';
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

      final downloadTask = DownloadTask(
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
      );

      final result = await FileDownloader().enqueue(downloadTask);

      if (!result) {
        NotificationService.error(message: 'Failed to queue download');
        return false;
      }

      // Notify listeners immediately so the cubit refreshes its task list.
      // The background_downloader status callbacks may not fire for
      // transitional states (enqueued/running), which previously caused
      // the download manager UI to never show the download.
      try {
        final record = await FileDownloader().database.recordForId(
          downloadTask.taskId,
        );
        if (record != null) {
          _statusUpdates.add(
            TaskStatusUpdate(
              downloadTask,
              record.status ?? TaskStatus.enqueued,
            ),
          );
          notifyListeners();
        }
      } catch (e, s) {
        _logger.warning('Failed to push initial status update', e, s);
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

    try {
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
    } catch (e, s) {
      // Ensure exceptions in platform integration or side-effect handlers
      // don't prevent the status update from reaching listeners.
      _logger.warning('Error handling status update side-effects', e, s);
    }

    _statusUpdates.add(update);
    notifyListeners();
  }

  Future<void> _taskProgressCallback(TaskProgressUpdate update) async {
    _logger.finest(
      'Task progress: ${update.task.taskId} - ${(update.progress * 100).toStringAsFixed(1)}%',
    );

    try {
      if (update.progress > 0 && update.progress < 1) {
        await _platformIntegration.updateProgress(update.progress);
      }
    } catch (e, s) {
      _logger.warning('Error updating platform progress', e, s);
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
        final name = metadata['name'] as String? ?? '';
        final version = metadata['version'] as String? ?? '';
        _logger.info('Processing queued download for $name ($version)');

        if (ModHelper.isInstalled(name, version)) {
          _logger.info('Mod $name is already installed. Skipping download.');
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

    // Snapshot .fbmod files BEFORE extraction
    final beforeFiles =
        Directory(update.task.directory)
            .listSync()
            .whereType<File>()
            .where((f) => extension(f.path) == '.fbmod' || extension(f.path) == '.fbfile')
            .map((f) => basename(f.path))
            .toSet();

    final postProcessor = DownloadPostProcessor();
    await postProcessor.processCompletedDownload(
      update,
      onProgress: onProgress,
    );

    // Persist the NexusMods mod ID in a global manifest.
    // Primary source: metadata (set by FileDownloadDialog).
    try {
      final metaDataStr = update.task.metaData;
      var modId = _parseModIdFromMetadata(metaDataStr);

      if (modId == null) {
        final match = RegExp(r'/mods/(\d+)').firstMatch(update.task.url);
        if (match != null) modId = int.tryParse(match.group(1)!);
      }

      if (modId == null) return;

      final manifest = await ModService.readManifest();

      final files = (manifest['files'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final mods = (manifest['mods'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final modMeta = _decodeMetadata(update.task.metaData);
      final modTitle = modMeta?['name'] as String? ?? update.task.displayName;
      final modVersion = modMeta?['version'] as String? ?? '';

      mods[modId.toString()] = <String, dynamic>{
        'title': modTitle,
        'latestVersion': modVersion,
        'lastDownloaded': DateTime.now().toIso8601String(),
      };

      // Snapshot AFTER extraction to find new .fbmod files
      await Future.delayed(const Duration(milliseconds: 500));
      final afterFiles =
          Directory(update.task.directory)
              .listSync()
              .whereType<File>()
              .where((f) => extension(f.path) == '.fbmod' || extension(f.path) == '.fbfile')
              .map((f) => basename(f.path))
              .toSet();

      final newFiles = afterFiles.difference(beforeFiles);

      if (newFiles.isEmpty) {
        files[basename(update.task.filename)] = modId;
      } else {
        for (final file in newFiles) {
          files[file] = modId;
        }
      }

      manifest['files'] = files;
      manifest['mods'] = mods;
      await ModService.writeManifest(manifest);
    } catch (_) {
      // Non-critical — manifest is a best-effort cache
    }
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
      final result = <String, dynamic>{
        'serverMod': serverMod.writeToJson(),
      };
      final modId = metadata['modId'];
      if (modId != null) {
        result['modId'] = modId;
      }
      return jsonEncode(result);
    } catch (e) {
      _logger.warning('Failed to encode metadata: $e');
      return '';
    }
  }

  /// Parses a mod ID from metadata. Handles new wrapper format
  /// (`{"serverMod":..., "modId":2042}`) and legacy plain ServerMod JSON.
  static int? _parseModIdFromMetadata(String metaDataString) {
    if (metaDataString.isEmpty) return null;
    try {
      final decoded = jsonDecode(metaDataString);
      if (decoded is Map<String, dynamic>) {
        final modId = decoded['modId'];
        if (modId != null) return (modId as num).toInt();
        // Legacy format: try to parse as ServerMod and extract from link
        if (decoded.containsKey('link')) {
          final link = decoded['link'] as String? ?? '';
          final match = RegExp(r'/mods/(\d+)').firstMatch(link);
          if (match != null) return int.tryParse(match.group(1)!);
        }
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? _decodeMetadata(String metaDataString) {
    if (metaDataString.isEmpty) {
      return null;
    }

    try {
      // Try new wrapper format first: {"serverMod": "...", "modId": 2042}
      final decoded = jsonDecode(metaDataString);
      if (decoded is Map<String, dynamic> && decoded.containsKey('serverMod')) {
        final serverMod = ServerMod.fromJson(decoded['serverMod'] as String);
        final result = <String, dynamic>{
          'name': serverMod.name,
          'version': serverMod.version,
          'link': serverMod.link,
          'fileSize': serverMod.fileSize.toInt(),
        };
        final modId = decoded['modId'];
        if (modId != null) result['modId'] = modId;
        return result;
      }
    } catch (_) {
      // Fall through to legacy format
    }

    try {
      // Legacy format: plain ServerMod JSON
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
