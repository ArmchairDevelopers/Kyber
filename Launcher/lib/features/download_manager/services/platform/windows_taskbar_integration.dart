import 'package:flutter/services.dart';
import 'package:kyber_launcher/features/download_manager/services/platform/download_platform_integration.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

class WindowsTaskbarIntegration implements DownloadPlatformIntegration {
  const WindowsTaskbarIntegration();

  @override
  Future<void> updateProgress(double progress) async {
    if (progress < 0 || progress > 1) {
      return;
    }

    await _guard(() async {
      await WindowsTaskbar.setProgressMode(TaskbarProgressMode.normal);
      final percentage = (progress * 100).toInt();
      await WindowsTaskbar.setProgress(percentage, 100);
    });
  }

  @override
  Future<void> setIndeterminate() async {
    await _guard(
      () => WindowsTaskbar.setProgressMode(TaskbarProgressMode.indeterminate),
    );
  }

  @override
  Future<void> clear() async {
    await _guard(
      () => WindowsTaskbar.setProgressMode(TaskbarProgressMode.noProgress),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (_) {}
  }
}

class NoOpPlatformIntegration implements DownloadPlatformIntegration {
  const NoOpPlatformIntegration();

  @override
  Future<void> updateProgress(double progress) async {}

  @override
  Future<void> setIndeterminate() async {}

  @override
  Future<void> clear() async {}
}
