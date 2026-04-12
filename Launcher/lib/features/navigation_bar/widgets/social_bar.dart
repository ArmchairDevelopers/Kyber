import 'package:fluent_ui/fluent_ui.dart' hide Button;
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_friends_dialog.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class SocialBar extends StatefulWidget {
  const SocialBar({super.key});

  @override
  State<SocialBar> createState() => _SocialBarState();
}

class _SocialBarState extends State<SocialBar> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(left: 35, right: 20),
      child: FractionallySizedBox(
        widthFactor: 1 / 3,
        alignment: .centerRight,
        child: SizedBox(
          height: 45,
          child: BackgroundBlur(
            child: Container(
              decoration: const BoxDecoration(
                border: .symmetric(vertical: kDefaultBorder),
              ),
              padding: const .symmetric(horizontal: 15, vertical: 4),
              alignment: .center,
              child: Row(
                spacing: 15,
                children: [
                  Button(
                    onPressed: () => showKyberDialog(
                      context: context,
                      builder: (_) => const MaximaFriendsDialog(),
                    ),
                    child: const Icon(mt.Icons.group),
                  ),
                  const VCardSection(),
                  const Flexible(child: _FriendsBar()),
                  const VCardSection(),
                  const _DownloadManagerButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadManagerButton extends StatelessWidget {
  const _DownloadManagerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final downloadManagerState = context.watch<DownloadCubit>().state;

    final isDownloadActive =
        downloadManagerState is DownloadLoaded &&
        downloadManagerState.activeTasks.isNotEmpty;

    if (isDownloadActive) {
      return buildBigDownloadButton(state: downloadManagerState);
    }

    return buildSmallDownloadButton();
  }

  Widget buildSmallDownloadButton() {
    return Button(
      onPressed: () => router.push('/downloads/overview'),
      child: const Icon(mt.Icons.download),
    );
  }

  Widget buildBigDownloadButton({required DownloadLoaded state}) {
    final progress = switch (state.progressUpdate) {
      null => state.currentDownload?.progress ?? 1.0,
      final update => update.progress,
    };
    final progressText = '${(progress * 100).toStringAsFixed(1)}%';

    final expectedSize = switch (state.progressUpdate) {
      null => state.currentDownload?.expectedFileSize ?? 0,
      final update => update.expectedFileSize,
    };
    final expectedSizeText = formatBytes(expectedSize, 1);

    final currentSize = (expectedSize * progress).toInt();
    final currentSizeText = formatBytes(currentSize, 1);

    return BackgroundBlur(
      borderRadius: const .all(.circular(6)),
      child: ButtonBuilder(
        onClick: () => router.push('/downloads/overview'),
        builder: (context, hovered) {
          final itemColor = switch (hovered) {
            true => kActiveColor,
            false => const Color(0xFFD9D9D9),
          };

          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9).withOpacity(.1),
              border: .all(
                color: hovered ? kActiveColor : const Color(0xFF5C5C5C),
                width: 1.5,
              ),
              borderRadius: const .all(.circular(6)),
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      Flexible(
                        child: AnimatedFractionallySizedBox(
                          duration: const .new(milliseconds: 200),
                          widthFactor: progress,
                          child: Container(
                            decoration: BoxDecoration(
                              color: kActiveColor,
                              borderRadius: const .vertical(
                                bottom: .circular(4),
                              ),
                            ),
                            height: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconTheme(
                  data: .new(
                    color: itemColor,
                  ),
                  child: DefaultTextStyle(
                    style: .new(color: itemColor),
                    child: Padding(
                      padding: const .symmetric(vertical: 6, horizontal: 16),
                      child: Row(
                        spacing: 15,
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          const Icon(mt.Icons.download),
                          Text(
                            '$progressText ($currentSizeText / $expectedSizeText)',
                            style: const .new(
                              fontSize: 14,
                              fontFamily: FontFamily.battlefrontUI,
                              fontFeatures: [.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FriendsBar extends StatelessWidget {
  const _FriendsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaximaRtmCubit, MaximaRtmState>(
      builder: (context, state) {
        final friends = state.getSortedPlayers();

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxItems = ((constraints.maxWidth - 15) / 45).floor();
            final displayedFriends = friends.take(maxItems).toList();

            return Row(
              spacing: 10,
              children: [
                for (final friend in displayedFriends)
                  Container(
                    decoration: const BoxDecoration(
                      border: kDefaultAllBorder,
                      borderRadius: .all(.circular(3)),
                    ),
                    clipBehavior: .antiAliasWithSaveLayer,
                    child: MaximaAvatar(pd: friend.pd, height: 33, width: 33),
                  ),
                if (friends.length > maxItems)
                  Text(
                    '+${friends.length - maxItems}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kInactiveColor,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
