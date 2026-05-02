import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:tinycolor2/tinycolor2.dart';

class KyberButton extends StatefulWidget {
  const KyberButton({
    required String this.text,
    required this.onPressed,
    super.key,
    this.icon,
    this.fontSize,
  }) : child = null,
       highlighted = false,
       padding = null;

  const KyberButton._({
    this.text,
    this.fontSize,
    this.onPressed,
    this.child,
    this.highlighted = false,
    this.padding,
    this.icon,
    super.key,
  });

  factory KyberButton.highlight({
    required void Function()? onPressed,
    Key? key,
    String? text,
    int? fontSize,
  }) {
    return KyberButton._(
      key: key,
      text: text,
      onPressed: onPressed,
      fontSize: fontSize,
      highlighted: true,
    );
  }

  factory KyberButton.withChild({
    required void Function()? onPressed,
    required Widget child,
    int? fontSize,
    Key? key,
    String? text,
    EdgeInsets? padding,
  }) {
    return KyberButton._(
      key: key,
      text: text,
      onPressed: onPressed,
      fontSize: fontSize,
      padding: padding,
      child: child,
    );
  }

  final String? text;
  final int? fontSize;
  final Widget? icon;
  final void Function()? onPressed;
  final EdgeInsets? padding;
  final Widget? child;
  final bool highlighted;

  @override
  State<KyberButton> createState() => _KyberButtonState();
}

class _KyberButtonState extends State<KyberButton>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final FocusNode _focusNode = FocusNode();

  bool hover = false;

  int get animationDuration => widget.highlighted ? 2 : 150;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: animationDuration),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.animateTo(0);

    _focusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void setHover(bool hover) {
    _controller.animateTo(hover ? 1 : 0);
  }

  bool get disabled => widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: FocusBorder(
        style: const FocusThemeData(
          renderOutside: true,
          primaryBorder: BorderSide(
            color: kButtonBorder,
            width: 4,
          ),
        ),
        focused: _focusNode.hasFocus,
        renderOutside: true,
        child: GestureDetector(
          onTap: () {
            if (disabled) {
              return;
            }

            if (widget.onPressed != null) {
              widget.onPressed!();
            }
          },
          child: ClipPath(
            clipper: CurveClipper(),
            child: FocusableActionDetector(
              focusNode: _focusNode,
              onShowFocusHighlight: (v) {
                if (mounted) setState(() {});
              },
              onShowHoverHighlight: (v) {
                if (mounted) setState(() {});
              },
              actions: {
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (ActivateIntent intent) => widget.onPressed!(),
                ),
                ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
                  onInvoke: (ButtonActivateIntent intent) =>
                      widget.onPressed!(),
                ),
              },
              enabled: !disabled,
              child: Semantics(
                button: true,
                enabled: !disabled,
                focusable: !disabled,
                focused: _focusNode.hasFocus,
                child: MouseRegion(
                  onEnter: (event) => setHover(true),
                  onExit: (event) => setHover(false),
                  cursor: disabled
                      ? SystemMouseCursors.forbidden
                      : SystemMouseCursors.click,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: ColoredBox(
                      color: Colors.black.withOpacity(.4),
                      child: CustomPaint(
                        painter: CurvePainter(
                          animation: _animation,
                          disabled: disabled,
                          highlighted: widget.highlighted,
                          hasIcon: widget.icon != null,
                        ),
                        isComplex: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.icon != null) ...[
                              SizedBox(
                                width: 35,
                                child: Center(
                                  child: widget.icon,
                                ),
                              ),
                            ],
                            Center(
                              child: Padding(
                                padding:
                                    widget.padding ??
                                    const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 7,
                                    ).copyWith(
                                      left: widget.icon != null ? 14 : null,
                                      right: 22,
                                    ),
                                child: DefaultTextStyleTransition(
                                  style: TextStyleTween(
                                    begin: TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      color: disabled
                                          ? kInactiveColor.darken(20)
                                          : kWhiteColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize:
                                          widget.fontSize?.toDouble() ?? 16,
                                    ),
                                    end: TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      color: disabled
                                          ? kInactiveColor
                                          : kActiveColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize:
                                          widget.fontSize?.toDouble() ?? 16,
                                      shadows: [
                                        Shadow(
                                          color: kActiveColor.withOpacity(0.5),
                                          blurRadius: 5,
                                        ),
                                      ],
                                    ),
                                  ).animate(_animation),
                                  child:
                                      widget.child ??
                                      Text(
                                        widget.text?.toUpperCase() ?? '',
                                        maxLines: 1,
                                        textAlign: widget.icon == null
                                            ? TextAlign.center
                                            : null,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path_0 = Path()
      ..moveTo(7, 0)
      ..lineTo(size.width - 12.5, 0)
      ..lineTo(size.width, 12.5)
      ..lineTo(size.width, size.height - 7)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - 7,
        size.height,
      )
      ..lineTo(7, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 7)
      ..lineTo(0, 7)
      ..quadraticBezierTo(0, 0, 7, 0)
      ..close();

    return path_0;
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return false;
  }
}

class CurvePainter extends CustomPainter {
  CurvePainter({
    required this.animation,
    required this.disabled,
    required this.highlighted,
    required this.hasIcon,
  }) : super(repaint: animation);
  final Animation<double> animation;
  final bool highlighted;
  final bool hasIcon;
  final bool disabled;

  @override
  void paint(Canvas canvas, Size size) {
    final path_0 = Path()
      ..moveTo(7, 0)
      ..lineTo(size.width - 12.5, 0)
      ..lineTo(size.width, 12.5)
      ..lineTo(size.width, size.height - 7)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - 7,
        size.height,
      )
      ..lineTo(7, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - 7)
      ..lineTo(0, 7)
      ..quadraticBezierTo(0, 0, 7, 0)
      ..close();

    final path_1 = Path()
      ..moveTo(33, 0)
      ..lineTo(33, size.height)
      ..close();

    late Color color;
    if (!highlighted) {
      if (disabled) {
        color = kWhiteBackgroundColor.darken();
      } else {
        color = ColorTween(
          begin: kButtonBorder,
          end: kActiveColor,
        ).evaluate(animation)!;
      }
    } else {
      color = kActiveColor;
    }

    final paintStroke0 = Paint()
      ..color = color
      ..style = .stroke
      ..strokeWidth = highlighted
          ? Tween<double>(begin: 3, end: 5).evaluate(animation)
          : 4
      ..strokeCap = .round
      ..strokeJoin = .round;

    canvas.drawPath(path_0, paintStroke0);
    if (hasIcon) {
      paintStroke0.strokeWidth = 2;
      canvas.drawPath(path_1, paintStroke0);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
