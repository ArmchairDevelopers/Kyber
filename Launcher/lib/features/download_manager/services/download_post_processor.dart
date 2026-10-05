import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:kyber_launcher/features/download_manager/services/archive_extractor.dart';
import 'package:kyber_launcher/features/download_manager/services/platform/download_platform_integration.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class DownloadPostProcessor {
  DownloadPostProcessor({
    DownloadPlatformIntegration? platformIntegration,
  }) : _platformIntegration = platformIntegration;

  final DownloadPlatformIntegration? _platformIntegration;
  final Logger _logger = Logger('download_post_processor');

  Future<void> processCompletedDownload(
    TaskStatusUpdate update, {
    ProgressCallback? onProgress,
  }) async {
    if (update.status != TaskStatus.complete) {
      return;
    }

    try {
      _logger.info('Processing completed download: ${update.task.filename}');

      await _platformIntegration?.setIndeterminate();

      final extractor = ArchiveExtractor(basePath: update.task.directory);
      var filename = update.task.filename;

      if (!extractor.isArchive(filename)) {
        final foundExtension = await extractor.findArchiveExtension(filename);
        if (foundExtension == null) {
          _logger.info('File is not an archive, skipping extraction');
          return;
        }

        final renamedFile = '$filename$foundExtension';

        _logger.info(
          'Detected $foundExtension archive from file header, '
          'renaming to $renamedFile',
        );
        await File(
          join(update.task.directory, filename),
        ).rename(join(update.task.directory, renamedFile));
        filename = renamedFile;
      }

      _logger.info('Extracting archive: $filename');
      final result = await extractor.extract(
        filename,
        onProgress: onProgress,
      );

      if (!result.success) {
        _logger.warning('Extraction failed: ${result.error}');
        return;
      }

      _logger.info('Extraction successful');
    } catch (e, s) {
      _logger.severe('Failed to process completed download', e, s);
    } finally {
      await _platformIntegration?.clear();
    }
  }
}
