import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

typedef _RtlGetVersionC = Int32 Function(Pointer<OSVERSIONINFO>);
typedef _RtlGetVersionDart = int Function(Pointer<OSVERSIONINFO>);

class WindowsUtils {
  WindowsUtils._();

  static bool isWindowsCompMode() {
    if (!Platform.isWindows) {
      return false;
    }

    final ntdll = DynamicLibrary.open('ntdll.dll');
    final rtlGetVersion = ntdll
        .lookupFunction<_RtlGetVersionC, _RtlGetVersionDart>('RtlGetVersion');

    return using((arena) {
      final info = arena<OSVERSIONINFO>()
        ..ref.dwOSVersionInfoSize = sizeOf<OSVERSIONINFO>();

      if (rtlGetVersion(info) != 0) {
        return false;
      }

      return info.ref.dwMajorVersion == 6 && info.ref.dwMinorVersion == 1;
    });
  }

  static bool _isDllPresent(String dllName) => using((arena) {
    final result = LoadLibraryEx(
      arena.pcwstr(dllName),
      LOAD_LIBRARY_SEARCH_SYSTEM32,
    );

    if (result.value.isNull) {
      return false;
    }

    FreeLibrary(result.value);
    return true;
  });

  static bool get isVcRuntimeInstalled =>
      _isDllPresent('vcruntime140.dll') || _isDllPresent('msvcp140.dll');
}
