import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

extension on String {
  PCWSTR toPCWSTR({Allocator allocator = calloc}) =>
      PCWSTR(toNativeUtf16(allocator: allocator));
}
