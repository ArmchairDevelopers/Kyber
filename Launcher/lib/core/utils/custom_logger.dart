import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart' as mx;
import 'package:kyber_launcher/main.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class CustomLogger {
  static late File _logFile;

  static void initialize({bool isIsolate = false}) {
    _logFile = File(join(applicationDocumentsDirectory, 'log.txt'));
    if (!isIsolate) {
      _createLogFile();
    }

    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen(
      (record) async {
        final loggerName = record.loggerName.isEmpty
            ? 'root'
            : record.loggerName;

        final errorMessage = record.error != null
            ? ' - ${record.error}${record.stackTrace != null ? ' \n\nStackTrace:\n${record.stackTrace}' : ''}'
            : '';
        final message =
            '${record.level.name} - [$loggerName] - ${record.message}$errorMessage';

        if (kDebugMode) {
          print(message);
        }

        if (!isIsolate) {
          _logToFile(
            "[${DateTime.now().toString().split('.').first}] $message",
          );
        }
      },
    );

    FlutterError.onError = (details) {
      Logger.root.severe(
        'Uncaught exception: ${details.exception}\n${details.stack}',
      );
      Sentry.captureException(details.exception, stackTrace: details.stack);
    };
  }

  static void setupRustLogs() {
    final debugLogsEnabled = Preferences.debug.frbDebugLogs;
    if (debugLogsEnabled) {
      PlatformInAppWebViewController.debugLoggingSettings.enabled = true;
      PlatformInAppWebViewController.debugLoggingSettings.usePrint = true;
      Logger.root.level = Level.ALL;
    }

    mx.setupLogStream().listen((event) {
      final Level level = switch (event.logLevel) {
        mx.Level.debug => .FINE,
        mx.Level.error => .SEVERE,
        mx.Level.info => .INFO,
        mx.Level.trace => .ALL,
        mx.Level.warn => .WARNING,
      };

      final loggerName = event.lbl.isEmpty ? 'root' : event.lbl;
      Logger(loggerName).log(level, event.msg);
    });
  }

  static Future<void> requestLogExport() async {
    final file = await getSaveLocation(
      suggestedName:
          'logs_${DateTime.now().toString().split('.').first.replaceAll(':', '-').replaceAll(' ', '_')}.zip',
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Zip-Archive',
          extensions: ['zip'],
        ),
      ],
    );

    if (file == null) {
      return;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final maximaLog = File(
      'C:/ProgramData/Maxima/Logs/MaximaBackgroundService.log',
    );
    final launcherLog = File(join(applicationDocumentsDirectory, 'log.txt'));
    final crashDumpsDir = Directory(
      '${documentsDirectory.path}\\STAR WARS Battlefront II\\CrashDumps',
    );
    var crashDumps = <File>[];
    if (crashDumpsDir.existsSync()) {
      crashDumps = crashDumpsDir.listSync().whereType<File>().toList()
        ..sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );
    }

    final encoder = ZipFileEncoder()..create(file.path);

    if (maximaLog.existsSync()) {
      await encoder.addFile(maximaLog, 'maxima-log.txt');
    }

    if (launcherLog.existsSync()) {
      await encoder.addFile(launcherLog, 'launcher-log.txt');
    }

    if (Directory(
      "${Platform.environment['APPDATA']}\\ArmchairDevelopers\\Kyber\\Logs",
    ).existsSync()) {
      final kyberLogsList = Directory(
        "${Platform.environment['APPDATA']}\\ArmchairDevelopers\\Kyber\\Logs",
      ).listSync();
      final kyberLogs =
          kyberLogsList
              .where((e) => basename(e.path).startsWith('kyber_'))
              .toList()
            ..sort(
              (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
            );
      final kyberServerLogs =
          kyberLogsList
              .where((e) => basename(e.path).startsWith('kyber-server'))
              .toList()
            ..sort(
              (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
            );
      if (kyberLogs.isNotEmpty) {
        await encoder.addFile(File(kyberLogs.last.path));
      }

      if (kyberServerLogs.isNotEmpty) {
        await encoder.addFile(File(kyberServerLogs.last.path));
      }

      if (crashDumps.isNotEmpty) {
        await encoder.addFile(File(crashDumps.last.path));
      }
    }

    await encoder.close();
    NotificationService.showNotification(
      message: 'Logs successfully exported',
      severity: InfoBarSeverity.success,
    );
  }

  static String getLogs() {
    return _logFile.readAsStringSync();
  }

  static void _logToFile(String message) {
    if (kDebugMode) {
      return;
    }

    try {
      _logFile.writeAsStringSync(
        '$message${Platform.lineTerminator}',
        mode: FileMode.writeOnlyAppend,
        flush: true,
      );
    } on FileSystemException catch (_) {}
  }

  static void clearLogFile() {
    _logFile.writeAsStringSync('');
  }

  static void _createLogFile() {
    if (!_logFile.existsSync()) {
      _logFile.createSync();
    }

    if (_logFile.lengthSync() > 1024 * 1024 * 5) {
      _logFile
        ..deleteSync()
        ..createSync();
    }
  }
}
