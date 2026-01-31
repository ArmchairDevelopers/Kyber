import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_completion/cli_completion.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_cli/commands/download_game.dart';
import 'package:kyber_cli/commands/get_ea_token.dart';
import 'package:kyber_cli/commands/get_token.dart';
import 'package:kyber_cli/commands/start_game.dart';
import 'package:kyber_cli/commands/start_server_command.dart';
import 'package:kyber_cli/gen/api/archive.dart';
import 'package:kyber_cli/gen/api/maxima.dart' as mx;
import 'package:kyber_cli/utils/windows_env.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart';

final sl = GetIt.instance;
const version = '2.0.0-beta9+1';
const executableName = 'kyber_cli';
const packageName = 'kyber_cli';
const description = 'A CLI for Kyber.';

class KyberCliCommandRunner extends CompletionCommandRunner<int> {
  String customInfoStyle(String level, String? message) {
    final x = '[$level] - $message';
    return "[${DateTime.now().toString().split('.').first}] $x";
  }

  KyberCliCommandRunner({Logger? logger}) : super(executableName, description) {
    _logger =
        logger ??
        Logger(
          theme: LogTheme(
            alert: (message) => customInfoStyle('alert', message),
            detail: (message) => customInfoStyle('detail', message),
            err: (message) => customInfoStyle('error', message),
            info: (message) => customInfoStyle('info', message),
            success: (message) => customInfoStyle('info', message),
            warn: (message) => customInfoStyle('warn', message),
          ),
        );

    _logger.level = Level.info;

    mxLogs = mx.setupLogStream().asBroadcastStream();

    argParser
      ..addFlag('skip-updates', help: 'Skip checking for updates.')
      ..addFlag('version', negatable: false, help: 'Print the current version.')
      ..addFlag(
        'verbose',
        abbr: 'v',
        help: 'Noisy logging, including all shell commands executed.',
      )
      ..addFlag('debug', help: 'Enable debug mode. Logs all maxima events.');

    addCommand(StartServerCommand(logger: _logger, logStream: mxLogs));
    addCommand(StartGameCommand(logger: _logger));
    addCommand(GetTokenCommand(logger: _logger));
    addCommand(GetEATokenCommand(logger: _logger));
    addCommand(SetupServerCommand(logger: _logger));
  }

  @override
  void printUsage() => _logger.info(usage);

  late Logger _logger;

  late Stream<mx.LogEntry> mxLogs;

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final topLevelResults = parse(args);
      if (topLevelResults['verbose'] == true) {
        _logger.level = Level.verbose;
      }

      final mxDebug = topLevelResults['debug'] == true;

      mxLogs.listen((event) {
        final loggerName = event.lbl.isEmpty ? 'root' : event.lbl;
        final message = '[$loggerName] - ${event.msg}';
        switch (event.logLevel) {
          case mx.Level.debug:
          case mx.Level.trace:
            if (!mxDebug) {
              return;
            }

            _logger.detail(message);
          case mx.Level.error:
            _logger.err(message);
          case mx.Level.info:
            _logger.info(message);
          case mx.Level.warn:
            _logger.warn(message);
        }
      });

      final apiEnv = Platform.environment['KYBER_API_ENV'] ?? 'prod';

      const skipCommands = ['get_token', 'get_ea_token'];
      if (!skipCommands.contains(topLevelResults.command?.name)) {
        Env.set('MAXIMA_DISABLE_QRC', '1');
      }

      Env.set('KYBER_ENVIRONMENT', apiEnv);
      sl.registerSingleton(KyberGRPCService.fromEnv(apiEnv));

      final kyberToken = Platform.environment['KYBER_TOKEN'];
      if (kyberToken?.isNotEmpty ?? false) {
        sl.get<KyberGRPCService>().token = kyberToken;
        _logger.info('Using provided KYBER_TOKEN for API authentication.');
      }

      if (topLevelResults.command != null &&
          !topLevelResults.arguments.contains('--help')) {
        final isLinux = Platform.isLinux;
        final hasModuleEnv = Platform.environment.containsKey(
          'KYBER_MODULE_CHANNEL',
        );

        if (!topLevelResults.arguments.contains('--skip-updates') &&
            (!isLinux || hasModuleEnv) &&
            [
              'start_server',
              'start_game',
            ].contains(topLevelResults.command!.name)) {
          final userBranch =
              (Platform.environment['KYBER_MODULE_CHANNEL'] ??
                      topLevelResults.command!['module-branch'])
                  as String?;
          _logger.info('Checking for updates...');

          final rq = ServiceVersionsRequest(
            id: 'kyber-module',
            channel: userBranch ?? 'stable',
          );
          final versions = await sl
              .get<KyberGRPCService>()
              .launcherClient
              .versions(rq);
          final latestVersion = versions.versions.firstWhere((x) => x.isLatest);
          final currentVersionFile = File(
            join(FileHelper.getModuleDirectory().path, 'VERSION'),
          );

          var needsUpdate = false;
          if (!currentVersionFile.existsSync()) {
            needsUpdate = true;
          } else {
            final currentVersion = currentVersionFile.readAsStringSync();
            needsUpdate = currentVersion != latestVersion.version;
          }

          if (needsUpdate) {
            _logger.info(
              'Updating "kyber-module" to version ${latestVersion.version}',
            );

            final download = await sl
                .get<KyberGRPCService>()
                .launcherClient
                .downloadUrl(
                  ServiceVersionDownloadUrlRequest(
                    id: 'kyber-module',
                    version: latestVersion.version,
                    channel: userBranch ?? 'stable',
                  ),
                );

            final filename = basename(download.url).split('?').first;
            final downloadDir = FileHelper.getModuleDirectory().path;
            final downloadPath = join(downloadDir, filename);
            _logger.info('Downloading to $downloadPath');
            await Dio().download(download.url, downloadPath);

            if (!Directory(downloadDir).existsSync()) {
              Directory(downloadDir).createSync();
            }

            _logger.info('Extracting...');
            await extract(filePath: downloadPath, targetDir: downloadDir);
            File(downloadPath).deleteSync();

            currentVersionFile.writeAsStringSync(latestVersion.version);
            _logger.info(
              'Updated "kyber-module" to version ${latestVersion.version}',
            );
          }
        }

        final command = topLevelResults.command!;
        final isDummy =
            command.name == 'start_server' && command['credentials'] != null;
        await mx.startMaxima(dummyAuthStorage: isDummy);
      }

      return await runCommand(topLevelResults) ?? ExitCode.success.code;
    } on FormatException catch (e, stackTrace) {
      _logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on UsageException catch (e) {
      _logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);
      return ExitCode.usage.code;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.command?.name == 'completion') {
      await super.runCommand(topLevelResults);
      return ExitCode.success.code;
    }

    _logger
      ..detail('Argument information:')
      ..detail('  Top level options:');
    for (final option in topLevelResults.options) {
      if (topLevelResults.wasParsed(option)) {
        _logger.detail('  - $option: ${topLevelResults[option]}');
      }
    }
    if (topLevelResults.command != null) {
      final commandResult = topLevelResults.command!;
      _logger
        ..detail('  Command: ${commandResult.name}')
        ..detail('    Command options:');
      for (final option in commandResult.options) {
        if (commandResult.wasParsed(option)) {
          _logger.detail('    - $option: ${commandResult[option]}');
        }
      }
    }

    final int? exitCode;
    if (topLevelResults['version'] == true) {
      print(version);
      exitCode = ExitCode.success.code;
    } else {
      exitCode = await super.runCommand(topLevelResults);
    }

    return exitCode;
  }
}
