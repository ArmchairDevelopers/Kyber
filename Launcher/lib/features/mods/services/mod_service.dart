import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/mods/constants/categories.dart';
import 'package:kyber_launcher/features/mods/services/level_declaration_service.dart';
import 'package:kyber_launcher/features/mods/services/mod_manifest_backfill_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:stream_transform/stream_transform.dart';

class ModService with ChangeNotifier {
  ModService({List<FrostyMod>? mods, List<FrostyMod>? hiddenMods}) {
    _mods = mods ?? [];
    _hiddenMods = hiddenMods ?? [];

    if (mods != null) {
      refreshCompleter.complete();
    }

    if (Preferences.general.setup) {
      watchDirectory();
    }
  }

  static final Logger _logger = Logger('mod_service');

  late List<FrostyMod> _hiddenMods;
  late List<FrostyMod> _mods;

  Completer<void> refreshCompleter = Completer();
  Completer<void> _enqueueCompleter = Completer();

  StreamSubscription<Object?>? _modFileSubscription;

  List<FrostyMod> get mods => List.unmodifiable(_mods);

  List<FrostyMod> get hiddenMods => List.unmodifiable(_hiddenMods);

  bool _paused = false;
  bool _enqueuedRefresh = false;

  static Future<void> setBasePath(String path) async {
    Preferences.general.modsPath = path;
    if (sl.isReadySync<ModService>()) {
      sl.get<ModService>().refresh();
      sl.get<ModService>().watchDirectory();
    }
  }

  void setPaused(bool paused) {
    _paused = paused;
  }

  static String getBasePath() => Preferences.general.modsPath;

  static Directory getBasePathAsDir() =>
      Directory(Preferences.general.modsPath);

  /// Path to the shared mod manifest that maps installed mod filenames to
  /// their NexusMods IDs and metadata.
  static String get manifestPath =>
      join(getBasePath(), 'nexus_mod_manifest.json');

  /// Reads the mod manifest and returns it as a decoded map, or an empty map
  /// if the file doesn't exist or is malformed.
  static Future<Map<String, dynamic>> readManifest() async {
    try {
      final file = File(manifestPath);
      if (!await file.exists()) return <String, dynamic>{};
      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  /// Reads the [section] from the manifest (e.g. 'files' or 'mods'),
  /// returning an empty map if the section is missing or the manifest
  /// can't be read.
  static Future<Map<String, dynamic>> readManifestSection(
    String section,
  ) async {
    final manifest = await readManifest();
    return (manifest[section] as Map<String, dynamic>?) ?? <String, dynamic>{};
  }

  /// Writes the full manifest to disk. Merging/updating individual entries
  /// is the caller's responsibility.
  static Future<void> writeManifest(Map<String, dynamic> manifest) async {
    try {
      await File(manifestPath).writeAsString(jsonEncode(manifest));
    } catch (e) {
      _logger.warning('Failed to write mod manifest: $e');
    }
  }

  @override
  void dispose() {
    _modFileSubscription?.cancel();
    super.dispose();
  }

  Map<String, List<FrostyMod>> filterByCategory([List<FrostyMod>? mods]) {
    final modsByCategory = <String, List<FrostyMod>>{};
    for (final mod in mods ?? this.mods) {
      if (!modsByCategory.containsKey(mod.details.category)) {
        modsByCategory[mod.details.category] = [];
      }

      modsByCategory[mod.details.category]!.add(mod);
    }

    return modsByCategory;
  }

  Future<void> refresh({bool enqueue = false}) async {
    if (!refreshCompleter.isCompleted) {
      if (_enqueuedRefresh) {
        _logger.info('Refresh already enqueued, skipping');
        return _enqueueCompleter.future;
      }

      if (!enqueue) {
        _logger.info('Refresh already in progress, waiting for completion');

        if (_enqueuedRefresh) {
          return _enqueueCompleter.future;
        }

        await refreshCompleter.future;
        _enqueueCompleter = Completer();

        _enqueuedRefresh = true;

        final future = refresh(enqueue: true).then((_) {
          if (!_enqueueCompleter.isCompleted) {
            _enqueueCompleter.complete();
            _enqueuedRefresh = false;
          }
        });

        return future;
      }

      await refreshCompleter.future;
    }

    _logger.info('Refreshing mods');

    refreshCompleter = Completer<void>();

    final dir = ModService.getBasePathAsDir();
    if (!dir.existsSync()) {
      await setBasePath(FileHelper.getModsDirectory().path);
      NotificationService.error(message: 'Resetting mods directory...');
    }

    final x = await Future.wait([_loadMods(), _loadCollections()]);
    _mods = [
      ...x[0].where((e) => !extension(e.filename, 2).contains('.bsm')),
      ...x[1],
    ];
    _hiddenMods = x[0]
        .where((e) => extension(e.filename, 2).contains('.bsm'))
        .toList();

    if (!refreshCompleter.isCompleted) {
      refreshCompleter.complete();
    }

    notifyListeners();

    // Fire-and-forget manifest backfill for pre-existing mods
    _logger.info('Triggering manifest backfill for ${_mods.length} mods');
    ModManifestBackfillService.backfillAll(_mods);
  }

  void watchDirectory() {
    try {
      final dir = getBasePathAsDir();
      if (!dir.existsSync()) {
        _logger.warning('Cannot watch directory, it does not exist');
        return;
      }

      if (_modFileSubscription != null) {
        _logger.warning('Cancelling previous file subscription');
        _modFileSubscription?.cancel();
      }

      _logger.info('Watching directory for changes');
      _modFileSubscription =
          StreamTransformer.fromBind(
            (s) => s.debounce(const Duration(seconds: 2)),
          ).bind(dir.watch()).listen((event) {
            if (event is FileSystemCreateEvent &&
                    event.path.contains('com.bbflight.background_downloader') ||
                event is FileSystemModifyEvent &&
                    event.path.contains('com.bbflight.background_downloader') ||
                event is FileSystemDeleteEvent &&
                    event.path.contains('com.bbflight.background_downloader')) {
              return;
            }

            if (_paused) {
              return;
            }

            _logger.fine('Detected file system event: $event');
            refresh();
          });
    } catch (e, s) {
      _logger.severe('Failed to watch directory:', e, s);
      Sentry.captureException(e, stackTrace: s);
      NotificationService.error(message: 'Failed to watch mods directory');
    }
  }

  Future<bool> hasDuplicates() async {
    final uniqueMods = mods.toSet();
    if (uniqueMods.length == mods.length) {
      return true;
    }

    return false;
  }

  Future<List<FrostyMod>> getDuplicates() async {
    final uniqueMods = mods.toSet();
    return mods.where((element) => !uniqueMods.contains(element)).toList();
  }

  static Future<ModService> getInstance([Directory? baseDir]) async {
    if (!Preferences.general.setup) {
      return ModService(mods: [], hiddenMods: []);
    }

    if (!FileHelper.getModsDirectory().existsSync()) {
      await FileHelper.getModsDirectory().create(recursive: true);
    }

    final dir = baseDir ?? ModService.getBasePathAsDir();
    if (!dir.existsSync()) {
      await setBasePath(FileHelper.getModsDirectory().path);
      NotificationService.error(message: 'Resetting mods directory...');
    }

    final time = DateTime.now();
    final x = await Future.wait([
      _loadMods(baseDir),
      _loadCollections(baseDir),
    ]);
    final mods = x[0]
        .where((e) => !extension(e.filename, 2).contains('.bsm'))
        .toList();
    final hiddenMods = x[0]
        .where((e) => extension(e.filename, 2).contains('.bsm'))
        .toList();
    final collections = x[1];

    final loadTime = DateTime.now().difference(time).inMilliseconds;
    _logger.info('Loaded ${mods.length} mods in $loadTime ms');

    mods.addAll(collections);

    return ModService(mods: mods, hiddenMods: hiddenMods);
  }

  static Future<List<FrostyMod>> _loadMods([Directory? baseDir]) async {
    baseDir ??= getBasePathAsDir();
    final entities = await baseDir
        .list(recursive: true)
        .whereType<File>()
        .toList();

    const cores = 2;
    final chunkSize = (entities.length / cores).ceil();

    final chunks = <List<String>>[];
    for (var i = 0; i < entities.length; i += chunkSize) {
      chunks.add(
        entities
            .sublist(
              i,
              i + chunkSize > entities.length ? entities.length : i + chunkSize,
            )
            .map((e) => e.path)
            .toList(),
      );
    }

    _logger.info('Loading mods in $cores chunks');

    final results = await Future.wait(
      List.generate(
        chunks.length,
        (i) => compute(_loadModsI, [baseDir!.path, chunks[i]]),
      ),
    );
    final mods = results.expand((element) => element).toList();

    final stopwatch = Stopwatch()..start();
    final modEntries = <String, ModEntry>{};
    for (final mod in mods.where(
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

      modEntries[mod.filename] = ModEntry(
        maps,
        modes,
        mod.customFrostyData!.modeMappings ?? {},
        mod.customFrostyData!.modeNameOverrides ?? {},
      );
    }

    sl.get<LevelDeclarationService>().set(modEntries);
    stopwatch.stop();
    _logger.info(
      'Loaded ${modEntries.length} mods with custom level data in ${stopwatch.elapsedMilliseconds} ms',
    );

    return mods;
  }

  static Future<List<FrostyMod>> _loadCollections([Directory? baseDir]) async {
    final entities = await (baseDir ?? getBasePathAsDir())
        .list(recursive: true)
        .where((e) => e is File && e.path.endsWith('.fbcollection'))
        .toList();
    return compute(
      _loadCollectionsI,
      [
        (baseDir ?? getBasePathAsDir()).path,
        entities.map((e) => e.path).toList(),
      ],
    );
  }
}

Future<List<FrostyMod>> _loadCollectionsI(List<dynamic> args) async {
  final loadedCollections = <FrostyMod>[];
  final y = List<String>.from(
    args[1] as List<String>,
  ).where((x) => x.endsWith('.fbcollection')).toList();
  await Future.forEach(y, (String element) async {
    try {
      final file = await File(element).open();
      final mod = FrostyCollectionReader(
        file,
        relative(element, from: args[0] as String),
      ).readMod();
      if (mod != null) {
        loadedCollections.add(mod);
      }
    } catch (e) {
      Logger.root.warning('Failed to load mod: $e');
    }
  });
  return loadedCollections;
}

Future<List<FrostyMod>> _loadModsI(List<dynamic> args) async {
  final loadedMods = <FrostyMod>[];
  final y = List<String>.from(
    args[1] as List<String>,
  ).where((x) => x.endsWith('.fbmod')).toList();

  await Future.forEach(y, (String x) async {
    try {
      final file = await File(x).open();
      final mod = ModReader(
        file,
        relative(x, from: args[0] as String),
      ).readMod();
      if (mod != null) {
        loadedMods.add(mod);
      }
    } catch (e) {
      Logger.root.warning('Failed to load mod: $e');
    }
  });

  return loadedMods;
}
