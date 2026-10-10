import 'dart:io';

import 'package:kyber_collection/kyber_collection.dart';
import 'package:path/path.dart';

class ModHelper {
  ModHelper._();

  static List<FrostyMod> filterGameplayMods(List<FrostyMod> mods) {
    return mods.where((mod) => ['gameplay', 'maps', 'map'].contains(mod.details.category.toLowerCase())).toList();
  }

  static List<FrostyMod> expandMods(List<FrostyMod> mods) {
    final mods = <FrostyMod>[];
    for (final mod in mods) {
      if (!mod.isCollection) {
        mods.add(mod);
      } else {
        for (final modPath in getCollectionMods(mod)) {
          final mod = File(modPath);
          if (!mod.existsSync()) {
            continue;
          }

          final frostyMod = ModReader(mod.openSync(), modPath).readMod();
          if (frostyMod == null) {
            continue;
          }

          mods.add(frostyMod);
        }
      }
    }

    return mods;
  }

  static List<String> getCollectionMods(FrostyMod mod) {
    final collectionDirName = dirname(mod.filename);
    if (collectionDirName == '.') {
      return mod.mods ?? [];
    }

    return mod.mods?.map((e) => join(dirname(mod.filename), e)).toList() ?? [];
  }

  static List<FrostyMod> readFrostyMods(List<String> modPaths) {
    final fbMods = <FrostyMod>[];
    for (final mod in modPaths) {
      final modFile = File(mod);
      if (!modFile.existsSync()) {
        continue;
      }

      final modExtension = extension(mod);
      late FrostyMod? frostyMod;
      if (modExtension == '.fbmod') {
        frostyMod = ModReader(modFile.openSync(), mod).readMod();
      } else if (modExtension == '.fbcollection') {
        frostyMod = FrostyCollectionReader(modFile.openSync(), mod).readMod();
      } else {
        continue;
      }

      if (frostyMod == null) {
        continue;
      }

      fbMods.add(frostyMod);
    }

    return fbMods;
  }
}
