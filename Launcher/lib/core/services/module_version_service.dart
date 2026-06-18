import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/gen/rust/api/archive.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rhttp/rhttp.dart';
import 'package:win32/win32.dart';
import 'package:win32_registry/win32_registry.dart';

const _launcherInstallerKey =
    r'SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\KyberLauncher_is1';

enum VersionModule {
  //launcher,
  module,
  installer,
}

extension VersionModuleExtension on VersionModule {
  Future<String?> getCurrentVersion() async {
    switch (this) {
      case VersionModule.module:
        final x = File(join(FileHelper.getModuleDirectory().path, 'VERSION'));

        if (!x.existsSync()) {
          return null;
        }

        return x.readAsStringSync();
      case VersionModule.installer:
        final info = await PackageInfo.fromPlatform();

        return '${info.version}+${info.buildNumber}';
    }
  }

  Future<String> getDownloadDir() async {
    switch (this) {
      case VersionModule.installer:
        final tmpDir = await getTemporaryDirectory();

        return join(
          tmpDir.path,
          'kyber_launcher_${DateTime.now().millisecondsSinceEpoch}',
        );
      case VersionModule.module:
        return FileHelper.getModuleDirectory().path;
    }
  }

  Future<void> setReleaseChannel(String channel) async {
    await box.put('${name}_release_channel', channel);
  }

  String get releaseChannel {
    return box.get('${name}_release_channel') as String? ?? 'stable';
  }

  List<String> get requiredFiles {
    switch (this) {
      case VersionModule.installer:
        return [];
      case VersionModule.module:
        final modulePath = FileHelper.getModuleDirectory().path;
        return [
          '$modulePath/vivoxsdk.dll',
          '$modulePath/VanillaBundleAggregation.kb',
          '$modulePath/Kyber.dll',
        ];
    }
  }

  String get name {
    switch (this) {
      case VersionModule.installer:
        return 'kyber-installer-win64';
      case VersionModule.module:
        return 'kyber-module';
    }
  }
}

class ModuleVersionService {
  final _logger = Logger('version_service');

  bool isStandalone() {
    // TODO: find a fix for this
    return false;
    RegistryKey? key;
    try {
      key = Registry.openPath(
        RegistryHive.localMachine,
        path: _launcherInstallerKey,
      );

      final installationPath = key.getStringValue('InstallLocation');
      if (installationPath == null) {
        return true;
      }

      return normalize(installationPath) !=
          dirname(Platform.resolvedExecutable);
    } on WindowsException catch (_) {
      return true;
    } catch (e) {
      _logger.warning('Failed to check if standalone: $e');
      return false;
    } finally {
      key?.close();
    }
  }

  Future<bool> checkChannel({
    required VersionModule module,
    required String channel,
  }) async {
    if (module == VersionModule.installer) {
      final version = await getLatestLauncherVersion(channel);
      return version != null;
    }

    final rq = ServiceVersionsRequest(id: module.name, channel: channel);
    final versions = await sl.get<KyberGRPCService>().launcherClient.versions(
      rq,
    );
    return versions.versions.isNotEmpty &&
        versions.versions.firstWhereOrNull((x) => x.isLatest) != null;
  }

  Future<bool> updateAvailable({
    required VersionModule module,
    String? channel,
    KyberGRPCService? service,
  }) async {
    if (Platform.isMacOS && module == VersionModule.installer) {
      return false;
    }

    if ((kDebugMode || kProfileMode) && module == VersionModule.installer) {
      return false;
    }

    channel ??= module.releaseChannel;
    final rq = ServiceVersionsRequest(id: module.name, channel: channel);
    final versions = await (service ?? sl.get<KyberGRPCService>())
        .launcherClient
        .versions(rq);

    final currentVersion = await module.getCurrentVersion();
    final latestVersion = versions.versions.firstWhereOrNull((x) => x.isLatest);
    if (currentVersion == null) {
      _logger.info('No version found for ${module.name}.');
      return true;
    }

    if (latestVersion == null) {
      _logger.info(
        'No latest version found for ${module.name}. Switching to stable.',
      );
      await module.setReleaseChannel('stable');
      return true;
    }

    late bool updateAvailable;
    if (module == VersionModule.installer) {
      final latestVersion = await getLatestLauncherVersion();
      if (latestVersion == 'DISCONTINUED' || latestVersion == null) {
        _logger.info(
          'The branch ${VersionModule.installer.releaseChannel} has been discontinued. Switching to main.',
        );
        await VersionModule.installer.setReleaseChannel('stable');
        return true;
      }

      updateAvailable = latestVersion != currentVersion;
    } else {
      updateAvailable = latestVersion.version != currentVersion;
    }

    if (updateAvailable) {
      _logger.info(
        'New version available for ${module.name}: ${latestVersion.version}',
      );
      return true;
    }

    if (module.requiredFiles.any((x) => !File(x).existsSync())) {
      _logger.info('Required files missing for ${module.name}.');
      return true;
    }

    return false;
  }

  Future<void> updateVersion({
    required VersionModule module,
    String? channel,
    String? token,
    KyberGRPCService? service,
    void Function(int, int)? onProgress,
  }) async {
    if (!kReleaseMode && module == VersionModule.installer) {
      return;
    }

    final x = service ?? sl.get<KyberGRPCService>();
    channel ??= module.releaseChannel;
    final versions = await x.launcherClient.versions(
      ServiceVersionsRequest(id: module.name, channel: channel),
    );
    final latestVersion = versions.versions
        .where((x) => x.isLatest)
        .firstOrNull;

    if (latestVersion == null) {
      NotificationService.showNotification(
        message:
            'No latest version found for "${module.name}" on channel "$channel".',
      );
      _logger.warning('No latest version found for ${module.name}');
      return;
    }

    if (module == VersionModule.installer && isStandalone()) {
      NotificationService.showNotification(
        message:
            'The standalone version of the Launcher cannot be automatically updated.',
      );
      _logger.warning(
        'The standalone version of the Launcher cannot be automatically updated.',
      );
      return;
    }

    _logger.info('Updating ${module.name} to version ${latestVersion.version}');

    final download = await x.launcherClient.downloadUrl(
      ServiceVersionDownloadUrlRequest(
        id: module.name,
        version: latestVersion.version,
        channel: channel,
      ),
    );
    final filename = basename(download.url).split('?').first;
    final downloadDir = await module.getDownloadDir();
    final downloadPath = join(downloadDir, filename);

    _logger.fine('Downloading to $downloadPath');

    final file = File(downloadPath);
    if (file.existsSync()) {
      file.deleteSync();
    }

    file.createSync(recursive: true);

    final raf = file.openSync(mode: FileMode.write);

    try {
      final stream = await Rhttp.getStream(
        download.url,
        onReceiveProgress: onProgress,
      );

      await stream.body.forEach(raf.writeFromSync);
    } finally {
      raf.closeSync();
    }

    if (!Directory(downloadDir).existsSync()) {
      Directory(downloadDir).createSync();
    }

    _logger.fine('Extracting artifact...');

    await extract(filePath: downloadPath, targetDir: downloadDir);

    File(downloadPath).deleteSync();

    await box.put(module.name, latestVersion.version);
    if (module == VersionModule.installer) {
      await Process.run('sc', ['stop', 'MaximaBackgroundService']);
      await Process.run(join(downloadDir, 'KyberLauncherInstaller.exe'), [
        '/VERYSILENT',
        '/FORCECLOSEAPPLICATIONS',
        '/RESTARTAPPLICATIONS',
      ], runInShell: true);

      exit(0);
    } else {
      if (module == VersionModule.module) {
        File(
          join(FileHelper.getModuleDirectory().path, 'VERSION'),
        ).writeAsStringSync(latestVersion.version);
      }
    }

    _logger.info('Updated ${module.name} to version ${latestVersion.version}');
  }

  Future<String?> getLatestLauncherVersion([String? releaseChannel]) async {
    try {
      final rawVersion = await Rhttp.getText(
        'https://s3.kyber.gg/artifacts/launcher-versions/${releaseChannel ?? VersionModule.installer.releaseChannel}/latest-version',
      );

      return rawVersion.body.split(Platform.lineTerminator).first;
    } catch (e) {
      return null;
    }
  }
}
