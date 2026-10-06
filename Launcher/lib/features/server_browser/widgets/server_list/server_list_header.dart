import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class DashedLineVerticalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double dashHeight = 5;
    const double dashSpace = 5;
    double startY = 4;
    final paint = Paint()
      ..color = decoColor
      ..strokeWidth = size.width;
    final stopY = size.height - 4;
    while (startY < stopY) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
