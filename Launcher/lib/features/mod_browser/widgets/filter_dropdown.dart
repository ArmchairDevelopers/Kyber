import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_browser_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_search_dropdown.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_dropdown.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:kyber_launcher/shared/ui/utils/hover_builder.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:window_manager/window_manager.dart';

class ModBrowserFilterDropdown extends StatefulWidget {
  const ModBrowserFilterDropdown({
    super.key,
  });

  @override
  _ModBrowserFilterDropdownState createState() =>
      _ModBrowserFilterDropdownState();
}

class _ModBrowserFilterDropdownState extends State<ModBrowserFilterDropdown>
    with SingleTickerProviderStateMixin {
  bool isOpen = false;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final LayerLink _layerLink = LayerLink();
  double? width;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleDropdown() {
    if (isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    setState(() {
      width = (context.findRenderObject()! as RenderBox).size.width;
      isOpen = true;
    });
  }

  void _closeDropdown() {
    _animationController.reverse().then((value) {
      _removeOverlay();
      setState(() {
        isOpen = false;
      });
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _closeDropdown,
        behavior: HitTestBehavior.translucent,
        child: _FilterDropdown(
          renderBox: renderBox,
          animation: _animation,
          layerLink: _layerLink,
          width: width ?? renderBox.size.width,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: HoverBuilder(
        builder: (context, hovered) {
          return AnimatedContainer(
            height: 40,
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: mt.Colors.black38,
              border: Border.all(
                color: hovered ? kActiveColor : kDefaultBorder.color,
                width: kDefaultBorder.width,
              ),
              borderRadius: !isOpen
                  ? BorderRadius.circular(kDefaultInnerBorderRadius)
                  : const BorderRadius.vertical(
                      top: Radius.circular(kDefaultInnerBorderRadius),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                ButtonBuilder(
                  onClick: _toggleDropdown,
                  builder: (context, hovered) => Container(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          Assets.icons.kblFilter.svg(
                            color: hovered ? kActiveColor : Colors.white,
                          ),
                          Icon(
                            isOpen
                                ? mt.Icons.keyboard_arrow_up_rounded
                                : mt.Icons.keyboard_arrow_down_rounded,
                            color: hovered ? kActiveColor : Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const ContainerSeparatorH(),
                Expanded(
                  key: filterDropdownKey,
                  child: const ModSearchDropdown(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FilterDropdown extends StatefulWidget {
  const _FilterDropdown({
    required this.renderBox,
    required this.width,
    required this.animation,
    required this.layerLink,
  });

  final double width;
  final RenderBox renderBox;
  final Animation<double> animation;

  final LayerLink layerLink;

  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> with WindowListener {
  late double width;

  @override
  void initState() {
    width = widget.width;
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() {
    width = widget.renderBox.size.width;
    setState(() {});
    super.onWindowResize();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    final size = widget.renderBox.size;
    final position = widget.renderBox.localToGlobal(Offset.zero);
    return Stack(
      clipBehavior: Clip.antiAlias,
      children: [
        Positioned(
          width: width,
          left: position.dx,
          top: size.height + 20,
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(kDefaultInnerBorderRadius),
              ),
              child: BackgroundBlur(
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: kDefaultBorder,
                      left: kDefaultBorder,
                      right: kDefaultBorder,
                    ),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(kDefaultInnerBorderRadius),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(kDefaultInnerBorderRadius - 2),
                    ),
                    child: SizeTransition(
                      sizeFactor: widget.animation,
                      axisAlignment: 1,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: 330,
                        ),
                        child: BlocBuilder<ModBrowserCubit, ModBrowserState>(
                          builder: (context, state) {
                            final cubit = BlocProvider.of<ModBrowserCubit>(
                              context,
                            );
                            return SuperListView(
                              children: [
                                KyberSectionDropdown(
                                  title: l10n.sortByTitle,
                                  initialExpanded: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CardSection(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        child: _FilterSelector<SortBy>(
                                          removeAll: true,
                                          spacing: 125,
                                          selectedItems: [cubit.currentSortBy],
                                          items: SortBy.values
                                              .map(
                                                (e) => _SelectorItem(
                                                  title: e.name,
                                                  value: e,
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (selectedItems) {
                                            cubit.changeSortBy(
                                              selectedItems.first,
                                            );
                                          },
                                        ),
                                      ),
                                      const CardSection(),
                                    ],
                                  ),
                                ),
                                KyberSectionDropdown(
                                  title: l10n.timeFilterTitle,
                                  initialExpanded: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CardSection(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        child: _FilterSelector<int>(
                                          selectedItems: [
                                            context
                                                .read<ModBrowserCubit>()
                                                .timeFilter,
                                          ],
                                          items: [1, 7, 14, 30, 365, 0].reversed
                                              .map((e) {
                                                var text = l10n.allTime;
                                                if (e == 365) {
                                                  text = l10n.oneYear;
                                                } else if (e == 30) {
                                                  text = l10n.oneMonth;
                                                } else if (e == 14) {
                                                  text = l10n.twoWeeks;
                                                } else if (e == 7) {
                                                  text = l10n.oneWeek;
                                                } else if (e == 1) {
                                                  text = l10n.oneDay;
                                                }

                                                return _SelectorItem(
                                                  title: text,
                                                  value: e,
                                                );
                                              })
                                              .toList(),
                                          onChanged: (selectedItems) {
                                            context
                                                .read<ModBrowserCubit>()
                                                .setTimeFilter(
                                                  selectedItems.first,
                                                );
                                          },
                                        ),
                                      ),
                                      const CardSection(),
                                    ],
                                  ),
                                ),
                                // items per page 20, 30, 40
                                KyberSectionDropdown(
                                  title: l10n.itemsPerPageTitle,
                                  initialExpanded: true,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const CardSection(),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        child: _FilterSelector<int>(
                                          removeAll: true,
                                          selectedItems: [cubit.perPage],
                                          items: [20, 30, 40]
                                              .map(
                                                (e) => _SelectorItem(
                                                  title: e.toString(),
                                                  value: e,
                                                ),
                                              )
                                              .toList(),
                                          onChanged: (selectedItems) {
                                            cubit.setPerPage(
                                              selectedItems.first,
                                            );
                                          },
                                        ),
                                      ),
                                      const CardSection(),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectorItem<T> {
  const _SelectorItem({required this.title, required this.value});

  final String title;
  final T value;
}

class _FilterSelector<T> extends StatelessWidget {
  const _FilterSelector({
    required this.selectedItems,
    required this.items,
    required this.onChanged,
    this.maxItems = 1,
    this.spacing,
    this.includeAll = false,
    this.removeAll = false,
    super.key,
  });

  final List<_SelectorItem<T>> items;
  final List<T> selectedItems;
  final void Function(List<T> selectedItems) onChanged;
  final int? maxItems;
  final double? spacing;
  final bool removeAll;
  final bool includeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: mt.SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: spacing ?? 100,
        childAspectRatio: 3,
        mainAxisExtent: 25,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        if (index == 0 && !removeAll) {
          return ButtonBuilder(
            onClick: () {
              if (!includeAll) {
                onChanged([items.first.value]);
              } else {
                onChanged([]);
              }
            },
            builder: (context, hovered) {
              return AnimatedContainer(
                duration: kDefaultDuration,
                width: 100,
                height: 25,
                decoration: BoxDecoration(
                  color: hovered
                      ? kActiveColor
                      : selectedItems.isEmpty ||
                            !includeAll &&
                                items.indexOf(
                                      items.firstWhere(
                                        (e) => e.value == selectedItems.first,
                                      ),
                                    ) ==
                                    0
                      ? kWhiteColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: kDefaultDuration,
                  style: TextStyle(
                    color:
                        hovered ||
                            selectedItems.isEmpty ||
                            !includeAll &&
                                items.indexOf(
                                      items.firstWhere(
                                        (e) => e.value == selectedItems.first,
                                      ),
                                    ) ==
                                    0
                        ? Colors.black
                        : Colors.white,
                    fontSize: 14,
                    fontFamily: currentFont,
                  ),
                  child: Text(
                    l10n.all,
                    style: TextStyle(
                      color:
                          hovered ||
                              selectedItems.isEmpty ||
                              !includeAll &&
                                  items.indexOf(
                                        items.firstWhere(
                                          (e) => e.value == selectedItems.first,
                                        ),
                                      ) ==
                                      0
                          ? Colors.black
                          : Colors.white,
                      fontSize: 14,
                      fontFamily: currentFont,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
          );
        } else {
          final mode = items.elementAt(includeAll ? index - 1 : index);
          return ButtonBuilder(
            onClick: () {
              final selected = selectedItems.contains(mode.value);
              final items = List<T>.from(selectedItems);
              if ((maxItems != null && items.length < maxItems! ||
                      maxItems == null) ||
                  selected) {
                if (selected) {
                  items.remove(mode.value);
                } else {
                  items.add(mode.value);
                }

                onChanged(items);
              } else {
                items
                  ..clear()
                  ..add(mode.value);

                onChanged(items);
              }
            },
            builder: (context, hovered) {
              return AnimatedContainer(
                duration: kDefaultDuration,
                width: 100,
                height: 25,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: hovered
                      ? kActiveColor
                      : selectedItems.contains(mode.value)
                      ? kWhiteColor
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: kDefaultDuration,
                  style: TextStyle(
                    color: hovered || selectedItems.contains(mode.value)
                        ? Colors.black
                        : Colors.white,
                    fontSize: 14,
                    fontFamily: currentFont,
                  ),
                  child: Text(
                    mode.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              );
            },
          );
        }
      },
      itemCount: includeAll && !removeAll ? items.length + 1 : items.length,
    );
  }
}