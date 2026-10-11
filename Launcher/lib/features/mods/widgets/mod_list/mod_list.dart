import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/mods/helper/frosty_mod_extension.dart';
import 'package:kyber_launcher/features/mods/models/mod_list_group.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/mods/widgets/mod_list/mod_list_entry.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/injection_container.dart';

class ModList extends StatefulWidget {
  const ModList({
    required this.mods,
    required this.onModSelected,
    required this.activeMod,
    required this.onModTap,
    required this.selectedMods,
    this.groups,
    super.key,
  });

  final List<FrostyMod> mods;
  final List<ModListGroup>? groups;
  final FrostyMod? activeMod;
  final Set<String> selectedMods;
  final void Function(FrostyMod mod) onModTap;
  final void Function(FrostyMod mod) onModSelected;

  @override
  State<ModList> createState() => _ModListState();
}

class _ModListState extends State<ModList> {
  int? hoverIndex;
  int? expandedIndex;
  List<FrostyMod> expandedChildren = [];
  final Set<int> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ModList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mods != widget.mods) {
      setState(() {
        hoverIndex = null;
        expandedIndex = null;
        expandedChildren.clear();
      });
    }
  }

  void _toggleGroup(int index) {
    setState(() {
      if (_collapsedGroups.contains(index)) {
        _collapsedGroups.remove(index);
      } else {
        _collapsedGroups.add(index);
      }
    });
  }

  Map<String, List<FrostyMod>> filterByCategory() {
    final mods = widget.mods;
    final filteredMods = <String, List<FrostyMod>>{};
    for (final mod in mods) {
      if (filteredMods.containsKey(mod.details.category)) {
        filteredMods[mod.details.category]!.add(mod);
      } else {
        filteredMods[mod.details.category] = [mod];
      }
    }
    return filteredMods;
  }

  void toggleExpand(int index, FrostyMod mod) {
    setState(() {
      if (expandedIndex == index) {
        expandedIndex = null;
        expandedChildren.clear();
      } else {
        expandedIndex = index;
        expandedChildren = mod.getCollectionMods();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups;
    if (groups != null && groups.isNotEmpty) {
      return _buildGroupedList(groups);
    }
    return _buildFlatList();
  }

  Widget _buildGroupedList(List<ModListGroup> groups) {
    // Build a flat index → (group, modIndexInGroup) mapping
    final flatItems = <({ModListGroup group, int modIndex})>[];
    for (final group in groups) {
      if (group.isNamed && group.mods.length > 1) {
        // Header slot (modIndex = -1)
        flatItems.add((group: group, modIndex: -1));
        if (!_collapsedGroups.contains(flatItems.length - 1)) {
          for (var i = 0; i < group.mods.length; i++) {
            flatItems.add((group: group, modIndex: i));
          }
        }
      } else {
        for (var i = 0; i < group.mods.length; i++) {
          flatItems.add((group: group, modIndex: i));
        }
      }
    }

    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            addAutomaticKeepAlives: false,
            (context, index) {
              final item = flatItems[index];
              if (item.modIndex == -1) {
                return _GroupHeader(
                  group: item.group,
                  collapsed: _collapsedGroups.contains(index),
                  onTap: () => _toggleGroup(index),
                );
              }

              final mod = item.group.mods[item.modIndex];
              final indent = item.group.isNamed && item.group.mods.length > 1;
              return _buildModWithChildren(mod, index, indent: indent);
            },
            childCount: flatItems.length,
          ),
        ),
      ],
    );
  }

  Widget _buildModWithChildren(FrostyMod mod, int idx, {bool indent = false}) {
    final entry = GestureDetector(
      onTap: () => widget.onModTap(mod),
      child: ModListEntry(
        mod: mod,
        selected: widget.selectedMods.contains(mod.filename),
        index: idx,
        isLastSubItem: false,
        hovered: hoverIndex == idx,
        expanded: expandedIndex == idx,
        onSelected: () => widget.onModSelected(mod),
        onExpandCollection: () => toggleExpand(idx, mod),
        onHover: (value) {
          setState(() => hoverIndex = value ? idx : null);
        },
      ),
    );

    if ((expandedIndex == idx && expandedChildren.isNotEmpty) || indent) {
      final children = <Widget>[];
      if (indent) {
        children.add(Padding(padding: const EdgeInsets.only(left: 24), child: entry));
      } else {
        children.add(entry);
      }
      if (expandedIndex == idx && expandedChildren.isNotEmpty) {
        for (var i = 0; i < expandedChildren.length; i++) {
          final child = expandedChildren[i];
          children.add(
            Padding(
              padding: EdgeInsets.only(left: indent ? 24 : 0),
              child: GestureDetector(
                onTap: () => widget.onModTap(child),
                child: ModListEntry(
                  mod: child,
                  selected: widget.selectedMods.contains(child.filename),
                  index: idx + i + 1,
                  isLastSubItem: i == expandedChildren.length - 1,
                  subIndex: i,
                  hovered: hoverIndex == idx + i + 1,
                  expanded: false,
                  onSelected: () => widget.onModSelected(child),
                  onExpandCollection: () {},
                  onHover: (value) {
                    setState(() => hoverIndex = value ? idx + i + 1 : null);
                  },
                ),
              ),
            ),
          );
        }
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }

    return entry;
  }

  Widget _buildFlatList() {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            addAutomaticKeepAlives: false,
            (context, index) {
              if (index == 0) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 2,
                  color: hoverIndex == 0 ? kActiveColor : kWhiteBackgroundColor,
                );
              }

              index--;
              if (expandedIndex != null &&
                  index > expandedIndex! &&
                  index <= expandedIndex! + expandedChildren.length) {
                final childMod = expandedChildren[index - expandedIndex! - 1];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () => widget.onModTap(childMod),
                      child: ModListEntry(
                        onExpandCollection: () => toggleExpand(index, childMod),
                        mod: childMod,
                        selected: widget.selectedMods.contains(
                          childMod.filename,
                        ),
                        index: index,
                        isLastSubItem:
                            index == expandedIndex! + expandedChildren.length,
                        subIndex: index - expandedIndex! - 1,
                        hovered: hoverIndex == index,
                        expanded: false,
                        onSelected: () {
                          widget.onModSelected(childMod);
                        },
                        onHover: (value) {
                          setState(() => hoverIndex = value ? index : null);
                        },
                      ),
                    ),
                    if (index - expandedIndex! == expandedChildren.length)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 2,
                        color: index + 1 == hoverIndex || hoverIndex == index
                            ? kActiveColor
                            : kWhiteBackgroundColor,
                      )
                    else
                      Row(
                        children: [
                          AnimatedContainer(
                            width: 106,
                            duration: const Duration(milliseconds: 150),
                            height: 2,
                            color:
                                index + 1 == hoverIndex || hoverIndex == index
                                ? kActiveColor
                                : kWhiteBackgroundColor,
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 1.5,
                              width: 20,
                              child: CustomPaint(
                                painter: _CustomBorder(
                                  index + 1 == hoverIndex || hoverIndex == index
                                      ? kActiveColor
                                      : kWhiteBackgroundColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              }

              final adjustedIndex =
                  (expandedIndex != null && index > expandedIndex!)
                  ? (index - expandedChildren.length)
                  : index;
              final mod = widget.mods.elementAt(adjustedIndex);

              final child = GestureDetector(
                onTap: () => widget.onModTap(mod),
                child: ModListEntry(
                  onExpandCollection: () => toggleExpand(adjustedIndex, mod),
                  mod: mod,
                  selected: widget.selectedMods.contains(mod.filename),
                  index: adjustedIndex,
                  isLastSubItem: false,
                  hovered: hoverIndex == index,
                  expanded: expandedIndex == adjustedIndex,
                  onSelected: () => widget.onModSelected(mod),
                  subIndex: expandedIndex == index ? -1 : null,
                  onHover: (value) {
                    setState(() => hoverIndex = value ? index : null);
                  },
                ),
              );

              return Column(
                children: [
                  child,
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 2,
                    color: hoverIndex == index + 1 || hoverIndex == index
                        ? kActiveColor
                        : kWhiteBackgroundColor,
                  ),
                ],
              );
            },
            childCount: widget.mods.length + 2 + (expandedChildren.length - 1),
          ),
        ),
      ],
    );
  }
}

class _CustomBorder extends CustomPainter {
  _CustomBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const double dashHeight = 4;
    const double dashSpace = 4;
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    final stopX = size.width;
    while (startX < stopX) {
      canvas.drawLine(
        Offset(startX, 0.75),
        Offset(startX + dashHeight, 0.75),
        paint,
      );
      startX += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.collapsed,
    required this.onTap,
  });

  final ModListGroup group;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[];
    if (group.latestVersion != null) {
      meta.add('Latest: v${group.latestVersion}');
    }
    if (group.lastDownloaded != null) {
      try {
        final dt = DateTime.parse(group.lastDownloaded!);
        meta.add(DateFormat.yMd().format(dt));
      } catch (_) {}
    }

    return ButtonBuilder(
      onClick: onTap,
      builder: (context, hovered) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.03),
            border: Border.symmetric(
              horizontal: BorderSide(
                color: hovered ? kActiveColor : decoColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: SvgPicture.asset(
                  collapsed
                      ? Assets.icons.kblDropdown.path
                      : Assets.icons.kblDropdownFlipped.path,
                  height: 10,
                  width: 10,
                  color: hovered ? kActiveColor : kInactiveColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: group.displayName,
                        style: TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 14,
                          color: kInactiveColor,
                        ),
                      ),
                      TextSpan(
                        text: '  (${group.mods.length} files',
                        style: TextStyle(
                          fontSize: 12,
                          color: FluentTheme.of(context)
                              .typography
                              .bodyLarge
                              ?.color
                              ?.withOpacity(.6),
                        ),
                      ),
                      if (meta.isNotEmpty)
                        TextSpan(
                          text: ' · ${meta.join(' · ')})',
                          style: TextStyle(
                            fontSize: 12,
                            color: FluentTheme.of(context)
                                .typography
                                .bodyLarge
                                ?.color
                                ?.withOpacity(.6),
                          ),
                        )
                      else
                        TextSpan(
                          text: ')',
                          style: TextStyle(
                            fontSize: 12,
                            color: FluentTheme.of(context)
                                .typography
                                .bodyLarge
                                ?.color
                                ?.withOpacity(.6),
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (group.modId != null) ...[
                const SizedBox(width: 4),
                KyberIconButton(
                  onPressed: () {
                    router.go('/mods/mod_browser/${group.modId}');
                  },
                  iconData: mt.Icons.open_in_new,
                  size: 14,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
