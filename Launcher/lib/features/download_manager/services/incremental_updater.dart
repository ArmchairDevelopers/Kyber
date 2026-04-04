import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/gen/rust/api/downloader.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:slugify/slugify.dart';

class IncrementalUpdater {
  final _logger = Logger('incremental_updater');

  // only a poc for now
  void updateMod({required String downloadUrl}) async {
    await sl.isReady<ModService>();

    final tmpDir = await getTemporaryDirectory();

    var entries = <ZipEntryInfo>[];
    final installed = <FrostyMod>[];
    final missing = <(String, String)>[];
    FrostyMod? collection;
    ZipEntryInfo? collectionEntry;
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
        print('No collection found in the mod package');
        return;
      }

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
        return;
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

      entries = entries
          .where((entry) => extension(entry.name).endsWith('.fbmod'))
          .toList();
    } finally {
      await downloaderDispose(d: d);
    }

    if (missing.length == entries.length - 1) {
      print('All mods are missing');
      return;
    }

    final random = String.fromCharCodes(
      List.generate(8, (index) => Random().nextInt(26) + 97),
    );

    final newDir = join(
      ModService.getBasePath(),
      slugify(
        '${collection.details.name} ${collection.details.version} $random',
      ),
    );

    d = await downloaderCreate(
      id: '1',
      zipUrl: downloadUrl,
      outputDir: join(ModService.getBasePath(), ''),
    );

    print(
      'Missing mods for collection ${collection.details.name} (${collection.details.version}): ${missing.length}',
    );

    final totalZipSize = entries.fold<int>(
      0,
          (previousValue, element) => previousValue + element.compressedSize,
    );
    final missingSize = entries
        .where(
          (entry) => missing.where((mod) => mod.$1 == entry.name).isNotEmpty,
    )
        .fold<int>(
      0,
          (previousValue, element) => previousValue + element.compressedSize,
    );
    print(
      'Total zip size: ${totalZipSize / 1024 / 1024 / 1024} GB, missing mods size: ${missingSize / 1024 / 1024 / 1024} GB',
    );

    print('Copying existing mods to $newDir');
    await Directory(newDir).create(recursive: true);

    for (final mod in installed) {
      final newPath = join(newDir, basename(mod.filename));
      print('Copying ${basename(mod.filename)} to $newPath');
      await File(join(ModService.getBasePath(), mod.filename)).copy(newPath);
    }

    try {
      for (final mod in missing) {
        print('Downloading missing mod ${mod.$1}');
        await downloaderDownloadEntryByName(d: d, entryName: mod.$1);
        final downloadedPath = join(
          ModService.getBasePath(),
          basename(mod.$1),
        );
        final newPath = join(newDir, basename(mod.$1));
        await File(downloadedPath).rename(newPath);
      }
    } finally {
      await downloaderDispose(d: d);
    }

    final collectionFilePath = join(newDir, basename(collectionEntry!.name));
    print('Copying collection file to $collectionFilePath');
    await File(
      join(tmpDir.path, collectionEntry.name),
    ).copy(collectionFilePath);

    print('All mods for collection are now in $newDir');
  }
}