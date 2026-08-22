import 'package:auto_size_text/auto_size_text.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';

class KyberPageSelector extends StatelessWidget {
  const KyberPageSelector({
    required this.current,
    required this.total,
    required this.onPageChanged,
    this.tinted = false,
    super.key,
  });

  final int current;
  final int total;
  final ValueChanged<int>? onPageChanged;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: .hardEdge,
      decoration: BoxDecoration(
        border: kDefaultAllBorder,
        borderRadius: .circular(kDefaultInnerBorderRadius),
      ),
      child: ClipRRect(
        borderRadius: .circular(kDefaultInnerBorderRadius - 2),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            children: [
              _Arrow(
                isFirst: true,
                onPressed: onPageChanged == null
                    ? null
                    : () => onPageChanged!(current > 1 ? current - 1 : total),
                tinted: tinted,
              ),
              Flexible(
                child: Container(
                  color: kControlBackgroundColor,
                  padding: const .symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  alignment: .center,
                  child: AutoSizeText(
                    '$current/$total',
                    style: const TextStyle(
                      fontFamily: FontFamily.battlefrontUI,
                      fontSize: 13,
                      fontWeight: .bold,
                      height: 1.1,
                      color: kWhiteColor,
                      fontFeatures: [
                        .tabularFigures(),
                      ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              _Arrow(
                isFirst: false,
                tinted: tinted,
                onPressed: onPageChanged == null
                    ? null
                    : () => onPageChanged!(current < total ? current + 1 : 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.isFirst,
    required this.onPressed,
    required this.tinted,
  });

  final bool isFirst;
  final bool tinted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return ButtonBuilder(
      onClick: onPressed,
      builder: (context, hovered) {
        final color = switch (tinted) {
          true => kControlBackgroundColor,
          false => const Color(0xFFD9D9D9).withOpacity(
            !enabled
                ? 0.4
                : hovered
                ? 0.2
                : 0.1,
          ),
        };

        return Container(
          color: color,
          padding: const .symmetric(horizontal: 9, vertical: 5),
          child: Transform.rotate(
            angle: !isFirst ? 0 : 3.14,
            child: Assets.icons.kblPlay.svg(
              height: 12,
              width: 12,
              colorFilter: .mode(
                !enabled
                    ? kWhiteColor1.withOpacity(0.4)
                    : hovered
                    ? kActiveColor
                    : kWhiteColor,
                .srcIn,
              ),
            ),
          ),
        );
      },
    );
  }
}
