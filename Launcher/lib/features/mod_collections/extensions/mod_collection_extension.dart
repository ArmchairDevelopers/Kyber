import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/constants/categories.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/injection_container.dart';

extension LocalMods on ModCollectionMetaData {
  List<String> getModPaths({bool excludeCollectionMods = false}) {
    if (localId == 'no-mods') {
      return [];
    }

    final paths = <String>[];
    for (final mod in getLocalMods().whereType<FrostyMod>()) {
      if (!mod.isCollection || excludeCollectionMods) {
        paths.add(mod.filename);
      } else {
        paths.addAll(mod.getMods()!);
      }
    }

    return paths;
  }

  bool containsMod(FrostyMod mod) {
    if (localId == 'no-mods') {
      return true;
    }

    final localMods = sl.get<ModService>().mods;
    final mods = <FrostyMod>[];
    for (final mod in getLocalMods()) {
      if (!mod!.isCollection) {
        mods.add(mod);
      } else {
        for (final collectionMod in mod.getMods()!) {
          final mod = localMods
              .where((e) => e.filename == collectionMod)
              .firstOrNull;
          if (mod != null) {
            mods.add(mod);
          }
        }
      }
    }

    return mods
        .where(
          (e) =>
              e.details.name == mod.details.name &&
              e.details.version == mod.details.version,
        )
        .isNotEmpty;
  }

  ModData getInterfaceData() {
    final basePath = ModService.getBasePath();
    final mods = getModPaths();
    final frostyMods = getLocalMods(onlyGameplay: true)
        .whereType<FrostyMod>()
        .map((e) {
          return ServerMod(
            name: e.details.name,
            version: e.details.version,
            link: e.details.link,
            fileSize: .new(e.size),
          );
        });

    return ModData(
      basePath: basePath,
      modPaths: mods,
      mods: frostyMods,
    );
  }

  bool containsGameplayMods() {
    return getLocalMods(onlyGameplay: true).isNotEmpty;
  }

  List<FrostyMod?> getLocalMods({
    bool onlyGameplay = false,
    bool expandCollections = false,
    bool expandGameplayCollections = true,
  }) {
    final localMods = [
      ...sl.get<ModService>().mods,
      ...sl.get<ModService>().hiddenMods,
    ];
    final mods = <FrostyMod?>[];
    for (final mod in this.mods) {
      if (mod.filename != null) {
        final localMod = localMods
            .where((x) => x.filename == mod.filename)
            .firstOrNull;
        if (localMod != null) {
          mods.add(localMod);
          continue;
        }
      }

      final localMod = localMods
          .where(
            (x) =>
                x.details.name == mod.name && x.details.version == mod.version,
          )
          .firstOrNull;
      mods.add(localMod);
    }

    if (expandCollections) {
      for (final collection in List<FrostyMod?>.from(
        mods.where(
          (e) =>
              (e?.isCollection ?? false) &&
              (expandGameplayCollections ||
                  !kRequiredCategories.contains(
                    e?.details.category.toLowerCase(),
                  )),
        ),
      )) {
        final modPaths = collection?.getMods();
        final collectionMods = modPaths
            ?.map((e) => localMods.where((x) => e == x.filename).firstOrNull)
            .toList();
        if (collectionMods != null) {
          final collectionIndex = mods.indexOf(collection);
          mods.insertAll(collectionIndex, collectionMods);
        }
      }
    }

    if (onlyGameplay) {
      return mods
          .where(
            (e) =>
                kRequiredCategories.contains(e?.details.category.toLowerCase()),
          )
          .toList();
    }

    return mods;
  }
}
