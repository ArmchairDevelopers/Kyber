import 'dart:convert';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/constants/categories.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/helper/frosty_mod_extension.dart';
import 'package:kyber_launcher/features/mods/models/mod_list_group.dart';
import 'package:kyber_launcher/features/mods/models/mods_filter.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:path/path.dart';

class ModsListCubit extends Cubit<ModsListState> {
  ModsListCubit() : super(const ModsListInitial()) {
    filter = const ModsFilter();

    sl.isReady<ModService>().then((_) {
      if (isClosed) return;
      sl<ModService>().addListener(_modsChanged);
      loadMods();
    });
  }

  late ModsFilter filter;

  @override
  Future<void> close() async {
    if (sl.isReadySync<ModService>()) {
      sl<ModService>().removeListener(_modsChanged);
    }
    return super.close();
  }

  void _modsChanged() {
    loadMods();
  }

  void setFilter(ModsFilter newFilter) {
    if (newFilter == filter) return;
    filter = newFilter;
    loadMods();
  }

  void setSelectedMod(FrostyMod? selectedMod) {
    emit(
      ModsListLoaded(
        mods: state.mods,
        groups: state.groups,
        filter: state.filter,
        selectedMods: state.selectedMods,
        selectedMod: selectedMod,
      ),
    );
  }

  void setSelectedMods(Set<String> selectedMods) {
    emit(
      ModsListLoaded(
        mods: state.mods,
        groups: state.groups,
        filter: state.filter,
        selectedMods: selectedMods,
        selectedMod: state.selectedMod,
      ),
    );
  }

  Future<void> loadMods() async {
    if (!sl.isReadySync<ModService>()) {
      await sl.isReady<ModService>();
      if (isClosed) return;
    }

    final all = List<FrostyMod>.of(sl<ModService>().mods);
    final filtered = _applyFilter(all, filter);
    final groups = _buildGroups(filtered);

    emit(
      ModsListLoaded(
        mods: filtered,
        groups: groups,
        filter: filter,
        selectedMods: state.selectedMods,
        selectedMod: state.selectedMod,
      ),
    );
  }

  /// Groups mods by their NexusMods mod ID from the manifest.
  /// Mods not in the manifest remain as individual (unnamed) groups.
  /// Groups are sorted by title, interleaved with unnamed mods alphabetically.
  List<ModListGroup> _buildGroups(List<FrostyMod> mods) {
    // Read the manifest
    Map<String, int> fileToModId;
    Map<int, String> modIdToTitle;
    Map<int, Map<String, dynamic>> modIdToMeta;
    try {
      final manifestFile = File(
        join(ModService.getBasePath(), 'nexus_mod_manifest.json'),
      );
      if (manifestFile.existsSync()) {
        final manifest =
            jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
        final files =
            manifest['files'] as Map<String, dynamic>? ?? {};
        final modEntries =
            manifest['mods'] as Map<String, dynamic>? ?? {};

        fileToModId = {};
        for (final e in files.entries) {
          fileToModId[e.key] = (e.value as num).toInt();
        }
        modIdToTitle = {};
        modIdToMeta = {};
        for (final e in modEntries.entries) {
          final meta = e.value as Map<String, dynamic>?;
          final id = int.parse(e.key);
          modIdToTitle[id] = meta?['title'] as String? ?? '';
          modIdToMeta[id] = meta ?? {};
        }
      } else {
        fileToModId = {};
        modIdToTitle = {};
        modIdToMeta = {};
      }
    } catch (_) {
      fileToModId = {};
      modIdToTitle = {};
      modIdToMeta = {};
    }

    // Group mods by modId; unmanifested mods go in their own bucket
    final groupMap = <int, List<FrostyMod>>{};
    final unmanifested = <FrostyMod>[];

    for (final mod in mods) {
      final lookupName = basename(mod.filename);
      final modId = fileToModId[lookupName] ?? fileToModId[mod.filename];
      if (modId != null) {
        groupMap.putIfAbsent(modId, () => []).add(mod);
      } else {
        unmanifested.add(mod);
      }
    }

    // Sort mods within each group alphabetically
    for (final list in groupMap.values) {
      list.sort((a, b) => a.details.name.compareTo(b.details.name));
    }

    // Build named groups, sorted by title
    final groups = <ModListGroup>[];
    final sortedIds = groupMap.keys.toList()
      ..sort((a, b) {
        final titleA = modIdToTitle[a] ?? '';
        final titleB = modIdToTitle[b] ?? '';
        return titleA.compareTo(titleB);
      });

    for (final id in sortedIds) {
      final meta = modIdToMeta[id] ?? {};
      groups.add(
        ModListGroup(
          title: modIdToTitle[id],
          modId: id,
          latestVersion: meta['latestVersion'] as String?,
          lastDownloaded: meta['lastDownloaded'] as String?,
          mods: groupMap[id]!,
        ),
      );
    }

    // Add unmanifested mods as individual groups, sorted by name
    unmanifested.sort((a, b) => a.details.name.compareTo(b.details.name));
    for (final mod in unmanifested) {
      groups.add(ModListGroup(mods: [mod]));
    }

    return groups;
  }

  List<FrostyMod> _applyFilter(List<FrostyMod> mods, ModsFilter filter) {
    final q = filter.query?.trim();
    final qLower = (q == null || q.isEmpty) ? null : q.toLowerCase();

    final out =
        mods.where((mod) {
          var matchesSearch = true;

          if (qLower != null) {
            final modData = StringBuffer(mod.toString().toLowerCase());
            if (mod.isCollection) {
              for (final element in mod.getCollectionMods()) {
                modData.write(element.toString().toLowerCase());
              }
            }
            matchesSearch = modData.toString().contains(qLower);
          }

          final matchesScope = switch (filter.scope) {
            ModScope.all => true,
            ModScope.gameplay => kRequiredCategories.contains(
              mod.details.category.toLowerCase(),
            ),
            ModScope.cosmetic => !kRequiredCategories.contains(
              mod.details.category.toLowerCase(),
            ),
          };

          return matchesSearch && matchesScope;
        }).toList()..sort((a, b) {
          if (a.isCollection != b.isCollection) {
            return a.isCollection ? -1 : 1;
          }
          return a.details.name.compareTo(b.details.name);
        });

    final modsInCollections = (filter.scope == ModScope.all ? out : mods)
        .where((x) => x.isCollection)
        .expand((e) => e.getMods() ?? <String>[])
        .toSet();

    out.removeWhere((mod) => modsInCollections.contains(mod.filename));

    return out;
  }
}

sealed class ModsListState {
  const ModsListState({
    required this.filter,
    this.mods = const [],
    this.groups = const [],
    this.selectedMods = const {},
    this.selectedMod,
  });

  final ModsFilter filter;
  final List<FrostyMod> mods;
  final List<ModListGroup> groups;
  final Set<String> selectedMods;
  final FrostyMod? selectedMod;
}

class ModsListInitial extends ModsListState {
  const ModsListInitial() : super(filter: const ModsFilter());
}

class ModsListLoaded extends ModsListState {
  const ModsListLoaded({
    required super.mods,
    required super.groups,
    required super.filter,
    required super.selectedMods,
    required super.selectedMod,
  });
}
