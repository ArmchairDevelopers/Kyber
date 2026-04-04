import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:vector_graphics/vector_graphics.dart';

class InteractiveButton extends StatefulWidget {
  const InteractiveButton({required this.child, required this.onPressed, super.key});

  final VoidCallback onPressed;
  final Widget child;

  @override
  State<InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<InteractiveButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final target = hovered ? kActiveColor : kWhiteColor;

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Stack(
          children: [
            VectorGraphic(
              loader: AssetBytesLoader(Assets.icons.kblPlayIcon.path),
              height: 47,
              width: 208,
            ),
            VectorGraphic(
              loader: AssetBytesLoader(Assets.icons.kblPlayIconBorder.path),
              height: 47,
              width: 208,
              colorFilter: .mode(
                target,
                BlendMode.srcIn,
              ),
            ),
            Positioned(
              top: 12,
              left: 72,
              child: AnimatedDefaultTextStyle(
                duration: const .new(milliseconds: 150),
                style: TextStyle(
                  color: target,
                  fontSize: 24,
                  fontWeight: .bold,
                  height: 1,
                  shadows: hovered
                      ? [
                    Shadow(
                      color: kActiveColor.withOpacity(.7),
                      blurRadius: 10,
                    ),
                  ]
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}