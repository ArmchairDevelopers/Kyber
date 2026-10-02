import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class BorderedContent extends StatelessWidget {
  const BorderedContent({
    required this.header,
    required this.content,
    this.overlappingBorder = false,
    this.divider = true,
    super.key,
  });

  final Widget header;
  final Widget content;
  final bool overlappingBorder;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: .circular(kDefaultOuterBorderRadius),
      topRight: .circular(kDefaultOuterBorderRadius),
    );

    return Column(
      children: [
        SizedBox(
          height: 65,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackgroundBlur(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: divider
                      ? const .fromBorderSide(kDefaultBorder)
                      : .fromLTRB(
                          top: kDefaultBorder,
                          left: kDefaultBorder,
                          right: kDefaultBorder,
                        ),
                ),
                child: ClipRRect(
                  borderRadius: const .only(
                    topLeft: .circular(
                      kDefaultOuterBorderRadius - 2,
                    ),
                    topRight: .circular(
                      kDefaultOuterBorderRadius - 2,
                    ),
                  ),
                  child: Padding(
                    padding: const .symmetric(
                      vertical: 14,
                      horizontal: 14,
                    ),
                    child: header,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!overlappingBorder)
          Expanded(
            child: ClipRRect(
              borderRadius: const .only(
                bottomLeft: .circular(kDefaultOuterBorderRadius),
                bottomRight: .circular(kDefaultOuterBorderRadius),
              ),
              child: BackgroundBlur(
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      bottomLeft: .circular(kDefaultOuterBorderRadius),
                      bottomRight: .circular(kDefaultOuterBorderRadius),
                    ),
                    border: Border(
                      bottom: kDefaultBorder,
                      left: kDefaultBorder,
                      right: kDefaultBorder,
                    ),
                  ),
                  child: RepaintBoundary(
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        if (overlappingBorder)
          Expanded(
            child: ClipRRect(
              borderRadius: const .vertical(
                bottom: .circular(kDefaultOuterBorderRadius),
              ),
              child: BackgroundBlur(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: .vertical(
                              bottom: .circular(
                                kDefaultOuterBorderRadius,
                              ),
                            ),
                            border: Border(
                              bottom: kDefaultBorder,
                              left: kDefaultBorder,
                              right: kDefaultBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const .vertical(
                          bottom: .circular(
                            kDefaultOuterBorderRadius + 4,
                          ),
                        ),
                        child: RepaintBoundary(
                          child: content,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: .vertical(
                              bottom: .circular(
                                kDefaultOuterBorderRadius,
                              ),
                            ),
                            border: Border(bottom: kDefaultBorder),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
