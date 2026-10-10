import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:win32/win32.dart';

class TaskbarIconHelper {
  TaskbarIconHelper._();

  static final _logger = Logger('taskbar_icon');
  static int? _defaultIcon;

  static Future<Uint8List?> _getIcon() async {
    try {
      final response = await Dio()
          .get<Uint8List>(
        'https://s3.kyber.gg/frontend-assets/launcher_icon.ico',
        options: Options(
          responseType: .bytes,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
        ),
      )
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Request timed out'),
      );

      return response.data != null ? Uint8List.fromList(response.data!) : null;
    } catch (_) {
      return null;
    }
  }

  static HWND _findWindow() => FindWindow(
    'FLUTTER_RUNNER_WIN32_WINDOW'.toPcwstr(),
    'KYBER Launcher'.toPcwstr(),
  ).value;

  static void _applyIcon(HWND hwnd, int icon) {
    SetClassLongPtr(hwnd, GCLP_HICON, icon);
    SendMessage(hwnd, WM_SETICON, const WPARAM(ICON_BIG), LPARAM(icon));
    SendMessage(hwnd, WM_SETICON, const WPARAM(ICON_SMALL), LPARAM(icon));
  }

  static void _resetIcon(HWND hwnd) {
    final defaultIcon = _defaultIcon;
    if (defaultIcon == null) return;
    _applyIcon(hwnd, defaultIcon);
  }

  static Future<void> setWindowIcon() async {
    if (!Platform.isWindows) return;

    final hwnd = _findWindow();
    if (hwnd.isNull) {
      _logger.severe('Failed to obtain the Flutter window handle.');
      return;
    }

    final icon = await _getIcon();
    if (icon == null) {
      _resetIcon(hwnd);
      return;
    }

    _defaultIcon ??= GetClassLongPtr(hwnd, GCLP_HICON).value;

    final tmpDir = await getTemporaryDirectory();
    final tmpFile = join(tmpDir.path, 'launcher_icon', 'launcher_icon.ico');
    await Directory(dirname(tmpFile)).create(recursive: true);
    await File(tmpFile).writeAsBytes(icon);

    final iconHandle = using((arena) {
      return LoadImage(
        null,
        arena.pcwstr(tmpFile),
        IMAGE_ICON,
        32,
        32,
        LR_LOADFROMFILE,
      );
    });

    if (iconHandle.value.isNull) {
      _logger.severe('Failed to load icon. Error code: ${iconHandle.error}');
      return;
    }

    _applyIcon(hwnd, iconHandle.value.address);
  }
}
