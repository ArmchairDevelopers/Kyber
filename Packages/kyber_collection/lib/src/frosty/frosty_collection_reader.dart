import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_collection/src/utils/file_byte_reader.dart';
import 'package:path/path.dart';

const _kFrostyMagic = 0x46434F4C;

class FrostyCollectionReader extends FileByteReader {
  final String filename;

  FrostyCollectionReader(super.file, this.filename);

  List<Uint8List> readScreenshots(FrostyMod mod) {
    file.setPositionSync(mod.screenshotOffset);
    final count = readUint32();
    final screenshots = <Uint8List>[];
    for (var i = 0; i < count; i++) {
      final size = readUint32();
      final screenshot = file.readSync(size);
      screenshots.add(screenshot);
    }

    return screenshots;
  }

  FrostyMod? readMod() {
    try {
      final magic = readUint32();
      final version = readUint32();
      if (magic != _kFrostyMagic) {
        return null;
      }

      final manifestOffset = readUint32();
      final manifestSize = readUint32();
      final iconOffset = readUint32();
      final iconSize = readUint32();
      final screenshotOffset = readUint32();

      file.setPositionSync(manifestOffset);
      final manifestString = utf8.decode(file.readSync(manifestSize));
      final manifest = FrostyCollectionManifest.fromJson(
        jsonDecode(manifestString) as Map<String, Object?>,
      );

      file.setPositionSync(iconOffset);
      final icon = file.readSync(iconSize);
      var size = file.lengthSync();

      for (final mod in manifest.mods) {
        final modFile = File(join(dirname(file.path), mod));
        if (modFile.existsSync()) {
          size += modFile.lengthSync();
        }
      }

      return FrostyMod(
        version: version,
        gameVersion: 0,
        filename: filename,
        icon: icon,
        size: size,
        isCollection: true,
        mods: manifest.mods,
        modVersions: manifest.modVersions,
        screenshotOffset: screenshotOffset,
        details: FrostyModDetails(
          manifest.title,
          manifest.author,
          manifest.category,
          manifest.version,
          manifest.description,
          manifest.link,
        ),
      );
    } finally {
      file.closeSync();
    }
  }
}
