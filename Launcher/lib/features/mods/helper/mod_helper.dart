import 'package:collection/collection.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/constants/categories.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/injection_container.dart';

class ModHelper {
  static FrostyMod? getModByFileName(String fileName) {
    final service = sl.get<ModService>();
    return service.mods
        .where((element) => element.filename == fileName)
        .firstOrNull;
  }

  static bool isInstalled(
    String name,
    String version, {
    bool ignoreCorrupted = false,
  }) {
    if (!sl.isReadySync<ModService>()) return false;

    final service = sl.get<ModService>();

    for (final mod in service.mods) {
      if (mod.details.name == name && mod.details.version == version) {
        if (!mod.isCollection || ignoreCorrupted) return true;
        if (!mod.isCorrupted()) return true;
      }
    }

    return false;
  }

  /// Returns the installed version string if any version of the named mod
  /// is installed, or `null` if none is installed.
  static String? getInstalledVersion(String name) {
    if (!sl.isReadySync<ModService>()) return null;

    final service = sl.get<ModService>();

    for (final mod in service.mods) {
      if (mod.details.name == name) {
        if (mod.isCollection && mod.isCorrupted()) continue;
        return mod.details.version;
      }
    }

    return null;
  }

  static List<FrostyMod> getGameplayMods(List<FrostyMod> mods) {
    return mods
        .where(
          (mod) =>
              kRequiredCategories.contains(mod.details.category.toLowerCase()),
        )
        .toList();
  }
}
