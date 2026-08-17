import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class DiskHelper {
  DiskHelper._();

  static DiskInfo getDiskInfo(String path) {
    final drive = path.substring(0, 3);
    final driveInfo = _getDiskSpaceInfo(drive);

    return DiskInfo(drive, driveInfo.$1, driveInfo.$2);
  }

  static (int, int) _getDiskSpaceInfo(String drive) => using((arena) {
    final freeBytesAvailable = arena<Uint64>();
    final totalNumberOfBytes = arena<Uint64>();
    final totalNumberOfFreeBytes = arena<Uint64>();

    final result = GetDiskFreeSpaceEx(
      arena.pcwstr(drive),
      freeBytesAvailable,
      totalNumberOfBytes,
      totalNumberOfFreeBytes,
    );

    if (!result.value) {
      return (0, 0);
    }

    return (totalNumberOfBytes.value, freeBytesAvailable.value);
  });
}

class DiskInfo {
  DiskInfo(this.path, this.totalSpace, this.freeSpace);

  final String path;
  final int totalSpace;
  final int freeSpace;
}
