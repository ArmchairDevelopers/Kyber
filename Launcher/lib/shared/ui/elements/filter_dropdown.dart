import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:window_manager/window_manager.dart';

class KyberSearchFilterDropdown extends StatefulWidget {
  const KyberSearchFilterDropdown({
    super.key,
    required this.dropdownContent,
    this.input,
    this.height = 40,
    this.maxHeight = 330,
    this.dropdownAnimationDuration = const Duration(milliseconds: 100),
    this.targetAnimationDuration = const Duration(milliseconds: 150),
    this.curve = Curves.easeOut,
    this.icon,
    this.showChevron = true,
    this.onOpenChanged,
    this.onSearchChanged,
  });

  final Widget dropdownContent;

  final Widget? input;

  final double height;
  final double maxHeight;

  final Duration dropdownAnimationDuration;
  final Duration targetAnimationDuration;
  final Curve curve;

  final Widget? icon;

  final bool showChevron;

  final ValueChanged<bool>? onOpenChanged;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<KyberSearchFilterDropdown> createState() =>
      _KyberSearchFilterDropdownState();
}

class _KyberSearchFilterDropdownState extends State<KyberSearchFilterDropdown>
    with SingleTickerProviderStateMixin {
  bool isOpen = false;

  late final AnimationController _controller;
  late final Animation<double> _animation;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  double? _targetWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.dropdownAnimationDuration,
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggle() => isOpen ? _close() : _open();

  void _open() {
    final ro = context.findRenderObject();
    if (ro is RenderBox) _targetWidth = ro.size.width;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);

    _controller.forward();
    setState(() => isOpen = true);
    widget.onOpenChanged?.call(true);
  }

  void _close() {
    _controller.reverse().then((_) {
      _removeOverlay();
      if (!mounted) return;
      setState(() => isOpen = false);
      widget.onOpenChanged?.call(false);
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;

    return OverlayEntry(
      builder: (_) => GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.translucent,
        child: _KyberFilterDropdownOverlay(
          renderBox: renderBox,
          layerLink: _layerLink,
          animation: _animation,
          width: _targetWidth ?? renderBox.size.width,
          maxHeight: widget.maxHeight,
          content: widget.dropdownContent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final input = widget.input ?? _KyberSearchInput(onChanged: widget.onSearchChanged);

    return CompositedTransformTarget(
      link: _layerLink,
      child: HoverBuilder(
        builder: (context, hovered) {
          return AnimatedContainer(
            height: widget.height,
            duration: widget.targetAnimationDuration,
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
              mainAxisSize: MainAxisSize.min,
              children: [
                ButtonBuilder(
                  onClick: _toggle,
                  builder: (context, hovered) => Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        widget.icon ??
                            Assets.icons.kblFilter.svg(
                              color: hovered ? kActiveColor : Colors.white,
                            ),
                        if (widget.showChevron)
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
                const ContainerSeparatorH(),
                Expanded(child: input),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KyberFilterDropdownOverlay extends StatefulWidget {
  const _KyberFilterDropdownOverlay({
    required this.renderBox,
    required this.layerLink,
    required this.animation,
    required this.width,
    required this.maxHeight,
    required this.content,
  });

  final RenderBox renderBox;
  final LayerLink layerLink;
  final Animation<double> animation;
  final double width;
  final double maxHeight;
  final Widget content;

  @override
  State<_KyberFilterDropdownOverlay> createState() =>
      _KyberFilterDropdownOverlayState();
}

class _KyberFilterDropdownOverlayState extends State<_KyberFilterDropdownOverlay>
    with WindowListener {
  late double width;

  @override
  void initState() {
    super.initState();
    width = widget.width;
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() {
    width = widget.renderBox.size.width;
    if (mounted) setState(() {});
    super.onWindowResize();
  }

  @override
  Widget build(BuildContext context) {
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
                        constraints: BoxConstraints(maxHeight: widget.maxHeight),
                        child: widget.content,
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

class KyberFilterSection<T> extends StatelessWidget {
  const KyberFilterSection({
    super.key,
    required this.title,
    required this.selectedItems,
    required this.items,
    required this.onChanged,
    this.initialExpanded = true,
    this.maxItems = 1,
    this.includeAll = false,
    this.spacing,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  final String title;
  final bool initialExpanded;

  final List<T> selectedItems;
  final List<_SelectorItem<T>> items;
  final ValueChanged<List<T>> onChanged;

  final int? maxItems;
  final bool includeAll;
  final double? spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return KyberSectionDropdown(
      title: title,
      initialExpanded: initialExpanded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardSection(),
          Padding(
            padding: padding,
            child: _FilterSelector<T>(
              selectedItems: selectedItems,
              items: items,
              onChanged: onChanged,
              maxItems: maxItems,
              includeAll: includeAll,
              spacing: spacing,
            ),
          ),
          const CardSection(),
        ],
      ),
    );
  }
}

List<_SelectorItem<T>> toSelectorItems<T>(
    Iterable<T> values, {
      required String Function(T v) title,
    }) {
  return values.map((v) => _SelectorItem<T>(title: title(v), value: v)).toList();
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
    super.key,
  });

  final List<_SelectorItem<T>> items;
  final List<T> selectedItems;
  final void Function(List<T> selectedItems) onChanged;
  final int? maxItems;
  final double? spacing;
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
        if (index == 0) {
          return ButtonBuilder(
            onClick: () {
              if (!includeAll) {
                onChanged([items.first.value]);
              } else {
                onChanged([]);
              }
            },
            builder: (context, hovered) {
              final isAllSelected =
                  selectedItems.isEmpty ||
                      (!includeAll &&
                          items.indexOf(
                            items.firstWhere(
                                  (e) => e.value == selectedItems.first,
                            ),
                          ) ==
                              0);

              return AnimatedContainer(
                duration: kDefaultDuration,
                width: 100,
                height: 25,
                decoration: BoxDecoration(
                  color: hovered
                      ? kActiveColor
                      : isAllSelected
                      ? kWhiteColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: kDefaultDuration,
                  style: TextStyle(
                    color: hovered || isAllSelected ? Colors.black : Colors.white,
                    fontSize: 14,
                    fontFamily: currentFont,
                  ),
                  child: Text(
                    l10n.all,
                    style: TextStyle(
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
              final next = List<T>.from(selectedItems);

              final canAdd =
                  (maxItems == null) || (next.length < (maxItems ?? 0));

              if (selected || canAdd) {
                if (selected) {
                  next.remove(mode.value);
                } else {
                  next.add(mode.value);
                }
                onChanged(next);
              } else {
                next
                  ..clear()
                  ..add(mode.value);
                onChanged(next);
              }
            },
            builder: (context, hovered) {
              final isSelected = selectedItems.contains(mode.value);

              return AnimatedContainer(
                duration: kDefaultDuration,
                width: 100,
                height: 25,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: hovered
                      ? kActiveColor
                      : isSelected
                      ? kWhiteColor
                      : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: kDefaultDuration,
                  style: TextStyle(
                    color: hovered || isSelected ? Colors.black : Colors.white,
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
      itemCount: includeAll ? items.length + 1 : items.length,
    );
  }
}

class _KyberSearchInput extends StatelessWidget {
  const _KyberSearchInput({this.onChanged});

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return mt.TextFormField(
      style: mt.TextStyle(
        fontFamily: currentFont,
        fontSize: 15,
        height: 1,
      ),
      decoration: mt.InputDecoration(
        isDense: true,
        border: mt.InputBorder.none,
        enabledBorder: mt.InputBorder.none,
        focusedBorder: mt.InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0.5),
        hintText: l10n.searchHint,
        hintStyle: TextStyle(
          color: kInactiveColor,
          fontFamily: currentFont,
          fontSize: 15,
          height: 1,
        ),
      ),
      onChanged: onChanged,
    );
  }
}