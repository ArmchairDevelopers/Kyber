import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_cli/command_runner.dart';
import 'package:kyber_cli/gen/api/maxima.dart';
import 'package:kyber_cli/models/maxima_instance.dart';
import 'package:kyber_cli/utils/collection_helper.dart';
import 'package:kyber_cli/utils/env_helper.dart';
import 'package:kyber_cli/utils/extensions/server_mod_extension.dart';
import 'package:kyber_cli/utils/kyber_grpc_server.dart';
import 'package:kyber_cli/utils/mod_helper.dart';
import 'package:kyber_cli/utils/services/level_declaration_service.dart';
import 'package:kyber_cli/utils/types/raw_mods.dart';
import 'package:kyber_cli/utils/windows_env.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart';

const _denuvoLogPrefix = 'Got Denuvo Token: ';

class StartServerCommand extends Command<int> {
  StartServerCommand({required Logger logger, required this.logStream})
    : _logger = logger {
    argParser
      ..addFlag('show-console', help: 'Shows the Kyber console window.')
      ..addFlag(
        'no-dedicated',
        help: 'Starts a non-dedicated server',
        negatable: false,
      )
      ..addFlag(
        'lan',
        help: 'Starts a LAN-only server without registering with Kyber API or proxies.',
        negatable: false,
      )
      ..addSeparator('Server Options')
      ..addOption('server-name', abbr: 'n', help: 'Specify the server name')
      ..addOption('server-password', abbr: 'p', help: 'Specify the server name')
      ..addOption('server-description', help: 'Specify the server description')
      ..addOption(
        'server-port',
        defaultsTo: '25200',
        help: 'Specify the LAN game server port',
      )
      ..addOption(
        'max-players',
        defaultsTo: '40',
        help: 'Specify the maximum number of players',
      )
      ..addOption('mode', help: 'Specify the mode')
      ..addOption('map', help: 'Specify the map')
      ..addOption('rotation-file', help: 'Specify the rotation file to use')
      ..addOption(
        'startup-commands',
        help: 'Specify a text file with startup commands',
        valueHelp: 'path/to/commands.txt',
      )
      ..addSeparator('Game Options')
      ..addOption(
        'collection-file',
        help: 'Specify the Mod Collection file to use',
        valueHelp: 'path/to/collection.kmodcollection',
      )
      ..addOption(
        'collection-mods-directory',
        help: 'Specify the directory to use for the collection mods',
        valueHelp: 'path/to/mods',
      )
      ..addOption(
        'raw-mods',
        help: 'Specify a list of mods to use',
        valueHelp: 'path/to/mod_file.json',
      )
      ..addOption(
        'mod-folder',
        help:
            'Specify a directory that contains a collection file and all required mods',
        valueHelp: 'path/to/dir',
      )
      ..addOption('game-path', help: 'Specify the game path')
      ..addMultiOption(
        'game-args',
        help: 'Specify the game arguments',
        valueHelp: '[arg1, arg2, ...]',
      )
      ..addSeparator('Maxima Options')
      ..addOption(
        'credentials',
        abbr: 'c',
        help: 'Specify the credentials to use for EA login',
        valueHelp: 'persona:password',
      )
      ..addOption('token', help: 'Specify the Kyber auth token')
      ..addOption(
        'module-path',
        help: 'Specify a custom directory to use for the Kyber module',
        valueHelp: 'path/to/module',
      )
      ..addOption(
        'module-branch',
        help: 'Specify the branch to use for the Kyber module',
        valueHelp: 'branch',
      )
      ..addOption('offer-id', help: 'Specify the offer ID')
      ..addOption('interface-port', valueHelp: '9000');
  }

  @override
  String get description =>
      '''Starts a dedicated Kyber server with the given options''';

  @override
  String get name => 'start_server';

  final Logger _logger;
  final Stream<LogEntry> logStream;

  @override
  Future<int> run() async {
    final allowDedicated = Platform.environment['KYBER_BYPASS_DOCKER_I_REALLY_KNOW_WHAT_I_AM_DOING'];
    if (allowDedicated == null || allowDedicated.isEmpty) {
      _logger.info(
        'To host dedicated servers, please use our Docker image. For more information, visit https://docs.kyber.gg',
      );
      return ExitCode.usage.code;
    }

    final serverName =
        (Platform.environment['KYBER_SERVER_NAME'] ??
                argResults?['server-name'])
            as String?;
    if (serverName == null || serverName.isEmpty) {
      _logger.err('server-name is required');
      return ExitCode.usage.code;
    }

    final modulePath = argResults?['module-path'] as String?;
    EnvHelper.setPath(modulePath);

    _logger.info('Starting login flow...');
    late String playerName;
    final loginCredentials = argResults?['credentials'] as String?;
    try {
      if (loginCredentials == null) {
        final player = await loginFlow();
        playerName = player.displayName;
      } else {
        playerName = 'ServerUser';
        final split = loginCredentials.split(':');
        if (split.length != 2) {
          _logger.err('Invalid credentials format. Use persona:password');
          return ExitCode.usage.code;
        }
      }
    } catch (e) {
      if (e is PanicException || e is AnyhowException) {
        final err = e is PanicException
            ? e.message
            : (e as AnyhowException).message;
        if (err.contains('unknown variant `NO_SUCH_USER`')) {
          _logger.err('Login failed: The specified user does not exist');
        } else {
          _logger.err('Login failed: $err');
        }
        return ExitCode.usage.code;
      }

      _logger.err('Login failed: $e');
      return ExitCode.usage.code;
    }

    _logger
      ..success('Logged in as $playerName.')
      ..info('Starting game...');

    final mapRotation = <LevelSetup>[];
    if (argResults?['rotation-file'] != null ||
        Platform.environment.containsKey('KYBER_MAP_ROTATION')) {
      File? file;
      if ((argResults?['rotation-file'] as String?) != null) {
        final file = File(argResults?['rotation-file'] as String);
        if (!file.existsSync()) {
          _logger.err('The specified rotation file does not exist');
          return ExitCode.usage.code;
        }
      }

      late List<String> data;
      if (Platform.environment.containsKey('KYBER_MAP_ROTATION')) {
        data = utf8
            .decode(base64.decode(Platform.environment['KYBER_MAP_ROTATION']!))
            .split('\n');
      } else {
        data = file!.readAsLinesSync();
      }
      for (final line in data) {
        if (line.isEmpty || line.startsWith('#')) {
          continue;
        }

        final split = line.split(';');
        if (split.length != 2) {
          _logger.err('Invalid rotation file');
          return ExitCode.usage.code;
        }

        mapRotation.add(LevelSetup(map: split[1], mode: split[0]));
      }

      _logger.info('Loaded map rotation with ${mapRotation.length} entries');
    }

    File? collectionFile;
    final modFolder =
        Platform.environment['KYBER_MOD_FOLDER'] ??
        argResults?['mod-folder'] as String?;
    if (modFolder != null) {
      final dir = Directory(modFolder);
      if (!dir.existsSync()) {
        _logger.err('The specified mod folder does not exist');
        return ExitCode.usage.code;
      }

      final collectionFiles = dir
          .listSync()
          .whereType<File>()
          .where((e) => e.path.endsWith('.kbcollection'))
          .toList();
      if (collectionFiles.isEmpty) {
        _logger.err(
          'The specified mod folder does not contain a collection file',
        );
        return ExitCode.usage.code;
      }

      if (collectionFiles.length > 1) {
        _logger.err(
          'The specified mod folder contains multiple collection files',
        );
        return ExitCode.usage.code;
      }

      collectionFile = collectionFiles.first;
    } else if (argResults?['collection-file'] != null) {
      collectionFile = File(argResults?['collection-file'] as String);
      await CollectionHelper().useCollection(collectionFile);
    }

    late String kToken;
    if (argResults?['token'] != null) {
      kToken = argResults?['token'] as String;
    } else {
      try {
        final authToken = await getAuthToken();
        final resp = await sl.get<KyberGRPCService>().login(authToken);
        kToken = resp.token;
      } catch (e) {
        if (e is GrpcError) {
          if (e.code == StatusCode.unauthenticated ||
              e.code == StatusCode.permissionDenied) {
            _logger.err('Kyber  Login Error: ${e.message}');
          } else {
            _logger.err('Failed to fetch Kyber auth token: $e');
          }

          return ExitCode.usage.code;
        }
      }
    }

    sl.get<KyberGRPCService>().token = kToken;

    final userId = _stableStringHash(loginCredentials?.split(':').first ?? '');
    final licenseId = '${userId}_file';
    final denuvoId = '${userId}_denuvo';

    final existingToken = await _fetchLicense(id: denuvoId);
    if (existingToken != null) {
      _logger.info('Found existing Denuvo token, using it...');
      Env.set('MAXIMA_DENUVO_TOKEN', existingToken);
    }

    Env.delete('KYBER_HIDE_CONSOLE');
    final showConsole = argResults?['show-console'] as bool?;
    if (showConsole != null && showConsole) {
      Env.set('KYBER_HIDE_CONSOLE', '1');
    }

    Env.set('KYBER_API_TOKEN', kToken);
    final lanMode = argResults?['lan'] as bool? ?? false;
    Env.set('KYBER_ONLINE_MODE', lanMode ? '0' : '1');
    Env.set(
      'KYBER_SERVER_PORT',
      lanMode ? argResults?['server-port'] as String? ?? '25200' : '25200',
    );

    final noDedicated = argResults?['no-dedicated'] as bool? ?? false;
    Env.set('KYBER_DEDICATED_SERVER', noDedicated ? '0' : '1');
    if (noDedicated) {
      Env.delete('KYBER_DEDICATED_SERVER');
    }

    final kyberPort =
        argResults?['interface-port'] as String? ??
        (await KyberNetworkHelper.findAvailablePort()).toString();
    Env.set('KYBER_INTERFACE_PORT', kyberPort);
    Env.set('KYBER_API_HOSTNAME', sl.get<KyberGRPCService>().host);
    Env.set('KYBER_HTTP_HOSTNAME', sl.get<KyberGRPCService>().httpHostname);

    await _fetchLicense(id: licenseId, isFile: true);

    logStream.listen((event) {
      switch (event.msg) {
        case final String msg when event.msg.startsWith(_denuvoLogPrefix):
          final token = msg.substring(_denuvoLogPrefix.length);
          _uploadLicense(id: denuvoId, data: token);
      }
    });

    final rawModsPath = argResults?['raw-mods'] as String?;
    ModData? modData;
    var gameplayMods = <FrostyMod>[];
    if (collectionFile != null) {
      final metaData = await ModCollection.readCollection(collectionFile);
      var modsDir =
          modFolder ??
          argResults?['collection-mods-directory'] as String? ??
          CollectionHelper().getModsDirectory();

      final mods = CollectionHelper().getModsList(
        metaData,
        modDirectory: modsDir,
      );
      final apiMods = CollectionHelper().getModsList(
        metaData,
        listFrostyCollectionMods: false,
      );

      _logger.info('Reading ${mods.length} mods');
      final fbMods = ModHelper.readFrostyMods(
        apiMods.map((e) => join(modsDir, basename(e))).toList(),
      );

      if (Platform.isLinux) {
        modsDir = 'Z:${modsDir.replaceAll('/', r'\')}';
      }

      gameplayMods = ModHelper.filterGameplayMods(fbMods);
      _logger.info(
        'Got ${fbMods.length} and ${gameplayMods.length} gameplay mods from collection',
      );

      modData = ModData(
        basePath: modsDir,
        modPaths: mods,
        mods: gameplayMods.map((e) => e.toServerMod()),
        explodedMods: ModHelper.expandMods(
          gameplayMods,
        ).map((e) => e.toServerMod()),
      );
    } else if (rawModsPath != null) {
      final rawModsFile = File(rawModsPath);
      if (!rawModsFile.existsSync()) {
        _logger.err('The specified raw-mods file does not exist');
        return ExitCode.usage.code;
      }

      final data = rawModsFile.readAsStringSync();
      final rawMods = RawMods.fromJson(
        jsonDecode(data) as Map<String, dynamic>,
      );
      final fbMods = ModHelper.readFrostyMods(
        rawMods.modPaths.map((e) => join(rawMods.basePath, e)).toList(),
      );

      gameplayMods = ModHelper.filterGameplayMods(fbMods);

      modData = ModData(
        basePath: rawMods.basePath,
        modPaths: rawMods.modPaths,
        mods: gameplayMods.map((e) => e.toServerMod()),
        explodedMods: ModHelper.expandMods(
          gameplayMods,
        ).map((e) => e.toServerMod()),
      );
    }

    final modEntries = <String, ModEntry>{};
    for (final mod in gameplayMods.where(
      (element) =>
          kRequiredCategories.contains(
            element.details.category.toLowerCase(),
          ) &&
          element.customFrostyData != null,
    )) {
      final modes = mod.customFrostyData!.modes
          .map(
            (e) => CustomMode(
              e.name,
              e.id,
              e.maxPlayers ?? -1,
              base64.decode(e.image),
            ),
          )
          .toList();
      final maps = mod.customFrostyData!.maps
          .map(
            (e) => CustomMap(
              e.name,
              e.id,
              e.supportedModes ?? [],
              base64.decode(e.image),
            ),
          )
          .toList();

      modEntries[mod.filename.replaceAll(r'\', '/')] = ModEntry(
        maps,
        modes,
        mod.customFrostyData!.modeMappings ?? {},
        mod.customFrostyData!.modeNameOverrides ?? {},
      );
    }

    sl
      ..registerSingleton<LevelDeclarationService>(LevelDeclarationService())
      ..get<LevelDeclarationService>().set(modEntries);

    var startupCommands = <String>[];
    if (argResults?['startup-commands'] != null) {
      final file = File(argResults?['startup-commands'] as String);
      if (!file.existsSync()) {
        _logger.err('The specified startup commands file does not exist');
        return ExitCode.usage.code;
      }

      startupCommands = file.readAsLinesSync();
    }

    _logger.info('Kyber is listening on port $kyberPort');

    final server = KyberGRPCServer();
    await server.start();

    final maxPlayers = argResults?['max-players'] != null
        ? int.tryParse(argResults!['max-players'] as String) ?? 40
        : 40;
    server.setInitializeRequest(
      InitializeRequest(
        modData: modData,
        startupCommands: startupCommands,
        startServer: StartServerRequest(
          password:
              (Platform.environment['KYBER_SERVER_PASSWORD'] ??
                      argResults?['server-password'])
                  as String?,
          description:
              (Platform.environment['KYBER_SERVER_DESCRIPTION'] ??
                      argResults?['server-description'])
                  as String?,
          mapRotation: mapRotation.isNotEmpty
              ? mapRotation
              : [
                  LevelSetup(
                    map:
                        argResults?['map'] as String? ??
                        'S5_1/Levels/MP/Geonosis_01/Geonosis_01',
                    mode:
                        argResults?['mode'] as String? ??
                        'HeroesVersusVillains',
                  ),
                ],
          maxPlayers:
              int.tryParse(
                Platform.environment['KYBER_SERVER_MAX_PLAYERS'] ?? '',
              ) ??
              maxPlayers,
          name: serverName,
        ),
      ),
    );

    late int pid;
    if (loginCredentials == null) {
      pid = await startGame(
        gameSlug: 'star-wars-battlefront-2',
        gamePathOverride: argResults?['game-path'] as String?,
        gameArgs: [],
      );
    } else {
      final split = loginCredentials.split(':');

      pid = await startGame(
        gameSlug: 'star-wars-battlefront-2',
        gamePathOverride: argResults?['game-path'] as String?,
        gameArgs: [],
        user: split[0],
        pass: split[1],
      );
    }

    final moduleDir = modulePath ?? FileHelper.getModuleDirectory().path;
    final moduleFile = join(moduleDir, 'Kyber.dll');
    _logger
      ..info('Game started with PID: $pid')
      ..info('Injecting Kyber from $moduleFile');

    await injectKyber(pid: pid, path: moduleFile);

    sl.registerSingleton<MaximaGameInstance>(
      MaximaGameInstance(
        pid: pid,
        isDedicated: true,
        clientService: .new('', 0),
        mods: gameplayMods,
      ),
    );

    final completion = Completer<void>();
    lsxGetEventStream(pid: pid).listen(
      (event) async {
        if (event == 'RequestLicense') {
          _logger.success('Kyber started');
          _uploadLicense(id: licenseId);
        }
      },
      onDone: completion.complete,
      onError: (e) => completion.complete(),
    );

    await completion.future;

    return ExitCode.success.code;
  }

  Future<String?> _fetchLicense({
    required String id,
    bool isFile = false,
  }) async {
    final endpoint = Platform.environment['KYBER_LICENSE_ENDPOINT'];
    final authToken = Platform.environment['KYBER_LICENSE_AUTH_TOKEN'];
    if (endpoint == null || authToken == null) {
      return null;
    }

    _logger.info('Fetching license from $endpoint');

    final dio = Dio();
    dio.options.headers['Authorization'] = 'Bearer $authToken';

    final metaData = Platform.environment['KYBER_SERVER_META'];
    final regionId = switch (metaData) {
      final String m when m.isNotEmpty => '?region=${_getServerRegion()}',
      _ => '',
    };

    try {
      final response = await dio.get<List<int>>(
        '$endpoint/$id$regionId',
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final licenseData = response.data!;

        if (!isFile) {
          final licenseString = utf8.decode(licenseData);
          _logger.success('License fetched successfully');
          return licenseString;
        }

        const licensePath =
            '~/.local/share/maxima/wine/prefix/drive_c/ProgramData/Electronic Arts/EA Services/License/1035052.dlf';
        File(licensePath.replaceFirst('~', Platform.environment['HOME']!))
          ..createSync(recursive: true)
          ..writeAsBytesSync(licenseData);
        _logger.success('License fetched and saved to $licensePath');
      } else {
        _logger.err(
          'Failed to fetch license: ${response.statusCode} ${response.statusMessage}',
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _logger.err('License not found on server');
        return null;
      }

      rethrow;
    } catch (e) {
      _logger.err('Error fetching license: $e');
    }
  }

  Future<void> _uploadLicense({required String id, String? data}) async {
    final endpoint = Platform.environment['KYBER_LICENSE_ENDPOINT'];
    final authToken = Platform.environment['KYBER_LICENSE_AUTH_TOKEN'];
    if (endpoint == null || authToken == null) {
      return;
    }

    _logger.info('Uploading Denuvo token to license server...');

    final dio = Dio();
    dio.options.headers['Authorization'] = 'Bearer $authToken';

    final licenseData = switch (data) {
      final String d when d.isNotEmpty => utf8.encode(d),
      _ => () {
        if (!Platform.isLinux) {
          return [];
        }

        const licensePath =
            '~/.local/share/maxima/wine/prefix/drive_c/ProgramData/Electronic Arts/EA Services/License/1035052.dlf';
        final licenseFile = File(
          licensePath.replaceFirst('~', Platform.environment['HOME']!),
        );
        if (!licenseFile.existsSync()) {
          throw Exception('License file not found at $licensePath');
        }

        return licenseFile.readAsBytesSync();
      }(),
    };

    if (licenseData.isEmpty) {
      _logger.err('No license data to upload');
      return;
    }

    final metaData = Platform.environment['KYBER_SERVER_META'];
    final regionId = switch (metaData) {
      final String m when m.isNotEmpty => '?region=${_getServerRegion()}',
      _ => '',
    };
    try {
      final response = await dio.put(
        '$endpoint/$id$regionId',
        data: licenseData,
        options: Options(
          headers: {
            Headers.contentTypeHeader: 'application/octet-stream',
            Headers.contentLengthHeader: licenseData.length,
          },
        ),
      );

      if (response.statusCode == 200) {
        _logger.success('License uploaded successfully');
      } else {
        _logger.err(
          'Failed to upload license: ${response.statusCode} ${response.statusMessage}',
        );
      }
    } catch (e) {
      _logger.err('Error uploading license: $e');
    }
  }

  String _getServerRegion() {
    final metaData = Platform.environment['KYBER_SERVER_METADATA'];
    if (metaData == null || metaData.isEmpty) {
      return 'unknown';
    }

    try {
      final data = metaData.split(',').map((e) => MapEntry(e.split('=').first, e.split('=').last));
      final map = Map<String, String>.fromEntries(data);

      return map['pinned_proxy_id'] ?? 'unknown';
    } catch (e) {
      return 'unknown';
    }
  }

  int _stableStringHash(String s) {
    var hash = 0;

    for (final codeUnit in s.codeUnits) {
      hash = 31 * hash + codeUnit;
    }

    return hash & 0x7fffffff;
  }
}
