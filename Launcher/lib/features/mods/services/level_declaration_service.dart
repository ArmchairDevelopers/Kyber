import 'dart:typed_data';

import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/models/modes.dart';
import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/injection_container.dart';

class LevelDeclarationService {
  final Map<String, ModEntry> _modEntries = {};

  void set(Map<String, ModEntry> modEntries) {
    _modEntries
      ..clear()
      ..addAll(modEntries);
  }

  KyberMap? getMapByMode({
    required String map,
    required String mode,
    required ModCollectionMetaData collection,
  }) {
    final filenames = collection.getModPaths();

    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      for (final customMap in modEntry.maps) {
        if (customMap.map != map || !customMap.supportedModes.contains(mode)) {
          continue;
        }

        return KyberMap(
          name: customMap.name,
          map: customMap.map,
          mode: mode,
          isCustom: true,
        );
      }
    }

    return null;
  }

  FrostyMod getModByMap({
    required String map,
    required ModCollectionMetaData collection,
  }) {
    final filenames = collection.getModPaths();

    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      for (final customMap in modEntry.maps) {
        if (customMap.map != map) {
          continue;
        }

        return sl
            .get<ModService>()
            .mods
            .where((e) => e.filename == filename)
            .first;
      }
    }

    throw Exception('Mod not found for map $map');
  }

  List<KyberMap> getMapsForMode({
    required String mode,
    required ModCollectionMetaData collection,
  }) {
    final filenames = collection.getModPaths();

    final maps = <KyberMap>[];
    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      for (final customMap in modEntry.maps) {
        final mappedModes = customMap.supportedModes.map(
          (e) => modEntry.modeMappings[e] ?? e,
        );
        if (!mappedModes.any((e) => e == mode)) {
          continue;
        }

        String? supportedMode;
        for (final entry in customMap.supportedModes) {
          if (entry == mode) {
            supportedMode = mode;
            break;
          }

          final mapped = modEntry.modeMappings[entry];
          if (mapped == mode) {
            supportedMode = entry;
            break;
          }
        }

        maps.add(
          KyberMap(
            name: customMap.name,
            map: customMap.map,
            mode: supportedMode,
            isCustom: true,
          ),
        );
      }
    }

    return maps;
  }

  List<KyberMap> getMapsForCollection(ModCollectionMetaData collection) {
    final filenames = collection.getModPaths();

    final maps = <KyberMap>[];
    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      for (final customMap in modEntry.maps) {
        maps.add(
          KyberMap(
            name: customMap.name,
            map: customMap.map,
          ),
        );
      }
    }
    return maps;
  }

  String? getModeName({
    required String mode,
    required ModCollectionMetaData collection,
  }) {
    final filenames = collection.getModPaths();

    String? modeName;
    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      if (modEntry.mapNameOverrides.containsKey(mode)) {
        modeName = modEntry.mapNameOverrides[mode];
      }

      for (final customMode in modEntry.modes) {
        if (customMode.mode == mode) {
          modeName = customMode.name;
        }
      }
    }

    return modeName;
  }

  List<Mode> getModesForCollection(
    ModCollectionMetaData collection, {
    bool includeDefaults = false,
  }) {
    final filenames = collection.getModPaths();
    final modeList = <Mode>[];

    if (includeDefaults) {
      for (final mode in modes) {
        modeList.add(
          Mode(
            name: mode.name,
            mode: mode.mode,
            maxPlayers: mode.maxPlayers,
            image: mode.image,
            alternativeModes: [],
            maps: [],
          ),
        );
      }
    }

    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      for (final customMode in modEntry.modes) {
        if (modEntry.modeMappings[customMode.mode] != null) {
          continue;
        }

        final subModes = modEntry.modeMappings.entries
            .where((e) => e.value == customMode.mode)
            .map((e) => e.key)
            .toList();
        modeList.add(
          Mode(
            name: customMode.name,
            mode: customMode.mode,
            maxPlayers: customMode.maxPlayers,
            image: customMode.image,
            alternativeModes: subModes,
            maps: [],
            isCustom: true,
          ),
        );
      }

      for (final entry in modeList) {
        if (modEntry.mapNameOverrides[entry.mode] != null) {
          entry.name = modEntry.mapNameOverrides[entry.mode]!;
        }
      }
    }

    return modeList;
  }

  Uint8List? getMapImage(
    ModCollectionMetaData collection,
    String map, {
    String? name,
  }) {
    final filenames = collection.getModPaths();

    for (final filename in filenames) {
      final modEntry = _modEntries[filename];
      if (modEntry == null) {
        continue;
      }

      for (final customMap in modEntry.maps) {
        if (customMap.map == map &&
            customMap.image != null &&
            (name == null || customMap.name == name) &&
            customMap.image!.isNotEmpty) {
          return customMap.image;
        }
      }
    }

    return null;
  }
}

class ModEntry {
  ModEntry(this.maps, this.modes, this.modeMappings, this.mapNameOverrides);

  final List<CustomMap> maps;
  final List<CustomMode> modes;
  final Map<String, String> modeMappings;
  final Map<String, String> mapNameOverrides;
}

class CustomMode {
  CustomMode(this.name, this.mode, this.maxPlayers, this.image);

  final String name;
  final String mode;
  final int maxPlayers;
  final Uint8List? image;
}

class CustomMap {
  CustomMap(this.name, this.map, this.supportedModes, this.image);

  final String name;
  final String map;
  final List<String> supportedModes;
  final Uint8List? image;
}
