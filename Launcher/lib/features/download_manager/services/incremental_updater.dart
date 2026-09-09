import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:collection/collection.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/gen/rust/api/downloader.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slugify/slugify.dart';

const _kAllowedHosts = [
  'kyber.gg',
  'nexusmods.com',
];

class IncrementalUpdater {
  final _logger = Logger('incremental_updater');

  Future<bool> checkEligibility(String downloadUrl) async {
    final uri = Uri.parse(downloadUrl);

    if (!_kAllowedHosts.any((host) => uri.host.endsWith(host))) {
      return false;
    }

    await sl.isReady<ModService>();

    final tmpDir = await getTemporaryDirectory();

    try {
      var entries = <ZipEntryInfo>[];
      final installed = <FrostyMod>[];
      final missing = <(String, String)>[];
      FrostyMod? collection;
      String? tempCollectionPath;

      DownloaderHandle? d;
      try {
        _logger.fine(
          'Checking incremental update eligibility for $downloadUrl',
        );

        d = await downloaderCreate(
          id: 'check-${DateTime.now().millisecondsSinceEpoch}',
          zipUrl: downloadUrl,
          outputDir: tmpDir.path,
        );

        _logger.fine('Fetching mod collection entries for eligibility check');
        entries = await downloaderListEntries(d: d);

        final collectionEntry = entries.firstWhereOrNull(
          (entry) => extension(entry.name) == '.fbcollection',
        );

        if (collectionEntry == null) {
          return false;
        }

        _logger.fine('Downloading collection manifest for eligibility check');
        await downloaderDownloadEntryByName(
          d: d,
          entryName: collectionEntry.name,
        );

        tempCollectionPath = join(tmpDir.path, collectionEntry.name);
        final file = File(tempCollectionPath).openSync();
        collection = FrostyCollectionReader(
          file,
          collectionEntry.name,
        ).readMod();

        if (collection == null) {
          return false;
        }

        final installedMods = sl.get<ModService>().mods;
        for (final mod in collection.mods!) {
          final index = collection.mods!.indexOf(mod);
          final modVersion = collection.modVersions![index];
          final installedMod = installedMods
              .where((m) => basename(m.filename) == mod)
              .where((m) => m.details.version == modVersion)
              .firstOrNull;

          if (installedMod == null) {
            missing.add((mod, modVersion));
          } else {
            installed.add(installedMod);
          }
        }
      } finally {
        if (d != null) await downloaderDispose(d: d);
        if (tempCollectionPath != null) {
          try {
            await File(tempCollectionPath).delete();
          } catch (_) {}
        }
      }

      if (missing.length == collection.mods?.length) {
        return false;
      }

      return true;
    } catch (e, s) {
      _logger.warning('Eligibility check failed', e, s);
      return false;
    }
  }

  Future<bool> update({
    required String downloadUrl,
    void Function(UpdatePhase phase)? onPhaseChanged,
    void Function(int current, int total)? onProgress,
    void Function(int bytesDownloaded, int totalBytes)? onDownloadProgress,
    CallbackTaskController? controller,
  }) async {
    final uri = Uri.parse(downloadUrl);

    if (!_kAllowedHosts.any((host) => uri.host.endsWith(host))) {
      _logger.warning(
        'Rejected download from unallowed domain: ${uri.host}',
      );
      return false;
    }

    await sl.isReady<ModService>();

    final rndStr = String.fromCharCodes(
      List.generate(8, (index) => Random().nextInt(26) + 97),
    );
    final tmpDir = Directory(join(ModService.getBasePath(), '_tmp_$rndStr'));

    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }

    await tmpDir.create(recursive: true);

    String? newDir;

    try {
      controller?.throwIfCancelled();
      onPhaseChanged?.call(.fetchingEntries);

      onProgress?.call(1, 1);

      var entries = <ZipEntryInfo>[];
      final installed = <FrostyMod>[];
      final missing = <(String, String)>[];
      FrostyMod? collection;
      ZipEntryInfo? collectionEntry;

      _logger.info('Fetching mod collection entries from $downloadUrl');

      late DownloaderHandle d;
      try {
        d = await downloaderCreate(
          id: '0',
          zipUrl: downloadUrl,
          outputDir: tmpDir.path,
        );
        entries = await downloaderListEntries(d: d);

        collectionEntry = entries.firstWhereOrNull(
          (entry) => extension(entry.name) == '.fbcollection',
        );

        if (collectionEntry == null) {
          _logger.warning('No .fbcollection found in the mod package');
          return false;
        }

        controller?.throwIfCancelled();
        onPhaseChanged?.call(.parsingCollection);

        await downloaderDownloadEntryByName(
          d: d,
          entryName: collectionEntry.name,
        );

        final file = File(join(tmpDir.path, collectionEntry.name)).openSync();
        collection = FrostyCollectionReader(
          file,
          collectionEntry.name,
        ).readMod();

        if (collection == null) {
          _logger.warning('Failed to parse collection manifest');
          return false;
        }

        controller?.throwIfCancelled();
        onPhaseChanged?.call(.comparingMods);

        final installedMods = sl.get<ModService>().mods;
        for (final mod in collection.mods!) {
          final index = collection.mods!.indexOf(mod);
          final modVersion = collection.modVersions![index];
          final installedMod = installedMods
              .where((m) => basename(m.filename) == mod)
              .where((m) => m.details.version == modVersion)
              .firstOrNull;

          if (installedMod == null) {
            missing.add((mod, modVersion));
          } else {
            installed.add(installedMod);
          }
        }

        entries = entries
            .where((entry) => extension(entry.name).endsWith('.fbmod'))
            .toList();
      } finally {
        await downloaderDispose(d: d);
      }

      if (missing.length == entries.length) {
        _logger.info('All mods are missing, incremental update not beneficial');
        return false;
      }

      final missingSize = entries
          .where(
            (entry) => missing.where((mod) => mod.$1 == entry.name).isNotEmpty,
          )
          .fold<int>(0, (sum, e) => sum + e.compressedSize);

      controller?.throwIfCancelled();
      onPhaseChanged?.call(.copyingExistingMods);

      final random = String.fromCharCodes(
        List.generate(8, (index) => Random().nextInt(26) + 97),
      );

      newDir = join(
        ModService.getBasePath(),
        slugify(
          '${collection.details.name} ${collection.details.version} $random',
        ),
      );

      _logger.info('Creating collection in $newDir');
      await Directory(newDir).create(recursive: true);

      controller?.throwIfCancelled();
      onPhaseChanged?.call(.downloadingMissingMods);

      d = await downloaderCreate(
        id: '1',
        zipUrl: downloadUrl,
        outputDir: tmpDir.path,
      );

      final total = missingSize;
      var current = 0;

      _logger.info(
        'Starting download of ${missing.length} missing mods (${_formatBytes(total)})',
      );

      try {
        for (var i = 0; i < missing.length; i++) {
          controller?.throwIfCancelled();
          final mod = missing[i];
          final entryInfo = entries.firstWhereOrNull(
            (e) => e.name == mod.$1,
          );
          _logger.fine(
            'Downloading ${basename(mod.$1)} (${_formatBytes(entryInfo?.compressedSize ?? 0)})',
          );
          final streamSink = RustStreamSink<int>();

          final future = downloaderDownloadEntryByName(
            d: d,
            entryName: mod.$1,
            progress: streamSink,
          );

          streamSink.stream.listen((bytes) async {
            if (controller?.isCancelled ?? false) {
              await downloaderCancel(d: d);
              return;
            }

            current += bytes;
            onDownloadProgress?.call(current, total);
          });

          await future;

          final downloadedPath = join(
            tmpDir.path,
            basename(mod.$1),
          );
          final destPath = join(newDir, basename(mod.$1));
          await File(downloadedPath).rename(destPath);
        }
      } catch (e, s) {
        if (e == 'cancelled') {
          throw const CancelledException();
        } else {
          _logger.severe('Failed to download missing mods', e, s);
          rethrow;
        }
      } finally {
        await downloaderDispose(d: d);
      }

      onDownloadProgress?.call(total, total);

      _logger.info('All missing mods downloaded, copying existing mods');

      for (var i = 0; i < installed.length; i++) {
        controller?.throwIfCancelled();
        final mod = installed[i];
        onProgress?.call(i + 1, installed.length);

        final newPath = join(newDir, basename(mod.filename));
        _logger.fine('Copying ${basename(mod.filename)}');
        await File(join(ModService.getBasePath(), mod.filename)).copy(newPath);
      }

      onPhaseChanged?.call(.finalizing);

      onProgress?.call(1, 1);

      final collectionFilePath = join(
        newDir,
        basename(collectionEntry.name),
      );
      _logger.fine('Copying collection manifest to $collectionFilePath');

      final tempCollectionFile = File(
        join(tmpDir.path, collectionEntry.name),
      );
      await tempCollectionFile.copy(collectionFilePath);

      return true;
    } on CancelledException {
      _logger.info('Incremental update cancelled');

      if (newDir != null) {
        try {
          await Directory(newDir).delete(recursive: true);
        } catch (_) {
          _logger.warning(
            'Failed to clean up partial output directory: $newDir',
          );
        }
      }

      rethrow;
    } catch (e, s) {
      _logger.severe('Incremental update failed', e, s);

      if (newDir != null) {
        try {
          await Directory(newDir).delete(recursive: true);
        } catch (_) {
          _logger.warning(
            'Failed to clean up partial output directory: $newDir',
          );
        }
      }

      return false;
    } finally {
      try {
        tmpDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }
}

enum UpdatePhase {
  fetchingEntries,
  parsingCollection,
  comparingMods,
  copyingExistingMods,
  downloadingMissingMods,
  finalizing,
}
