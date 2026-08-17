import 'dart:io';
import 'dart:isolate';

import 'package:kyber_launcher/core/services/unrar_service.dart';
import 'package:path/path.dart';
import 'package:win32_registry/win32_registry.dart';

class UnzipHelper {
  static Future<void> unrar(
    File file,
    Directory to, {
    void Function(int extractedFilesCount, int totalFiles)? onProgress,
  }) async {
    if (file.path.endsWith('.rar')) {
      final rarFilePath = file.path;
      final outputDirectory = to.path;
      final receiver = ReceivePort()
        ..listen((message) {
          if (message is Map<String, int> && onProgress != null) {
            final extracted = message['extracted'] ?? 0;
            final total = message['total'] ?? 0;
            onProgress(extracted, total);
          }
        });
      final sendPort = receiver.sendPort;
      await Isolate.run(() async {
        extractRar(rarFilePath, outputDirectory, sendPort: sendPort);
      });
      receiver.close();
    } else {
      final currentDir = dirname(Platform.resolvedExecutable);
      final za = join(currentDir, '7za.exe');
      final result = await Process.run(za, [
        'e',
        file.path,
        '-y',
        '-o${to.path}',
      ]);
      if (result.exitCode != 0) {
        throw Exception(
          'Failed to extract file: ${result.stderr.toString().trim()}',
        );
      }
    }
  }

  static String? getExecutable() {
    final software = LOCAL_MACHINE.open('SOFTWARE');
    try {
      final subkeys = software.keys;

      if (subkeys.contains('WinRAR')) {
        return software.getString('exe64', path: 'WinRAR');
      }

      if (subkeys.contains('7-Zip')) {
        final path = software.getString('Path64', path: '7-Zip');
        return path == null ? null : '$path\\7z.exe';
      }

      return null;
    } finally {
      software.close();
    }
  }
}
