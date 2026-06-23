import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';

class KyberListItem extends StatelessWidget {
  const KyberListItem({
    required this.index,
    required this.child,
    required this.onTap,
    required this.hovered,
    required this.onHover,
    required this.activeItem,
    required this.scrollDirection,
    this.roundedEnd = false,
    super.key,
    this.padding,
    this.stateless = false,
    this.isLast = false,
    this.defaultTheme = true,
    this.borderRadius,
    this.roundedStart = false,
    this.textStyle,
  });

  final TextStyle? textStyle;
  final bool defaultTheme;
  final bool stateless;
  final int hovered;
  final int activeItem;
  final Axis scrollDirection;
  final double? borderRadius;
  final bool roundedEnd;
  final bool roundedStart;
  final bool isLast;
  final int index;
  final Widget child;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final hover = hovered == index;
    final active = activeItem == index;
    final padding =
        this.padding ??
        (scrollDirection == Axis.horizontal
            ? const EdgeInsets.symmetric(horizontal: 20)
            : const EdgeInsets.symmetric(vertical: 10, horizontal: 20));

    final color = hover
        ? kActiveColor
        : active
        ? kWhiteColor
        : decoColor;
    final textColor = hover
        ? kActiveColor
        : active || stateless
        ? kWhiteColor
        : defaultTheme
        ? kInactiveColor
        : Colors.white;
    final borderSide = BorderSide(
      color: color,
      width: 2,
    );
    final shadows = hover
        ? [
            Shadow(
              color: kActiveColor,
              blurRadius: 10,
            ),
          ]
        : null;

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: Container(
          alignment: .centerLeft,
          decoration: BoxDecoration(
            border: Border(
              top: (index == 0 || scrollDirection == .horizontal)
                  ? borderSide
                  : .none,
              left: (index == 0 || scrollDirection == .vertical)
                  ? borderSide
                  : .none,
              right: (isLast || scrollDirection == .vertical)
                  ? borderSide
                  : .none,
              bottom: (isLast || scrollDirection == Axis.horizontal)
                  ? borderSide
                  : .none,
            ),
            borderRadius: .only(
              topRight: .circular(
                roundedStart && index == 0
                    ? (borderRadius ?? kDefaultOuterBorderRadius)
                    : 0,
              ),
              topLeft: .circular(
                roundedStart && index == 0
                    ? (borderRadius ?? kDefaultOuterBorderRadius)
                    : 0,
              ),
              bottomRight: .circular(
                roundedEnd && isLast
                    ? (borderRadius ?? kDefaultOuterBorderRadius)
                    : 0,
              ),
              bottomLeft: .circular(
                roundedEnd && isLast
                    ? (borderRadius ?? kDefaultOuterBorderRadius)
                    : 0,
              ),
            ),
          ),
          child: Padding(
            padding: padding,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style:
                  textStyle?.copyWith(color: textColor) ??
                  TextStyle(color: textColor),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
