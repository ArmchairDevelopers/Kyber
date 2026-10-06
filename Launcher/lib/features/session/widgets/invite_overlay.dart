import 'dart:ui' as ui;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';

class InviteOverlayClipper extends CustomClipper<Path> {
  const InviteOverlayClipper();

  @override
  Path getClip(Size size) {
    final sx = size.width / InviteOverlay.svgSize.width;
    final sy = size.height / InviteOverlay.svgSize.height;

    final path = Path()
      ..moveTo(22.4854 * sx, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(6 * sx, 0)
      ..cubicTo(2.9624 * sx, 0, 0, 2.9624 * sy, 0, 6 * sy)
      ..lineTo(0, 87.5146 * sy)
      ..cubicTo(
        0,
        88.9733 * sy,
        1.0799 * sx,
        90.3719 * sy,
        2.1113 * sx,
        91.4033 * sy,
      )
      ..lineTo(18.5967 * sx, 107.889 * sy)
      ..cubicTo(
        19.6281 * sx,
        108.92 * sy,
        21.0267 * sx,
        size.height,
        22.4854 * sx,
        size.height,
      )
      ..close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class InviteOverlay extends StatelessWidget {
  const InviteOverlay({
    super.key,
    this.width,
    this.height,
    this.blurColorOpacity = 0.5,
    this.blurColor,
    this.child,
  });

  final double? width;
  final double? height;
  final double blurColorOpacity;
  final Color? blurColor;
  final Widget? child;

  static const Size svgSize = Size(314, 110);

  @override
  Widget build(BuildContext context) {
    final w = width ?? svgSize.width;
    final h = height ?? svgSize.height;

    return SizedBox(
      width: w,
      height: h,
      child: ClipPath(
        clipper: const InviteOverlayClipper(),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 6,
            sigmaY: 6,
            tileMode: .decal,
          ),
          child: CustomPaint(
            painter: _InviteBorderPainter(),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _InviteBorderPainter extends CustomPainter {
  _InviteBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / InviteOverlay.svgSize.width;
    final sy = size.height / InviteOverlay.svgSize.height;

    final path = Path()
      ..moveTo(22.4854 * sx, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..lineTo(6 * sx, 0)
      ..cubicTo(2.9624 * sx, 0, 0, 2.9624 * sy, 0, 6 * sy)
      ..lineTo(0, 87.5146 * sy)
      ..cubicTo(
        0,
        88.9733 * sy,
        1.0799 * sx,
        90.3719 * sy,
        2.1113 * sx,
        91.4033 * sy,
      )
      ..lineTo(18.5967 * sx, 107.889 * sy)
      ..cubicTo(
        19.6281 * sx,
        108.92 * sy,
        21.0267 * sx,
        size.height,
        22.4854 * sx,
        size.height,
      )
      ..close();

    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.black.withValues(
            alpha: .4,
          ),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = decoColor
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(_InviteBorderPainter oldDelegate) => false;
}
