import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/unzip_helper.dart';
import 'package:kyber_launcher/features/download_manager/models/extraction_result.dart';
import 'package:kyber_launcher/gen/rust/api/archive.dart' as rust_archive;
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:slugify/slugify.dart';
import 'package:uuid/uuid.dart';

typedef ProgressCallback = void Function(int current, int total);

class ArchiveExtractor {
  const ArchiveExtractor({required this.basePath});

  final String basePath;
  static final Logger _logger = Logger.detached('archive_extractor');

  bool isArchive(String filename) {
    const archiveExtensions = ['.zip', '.rar', '.7z'];
    return archiveExtensions.contains(extension(filename));
  }

  Future<ExtractionResult> extract(
    String filename, {
    bool deleteSource = true,
    ProgressCallback? onProgress,
  }) async {
    try {
      if (!isArchive(filename)) {
        return const ExtractionResult(
          success: false,
          extractedFiles: [],
          error: 'File is not a supported archive format',
        );
      }

      final tmpDir = await _extractToTemp(
        filename,
        deleteSource: deleteSource,
        onProgress: onProgress,
      );

      final files = Directory(tmpDir)
          .listSync(recursive: true)
          .whereType<File>();
      final isFrostyCollection = files.any(
        (e) => e.path.endsWith('.fbcollection'),
      );

      if (isFrostyCollection) {
        return await _handleFrostyCollection(tmpDir, files);
      } else {
        return await _handleRegularMods(tmpDir, files);
      }
    } catch (e, s) {
      String errorMessage;
      if (e is AnyhowException) {
        errorMessage = e.message;
      } else {
        errorMessage = 'An error occurred while unpacking the archive: $e';
      }

      _logger.severe('Could not extract $filename', e, s);
      return ExtractionResult(
        success: false,
        extractedFiles: [],
        error: errorMessage,
      );
    }
  }

  Future<String> _extractToTemp(
    String filename, {
    bool deleteSource = true,
    ProgressCallback? onProgress,
  }) async {
    final tmpDir = join(basePath, const Uuid().v4());
    await Directory(tmpDir).create();

    final filePath = join(basePath, filename);

    if (filename.endsWith('.zip')) {
      final completer = Completer<void>();
      final stream =
          rust_archive
              .extractStream(filePath: filePath, targetDir: tmpDir)
              .asBroadcastStream()
            ..listen((event) {
              if (event.$2 == event.$1) {
                completer.complete();
              }

              onProgress?.call(event.$1, event.$2);
            });

      await stream.last;

      await Future<void>.delayed(const Duration(milliseconds: 500));
    } else {
      await Future<void>.delayed(const Duration(seconds: 1));
      await UnzipHelper.unrar(
        File(filePath),
        Directory(tmpDir),
        onProgress: onProgress,
      );
    }

    if (deleteSource) {
      await File(filePath).delete();
    }

    return tmpDir;
  }

  Future<ExtractionResult> _handleFrostyCollection(
    String tmpDir,
    Iterable<File> files,
  ) async {
    try {
      final collectionFile = files.firstWhere(
        (e) => e.path.endsWith('.fbcollection'),
      );

      final collection = FrostyCollectionReader(
        collectionFile.openSync(),
        collectionFile.path,
      ).readMod();

      final random = String.fromCharCodes(
        List.generate(8, (index) => Random().nextInt(26) + 97),
      );

      final newDir = join(
        basePath,
        slugify(
          '${collection?.details.name} ${collection?.details.version} $random',
        ),
      );

      _logger.info('Extracting Frosty Collection to $newDir');
      Directory(tmpDir).renameSync(newDir);

      final pluginsInstalled = await _extractPlugins(newDir);

      return ExtractionResult(
        success: true,
        extractedFiles: [newDir],
        isFrostyCollection: true,
        pluginsInstalled: pluginsInstalled,
      );
    } catch (e, s) {
      _logger.severe('Failed to handle Frosty Collection', e, s);
      return ExtractionResult(
        success: false,
        extractedFiles: [],
        error: 'Failed to process Frosty Collection: $e',
        isFrostyCollection: true,
      );
    }
  }

  Future<ExtractionResult> _handleRegularMods(
    String tmpDir,
    Iterable<File> files,
  ) async {
    try {
      final mainDirFiles = Directory(basePath).listSync();
      final extractedFiles = <String>[];

      final fileNames = <String>{};
      final fileMappings = <File, String>{};

      for (final file in files) {
        final fileName = basename(file.path);

        if (fileNames.contains(fileName)) {
          final uuid = const Uuid().v4();
          final nameWithoutExt = basenameWithoutExtension(fileName);
          final ext = extension(fileName);

          fileMappings[file] = '${nameWithoutExt}_$uuid$ext';
        } else {
          fileNames.add(fileName);
        }
      }

      for (final file in files) {
        final outName = fileMappings[file] ?? basename(file.path);

        final existingMod = mainDirFiles.firstWhereOrNull(
          (e) => basename(e.path) == outName,
        );

        if (existingMod != null && extension(file.path) != '.dll') {
          _logger.info(
            'File ${existingMod.path} already exists, skipping ${file.path}',
          );
          continue;
        } else if (existingMod != null && extension(file.path) == '.dll') {
          await existingMod.delete();
          final newPath = join(basePath, outName);
          await file.rename(newPath);
          extractedFiles.add(newPath);
        } else {
          final newPath = join(basePath, outName);
          await file.rename(newPath);
          extractedFiles.add(newPath);
        }
      }

      try {
        await Directory(tmpDir).delete(recursive: true);
      } catch (e) {
        _logger.warning('Failed to delete temp directory: $e');
      }

      final pluginsInstalled = await _extractPlugins(basePath);

      return ExtractionResult(
        success: true,
        extractedFiles: extractedFiles,
        pluginsInstalled: pluginsInstalled,
      );
    } catch (e, s) {
      _logger.severe('Failed to handle regular mod extraction', e, s);
      return ExtractionResult(
        success: false,
        extractedFiles: [],
        error: 'Failed to extract mods: $e',
      );
    }
  }

  Future<int> _extractPlugins(String searchPath) async {
    try {
      final launcherDir = FileHelper.getLauncherDirectory().path;
      final now = DateTime.now().subtract(const Duration(seconds: 10));

      final pluginFiles = Directory(searchPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((element) {
            if (!element.path.endsWith('.dll')) {
              return false;
            }

            final stat = element.statSync();
            return stat.modified.isAfter(now) || stat.changed.isAfter(now);
          })
          .toList();

      if (pluginFiles.isEmpty) {
        return 0;
      }

      var installed = 0;
      for (final file in pluginFiles) {
        final dest = '$launcherDir\\Plugins\\${basename(file.path)}';

        if (File(dest).existsSync()) {
          await File(dest).delete();
        }

        await file.copy(dest);
        await file.delete();
        installed++;
        _logger.info('Installed plugin: ${basename(file.path)}');
      }

      return installed;
    } catch (e, s) {
      _logger.warning('Failed to extract plugins', e, s);
      return 0;
    }
  }
}
