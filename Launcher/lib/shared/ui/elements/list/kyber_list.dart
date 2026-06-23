import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/shared/ui/elements/list/kyber_list_item.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class KyberList extends StatefulWidget {
  const KyberList({
    required this.itemBuilder,
    required this.itemCount,
    super.key,
    this.shrinkWrap = false,
    this.stateless = false,
    this.scrollDirection = Axis.vertical,
    this.activeIndex,
    this.itemPadding,
    this.onSelectionChanged,
    this.blur = true,
    this.defaultTheme = true,
    this.roundedEnd = false,
    this.borderRadius,
    this.roundedStart = false,
    this.colorOpacity,
    this.physics = const NeverScrollableScrollPhysics(),
  });

  final ScrollPhysics physics;
  final bool defaultTheme;
  final bool blur;
  final bool stateless;
  final bool roundedStart;
  final bool roundedEnd;
  final bool shrinkWrap;
  final EdgeInsets? itemPadding;
  final Axis scrollDirection;
  final double? borderRadius;
  final int? activeIndex;
  final int itemCount;
  final double? colorOpacity;

  final NullableIndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onSelectionChanged;

  @override
  State<KyberList> createState() => _KyberListState();
}

class _KyberListState extends State<KyberList> {
  int? hoveredIndex;
  int? activeIndex = 0;

  int get activeIndexValue => widget.activeIndex ?? activeIndex ?? -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: .vertical(
        bottom: widget.roundedEnd
            ? .circular(widget.borderRadius ?? kDefaultOuterBorderRadius)
            : .zero,
        top: widget.roundedStart
            ? .circular(widget.borderRadius ?? kDefaultOuterBorderRadius)
            : .zero,
      ),
      child: BackgroundBlur(
        blurIntensity: widget.blur ? 6 : 0,
        blurColorOpacity: widget.colorOpacity ?? .4,
        child: RepaintBoundary(
          child: SuperListView.separated(
            physics: widget.physics,
            scrollDirection: widget.scrollDirection,
            padding: .zero,
            itemBuilder: (context, index) {
              return KyberListItem(
                padding: widget.itemPadding,
                scrollDirection: widget.scrollDirection,
                index: index,
                isLast: index == widget.itemCount - 1,
                onTap: () {
                  if (widget.activeIndex == null) {
                    setState(() => activeIndex = index);
                  }
                  widget.onSelectionChanged?.call(index);
                },
                defaultTheme: widget.defaultTheme,
                stateless: widget.stateless,
                activeItem: activeIndexValue,
                hovered: hoveredIndex ?? -1,
                roundedEnd: widget.roundedEnd,
                roundedStart: widget.roundedStart,
                borderRadius: widget.borderRadius,
                onHover: (hover) =>
                    setState(() => hoveredIndex = hover ? index : null),
                child: widget.itemBuilder(context, index) ?? const SizedBox(),
              );
            },
            shrinkWrap: widget.shrinkWrap,
            itemCount: widget.itemCount,
            separatorBuilder: (context, index) {
              return Container(
                width: widget.scrollDirection == Axis.horizontal ? 2 : 0,
                height: widget.scrollDirection == Axis.horizontal ? 0 : 2,
                color: hoveredIndex == index || hoveredIndex == index + 1
                    ? kActiveColor
                    : activeIndexValue == index || activeIndexValue == index + 1
                    ? kWhiteColor
                    : decoColor,
              );
            },
          ),
        ),
      ),
    );
  }
}
