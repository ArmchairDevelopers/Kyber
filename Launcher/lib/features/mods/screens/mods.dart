import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_browser_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_search_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_browser.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/filter_dropdown.dart';
import 'package:kyber_launcher/features/mods/dialogs/delete_mods_dialog.dart';
import 'package:kyber_launcher/features/mods/models/mods_filter.dart';
import 'package:kyber_launcher/features/mods/providers/collection_editor_cubit.dart';
import 'package:kyber_launcher/features/mods/providers/mod_list_cubit.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/mods/widgets/browser_category_box.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_box/collection_box.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_entry.dart';
import 'package:kyber_launcher/features/mods/widgets/mod_info_box.dart';
import 'package:kyber_launcher/features/mods/widgets/mod_list/mod_list.dart';
import 'package:kyber_launcher/features/mods/widgets/mod_list/mod_list_header.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/elements/filter_dropdown.dart';
import 'package:kyber_launcher/shared/ui/layout/bordered_content.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ModsPage extends StatefulWidget {
  const ModsPage({super.key});

  @override
  State<ModsPage> createState() => _ModsPageState();
}

class _ModsPageState extends State<ModsPage> {
  int _pageIndex = 0;
  int _categoryIndex = 0;
  int _lastSelectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _initCategoryIndex();
  }

  void _initCategoryIndex() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final categories = sl<NexusModsService>().nexusBridge.categories;
      final selectedCategory = context.read<ModBrowserCubit>().currentCategory;

      if (selectedCategory == null) return;

      setState(() {
        _categoryIndex = categories.indexOf(selectedCategory);
      });
    });
  }

  void _onPageChanged(int value) {
    setState(() => _pageIndex = value);
  }

  void _onCategorySelected(int category) {
    setState(() => _categoryIndex = category);
    context.read<ModBrowserCubit>().changePage(
      ModBrowserPage.category,
      category: sl<NexusModsService>().nexusBridge.categories[category],
    );
  }

  void _onModSelected(FrostyMod mod, ModsListState state, ModsListCubit cubit) {
    final currentIndex = state.mods.indexOf(mod);
    final isShiftPressed = _isShiftKeyPressed();

    if (!isShiftPressed) {
      _handleSingleModSelection(mod, currentIndex, state, cubit);
    } else {
      _handleShiftModSelection(mod, currentIndex, state, cubit);
    }

    if (cubit.state.selectedMods.isEmpty) {
      _lastSelectedIndex = -1;
    }

    setState(() {});
  }

  bool _isShiftKeyPressed() {
    return HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.isLogicalKeyPressed(
          LogicalKeyboardKey.shiftRight,
        );
  }

  void _handleSingleModSelection(
    FrostyMod mod,
    int currentIndex,
    ModsListState state,
    ModsListCubit cubit,
  ) {
    _lastSelectedIndex = currentIndex;
    final newSet = Set<String>.from(state.selectedMods);

    if (state.selectedMods.contains(mod.filename)) {
      newSet.remove(mod.filename);
    } else {
      newSet.add(mod.filename);
    }

    cubit.setSelectedMods(newSet);
  }

  void _handleShiftModSelection(
    FrostyMod mod,
    int currentIndex,
    ModsListState state,
    ModsListCubit cubit,
  ) {
    if (_lastSelectedIndex == -1) {
      final newSet = Set<String>.from(state.selectedMods)..add(mod.filename);
      cubit.setSelectedMods(newSet);
      _lastSelectedIndex = currentIndex;
      return;
    }

    final start = currentIndex < _lastSelectedIndex
        ? currentIndex
        : _lastSelectedIndex;
    final end = currentIndex < _lastSelectedIndex
        ? _lastSelectedIndex
        : currentIndex;
    final isDeselecting = state.selectedMods.contains(mod.filename);

    for (var i = start; i <= end; i++) {
      final selectedMods = Set<String>.from(cubit.state.selectedMods);
      if (isDeselecting) {
        selectedMods.remove(state.mods[i].filename);
      } else {
        selectedMods.add(state.mods[i].filename);
      }
      cubit.setSelectedMods(selectedMods);
    }
  }

  void _handleSelectAll({
    required bool selected,
    required ModsListState state,
    required ModsListCubit cubit,
  }) {
    if (selected) {
      final newSet = state.mods.map((mod) => mod.filename).toSet();
      cubit.setSelectedMods(newSet);
    } else {
      if (state.selectedMods.length != state.mods.length) {
        final newSet = state.mods.map((mod) => mod.filename).toSet();
        cubit.setSelectedMods(newSet);
      } else {
        cubit.setSelectedMods({});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 8,
          child: BorderedContent(
            overlappingBorder: _pageIndex == 0,
            header: _Header(
              pageIndex: _pageIndex,
              onPageChanged: _onPageChanged,
            ),
            content: _MainContent(
              pageIndex: _pageIndex,
              onModSelected: _onModSelected,
              onSelectAll: _handleSelectAll,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 3,
          child: _RightPanel(
            pageIndex: _pageIndex,
            categoryIndex: _categoryIndex,
            onCategorySelected: _onCategorySelected,
          ),
        ),
      ],
    );
  }
}

class _MainContent extends StatelessWidget {
  const _MainContent({
    required this.pageIndex,
    required this.onModSelected,
    required this.onSelectAll,
  });

  final int pageIndex;
  final void Function(FrostyMod, ModsListState, ModsListCubit) onModSelected;
  final void Function({
    required bool selected,
    required ModsListState state,
    required ModsListCubit cubit,
  })
  onSelectAll;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModsListCubit, ModsListState>(
      builder: (context, state) {
        final cubit = context.read<ModsListCubit>();
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          child: pageIndex == 0
              ? _ModListView(
                  state: state,
                  cubit: cubit,
                  onModSelected: onModSelected,
                  onSelectAll: onSelectAll,
                )
              : const CategorizedModList(),
        );
      },
    );
  }
}

class _ModListView extends StatelessWidget {
  const _ModListView({
    required this.state,
    required this.cubit,
    required this.onModSelected,
    required this.onSelectAll,
  });

  final ModsListState state;
  final ModsListCubit cubit;
  final void Function(FrostyMod, ModsListState, ModsListCubit) onModSelected;
  final void Function({
    required bool selected,
    required ModsListState state,
    required ModsListCubit cubit,
  })
  onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ModListHeader(
          modCount: state.mods.length,
          onAllSelected: (selected) => onSelectAll(
            selected: selected,
            state: state,
            cubit: cubit,
          ),
          selectedMods: state.selectedMods,
        ),
        Expanded(
          child: _buildModList(),
        ),
      ],
    );
  }

  Widget _buildModList() {
    if (state is ModsListInitial) {
      return const _LoadingIndicator();
    }

    return ModList(
      mods: state.mods,
      selectedMods: state.selectedMods,
      onModSelected: (mod) => onModSelected(mod, state, cubit),
      onModTap: cubit.setSelectedMod,
      activeMod: state.selectedMod,
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 15,
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: ProgressRing(),
          ),
          Text(
            'LOADING MODS...',
            style: TextStyle(fontFamily: FontFamily.battlefrontUI),
          ),
        ],
      ),
    );
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel({
    required this.pageIndex,
    required this.categoryIndex,
    required this.onCategorySelected,
  });

  final int pageIndex;
  final int categoryIndex;
  final ValueChanged<int> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    if (pageIndex == 1) {
      return BrowserCategoryBox(
        onCategorySelected: onCategorySelected,
        selectedCategory: categoryIndex,
      );
    }

    return BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
      builder: (context, state) {
        final cubit = context.read<ModsListCubit>();
        final modsState = context.watch<ModsListCubit>().state;

        if (state.selectedCollection != null) {
          return const CollectionBox();
        }

        if (modsState.selectedMod != null) {
          return ModInfoBox(
            key: ValueKey(modsState.selectedMod),
            mod: modsState.selectedMod!,
            onClose: () => cubit.setSelectedMod(null),
          );
        }

        return const _CollectionsPanel();
      },
    );
  }
}

class _CollectionsPanel extends StatelessWidget {
  const _CollectionsPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kDefaultOuterBorderRadius),
      child: BackgroundBlur(
        child: Container(
          key: const Key('collection'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kDefaultOuterBorderRadius),
            border: Border.all(color: decoColor, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kDefaultOuterBorderRadius - 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CollectionsHeader(),
                Container(height: 2, color: decoColor),
                const Expanded(child: _CollectionsGrid()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionsHeader extends StatelessWidget {
  const _CollectionsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 61,
      padding: const EdgeInsets.all(13),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COLLECTIONS',
            style: TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 21,
              height: 1,
            ),
          ),
          Text(
            'MANAGE MOD COLLECTIONS & CURATE COSMETIC MODS',
            style: TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 14,
              color: kWhiteColor,
              height: 0.9,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionsGrid extends StatelessWidget {
  const _CollectionsGrid();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: sl.isReady<ModService>(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: ProgressRing());
        }

        return HiveListener<dynamic>(
          box: collectionBox,
          builder: (_) {
            return GridView.builder(
              itemCount: collectionBox.length + 1,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              padding: const .all(13),
              itemBuilder: (context, index) {
                if (index == collectionBox.length) {
                  return CreateCollectionEntry(
                    onTap: () {
                      context.read<CollectionEditorCubit>().createCollection();
                    },
                  );
                }

                final collection = collectionBox.getAt(index)!;
                return CollectionEntry(
                  key: ValueKey(
                    collection.localId + collection.mods.length.toString(),
                  ),
                  modCollection: collection,
                  onTap: () {
                    context.read<CollectionEditorCubit>().selectCollection(
                      collection,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pageIndex,
    required this.onPageChanged,
  });

  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabSelector(pageIndex: pageIndex, onPageChanged: onPageChanged),
        if (pageIndex == 0) ...[
          const SizedBox(width: 20),
          _ModActionButtons(),
        ],
        const SizedBox(width: 20),
        Expanded(
          flex: 2,
          child: pageIndex == 1
              ? const ModBrowserFilterDropdown()
              : _ModsFilterDropdown(
                  onSearchChanged: (value) {
                    final cubit = context.read<ModsListCubit>();
                    cubit.setFilter(cubit.state.filter.copyWith(query: value));
                  },
                ),
        ),
        const SizedBox(width: 20),
        if (pageIndex == 0) _QuickActions(),
        if (pageIndex == 1) const _BrowserPagination(),
      ],
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.pageIndex,
    required this.onPageChanged,
  });

  final int pageIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: KyberTabBar(
        selectedIndex: pageIndex,
        onChanged: (value) {
          if (value == 0) {
            context.read<ModsListCubit>().loadMods();
          }
          onPageChanged(value);
        },
        tabs: [
          Text('Mods'.toUpperCase()),
          Text('Browser'.toUpperCase()),
        ],
      ),
    );
  }
}

class _ModActionButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: KyberTabBar(
        selectedIndex: -1,
        onChanged: (value) => _handleAction(context, value),
        tabs: [
          Assets.icons.kblCollection.svg(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            width: 15,
            height: 15,
          ),
          const Icon(mt.Icons.delete_forever_sharp),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, int value) async {
    final cubit = context.read<ModsListCubit>();
    final mods = cubit.state.mods;
    final selectedMods = cubit.state.selectedMods;
    final selectedFrostyMods = _getSelectedFrostyMods(mods, selectedMods);

    if (value == 1 && selectedFrostyMods.isNotEmpty) {
      await _handleDeleteMods(context, cubit, selectedFrostyMods);
    } else if (value == 0) {
      _handleCreateCollection(context, cubit, mods, selectedMods);
    }
  }

  List<FrostyMod> _getSelectedFrostyMods(
    List<FrostyMod> mods,
    Set<String> selectedMods,
  ) {
    return selectedMods
        .map(
          (filename) => mods.firstWhereOrNull(
            (mod) => mod.filename == filename,
          ),
        )
        .whereType<FrostyMod>()
        .toList();
  }

  Future<void> _handleDeleteMods(
    BuildContext context,
    ModsListCubit cubit,
    List<FrostyMod> modsToDelete,
  ) async {
    final result = await showKyberDialog<bool?>(
      context: navigatorKey.currentContext!,
      builder: (_) => DeleteModsDialog(mods: modsToDelete),
    );

    if (result ?? false) {
      cubit
        ..setSelectedMods({})
        ..setSelectedMod(null);
    }
  }

  void _handleCreateCollection(
    BuildContext context,
    ModsListCubit cubit,
    List<FrostyMod> mods,
    Set<String> selectedMods,
  ) {
    final initialMods = selectedMods
        .map(
          (filename) => mods.firstWhereOrNull(
            (mod) => mod.filename == filename,
          ),
        )
        .whereType<FrostyMod>()
        .toList();

    context.read<CollectionEditorCubit>().createCollection(
      initialMods: initialMods,
    );
    selectedMods.clear();
    cubit.setSelectedMod(null);
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<MaximaCubit>().state.isEntitled(
      .admin,
    );

    return SizedBox(
      width: 80,
      child: KyberTabBar(
        selectedIndex: -1,
        onChanged: (value) => _handleAction(value),
        tabs: [
          const Icon(mt.Icons.folder),
          const Icon(mt.Icons.settings),
          if (isAdmin) const Icon(mt.Icons.add),
        ],
      ),
    );
  }

  void _handleAction(int value) {
    switch (value) {
      case 0:
        launchUrlString('file://${ModService.getBasePath()}');
      case 1:
        router.go('/settings?index=1');
      case 2:
        router.go('/mods/create_collection');
    }
  }
}

class _BrowserPagination extends StatelessWidget {
  const _BrowserPagination();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: BlocBuilder<ModBrowserCubit, ModBrowserState>(
        builder: (context, state) {
          final (page, totalPages) = _getPageInfo(context, state);

          return KyberTabBar(
            selectedIndex: -1,
            onChanged: (value) => _handlePageChange(context, value),
            tabs: [
              const Icon(mt.Icons.arrow_back_ios_new_rounded),
              Text('$page/$totalPages'.toUpperCase()),
              const Icon(mt.Icons.arrow_forward_ios_rounded),
            ],
          );
        },
      ),
    );
  }

  (int, int) _getPageInfo(BuildContext context, ModBrowserState state) {
    var page = 0;
    var totalPages = 0;

    if (state is ModBrowserLoaded) {
      page = state.page;
      totalPages = state.totalPages;
    } else if (state is ModBrowserLoading) {
      page = state.page;
      totalPages = state.totalPages;
    }

    final searchState = context.watch<ModSearchCubit>().state;
    if (searchState is! SearchInitial) {
      return (1, 1);
    }

    return (page, totalPages);
  }

  void _handlePageChange(BuildContext context, int value) {
    final cubit = context.read<ModBrowserCubit>();
    if (value == 0) {
      cubit.previousPage();
    } else if (value == 2) {
      cubit.nextPage();
    }
  }
}

class _ModsFilterDropdown extends StatelessWidget {
  const _ModsFilterDropdown({required this.onSearchChanged});

  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ModsListCubit>();
    return KyberSearchFilterDropdown(
      dropdownContent: BlocBuilder<ModsListCubit, ModsListState>(
        builder: (context, state) {
          return SuperListView(
            children: [
              KyberFilterSection<ModScope>(
                title: 'MOD SCOPE',
                selectedItems: [state.filter.scope],
                items: toSelectorItems(
                  ModScope.values,
                  title: (e) => e.name,
                ),
                onChanged: (selected) {
                  cubit.setFilter(
                    cubit.filter.copyWith(scope: selected.firstOrNull),
                  );
                },
              ),
            ],
          );
        },
      ),
      onSearchChanged: onSearchChanged,
    );
  }
}
