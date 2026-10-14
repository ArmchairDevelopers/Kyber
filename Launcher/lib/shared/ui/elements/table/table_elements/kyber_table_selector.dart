import 'package:auto_size_text/auto_size_text.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_selector.dart';

class KyberTableSelector<T> extends StatefulWidget {
  const KyberTableSelector({
    required this.items,
    required this.hover,
    super.key,
    this.onChanged,
    this.value,
  });

  final bool hover;
  final T? value;
  final List<KyberSelectorItem<T>> items;
  final ValueChanged<T>? onChanged;

  @override
  State<KyberTableSelector> createState() => _KyberTableSelectorState<T>();
}

class _KyberTableSelectorState<T> extends State<KyberTableSelector<T>> {
  @override
  void initState() {
    super.initState();
  }

  T? get value => widget.value ?? widget.items.firstOrNull?.value;

  @override
  void didChangeDependencies() {
    setState(() {});
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: 1.5708 * 2,
          child: CustomIconButton(
            iconData: FluentIcons.play_solid,
            onPressed: widget.onChanged == null
                ? null
                : () {
                    final nextIndex =
                        widget.items.indexOf(
                          widget.items.firstWhere((x) => x.value == value),
                        ) -
                        1;
                    widget.onChanged!(
                      nextIndex == -1
                          ? widget.items[widget.items.length - 1].value
                          : widget.items[nextIndex].value,
                    );
                  },
          ),
        ),
        Expanded(
          child: Center(
            child: Builder(
              builder: (context) {
                final textWidget = AutoSizeText(
                  value == null
                      ? ''
                      : (widget.items
                                    .where((x) => x.value == value)
                                    .firstOrNull
                                    ?.title ??
                                '')
                            .toUpperCase(),
                  maxFontSize: 20,
                  minFontSize: 10,
                  maxLines: 1,
                  style: FluentTheme.of(context).typography.body!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.onChanged == null
                        ? FluentTheme.of(
                            context,
                          ).typography.body!.color!.withOpacity(.5)
                        : widget.hover
                        ? kActiveColor
                        : null,
                    shadows: widget.hover && widget.onChanged != null
                        ? [
                            Shadow(
                              color: kActiveColor.withOpacity(.5),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                );

                if (widget.items.length < 3) {
                  return textWidget;
                }

                return SizedBox(
                  height: 25,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: textWidget),
                      SizedBox(
                        height: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < widget.items.length; i++)
                              Expanded(
                                child: Container(
                                  height: 5,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color:
                                        i ==
                                            widget.items.indexWhere(
                                              (x) => x.value == value,
                                            )
                                        ? kActiveColor
                                        : kInactiveColor,
                                    boxShadow:
                                        i ==
                                            widget.items.indexWhere(
                                              (x) => x.value == value,
                                            )
                                        ? [
                                            BoxShadow(
                                              color: kActiveColor.withOpacity(
                                                .5,
                                              ),
                                              blurRadius: 5,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        CustomIconButton(
          iconData: FluentIcons.play_solid,
          onPressed: widget.onChanged == null
              ? null
              : () {
                  final nextIndex =
                      widget.items.indexOf(
                        widget.items.firstWhere((x) => x.value == value),
                      ) +
                      1;
                  widget.onChanged!(
                    nextIndex >= widget.items.length
                        ? widget.items.first.value
                        : widget.items[nextIndex].value,
                  );
                },
        ),
      ],
    );
  }
}
