import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/elements/header/kyber_header.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';

class ServerListHeader extends StatelessWidget {
  const ServerListHeader({super.key, this.withoutQuickJoin = false});

  final bool withoutQuickJoin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          vertical: BorderSide(
            color: decoColor,
            width: 2,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: KyberHeader(
        title: l10n.serverBrowser.toUpperCase(),
        headerLength: 150,
        sections: [
          const ExpandedHeaderSection(children: []),
          FixedWidthHeaderSection(
            width: 99,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.playersHeader,
                textAlign: TextAlign.left,
                style: TextStyle(fontFamily: currentFont),
              ),
            ],
          ),
          FixedWidthHeaderSection(
            width: 120,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.serverType,
                textAlign: TextAlign.left,
                style: TextStyle(fontFamily: currentFont),
              ),
            ],
          ),
          if (!withoutQuickJoin)
            FixedWidthHeaderSection(
              width: 67,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.playButton,
                  style: TextStyle(fontFamily: currentFont),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

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