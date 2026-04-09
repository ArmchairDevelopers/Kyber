import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:tinycolor2/tinycolor2.dart';

class NormalButton extends StatefulWidget {
  const NormalButton({
    required this.onPressed,
    required this.label,
    super.key,
    this.iconData,
    this.path,
    this.size,
    this.prefix,
  });

  final IconData? iconData;
  final String? path;
  final double? size;
  final Widget label;
  final Widget? prefix;
  final void Function()? onPressed;

  @override
  State<NormalButton> createState() => _NormalButtonState();
}

class _NormalButtonState extends State<NormalButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  bool hover = false;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = (Tween(
      begin: 0.toDouble(),
      end: 1.toDouble(),
    ).animate(_controller)..addListener(() => setState(() {})));
    _controller.animateTo(0);
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void onHover(bool hover) {
    this.hover = hover;
    setState(() {});
    if (hover) {
      _controller.animateTo(1);
    } else {
      _controller.animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: AnimatedContainer(
          height: 38,
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.4),
            border: Border.all(
              color: hover ? kActiveColor : kButtonBorder,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              color: widget.onPressed != null
                  ? hover
                        ? kActiveColor
                        : kWhiteColor
                  : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.prefix != null)
                  widget.prefix!
                else if (widget.path != null)
                  SvgPicture.asset(
                    widget.path!,
                    color: ColorTween(
                      begin: widget.onPressed != null
                          ? kWhiteColor
                          : FluentTheme.of(
                              context,
                            ).typography.title!.color!.darken(70),
                      end: widget.onPressed != null
                          ? kActiveColor
                          : FluentTheme.of(
                              context,
                            ).typography.title!.color!.darken(70),
                    ).animate(_animation).value,
                    height: widget.size ?? 24,
                  )
                else if (widget.iconData != null)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      widget.iconData,
                      size: widget.size ?? 20,
                      color: ColorTween(
                        begin: widget.onPressed != null
                            ? kWhiteColor
                            : FluentTheme.of(
                                context,
                              ).typography.title!.color!.darken(70),
                        end: widget.onPressed != null
                            ? kActiveColor
                            : FluentTheme.of(
                                context,
                              ).typography.title!.color!.darken(70),
                      ).animate(_animation).value,
                      shadows: [
                        if (hover && widget.onPressed != null)
                          BoxShadow(
                            color: kActiveColor.withOpacity(.25),
                            blurRadius: 8,
                            spreadRadius: 4,
                          ),
                      ],
                    ),
                  ),
                if (widget.prefix != null ||
                    widget.path != null ||
                    widget.iconData != null)
                  AnimatedContainer(
                    width: 2,
                    duration: const Duration(milliseconds: 150),
                    color: hover ? kActiveColor : kButtonBorder,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: widget.label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Button extends StatelessWidget {
  const Button({required this.child, required this.onPressed, super.key});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return BackgroundBlur(
      borderRadius: const .all(.circular(6)),
      child: ButtonBuilder(
        onClick: onPressed,
        builder: (context, hovered) {
          final itemColor = switch (hovered) {
            true => kActiveColor,
            false => const Color(0xFFD9D9D9),
          };
      
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9).withOpacity(.1),
              border: .all(
                color: hovered ? kActiveColor : const Color(0xFF5C5C5C),
                width: 1.5,
              ),
              borderRadius: const .all(.circular(6)),
            ),
            child: IconTheme(
              data: .new(
                color: itemColor,
              ),
              child: DefaultTextStyle(
                style: .new(color: itemColor),
                child: Padding(
                  padding: const .symmetric(vertical: 6, horizontal: 16),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
