import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class ProcessHelper {
  ProcessHelper._();

  static bool isRunningAsAdmin() => using((arena) {
    final tokenHandle = arena<Pointer>();

    final opened = OpenProcessToken(
      GetCurrentProcess(),
      TOKEN_QUERY,
      tokenHandle,
    );
    if (!opened.value) {
      throw WindowsException(opened.error.toHRESULT());
    }

    final token = HANDLE(tokenHandle.value);
    try {
      final elevation = arena<TOKEN_ELEVATION>();
      final returnLength = arena<Uint32>();

      final queried = GetTokenInformation(
        token,
        TokenElevation,
        elevation,
        sizeOf<TOKEN_ELEVATION>(),
        returnLength,
      );
      if (!queried.value) {
        throw WindowsException(queried.error.toHRESULT());
      }

      return elevation.ref.TokenIsElevated != 0;
    } finally {
      CloseHandle(token);
    }
  });
}
