import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:tinycolor2/tinycolor2.dart';

class KyberTooltip extends StatelessWidget {
  const KyberTooltip({required this.child, required this.message, super.key});

  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      style: TooltipThemeData(
        decoration: BoxDecoration(
          border: .all(
            color: decoColor.darken(5),
          ),
          color: Colors.black.withOpacity(0.95),
          borderRadius: .circular(2),
        ),
        textStyle: const TextStyle(
          color: kWhiteColor,
          fontSize: 14,
          fontFamily: FontFamily.battlefrontUI,
        ),
        padding: const .symmetric(horizontal: 8, vertical: 4),
      ),
      child: child,
    );
  }
}
