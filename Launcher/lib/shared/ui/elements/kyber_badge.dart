import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';

class KyberBadge extends StatelessWidget {
  const KyberBadge({this.padding, this.text, this.icon, super.key});

  final String? text;
  final Widget? icon;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    assert(text != null || icon != null, 'Badge must have either text or icon');

    return Container(
      padding: padding ?? const .symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: kControlBackgroundColor,
        border: .all(color: kButtonBorder, width: 1.5),
        borderRadius: .circular(4),
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child:
            icon ??
            Text(
              text!,
              maxLines: 1,
              style: const TextStyle(
                fontWeight: .w700,
                fontSize: 12,
                fontFamily: FontFamily.battlefrontUI,
                //height: 1,
                color: kWhiteColor,
                fontFeatures: [
                  .tabularFigures(),
                ],
              ),
            ),
      ),
    );
  }
}
