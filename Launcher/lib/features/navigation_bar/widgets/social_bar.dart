import 'package:fluent_ui/fluent_ui.dart' hide Button;
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
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
    return SizedBox(
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          border: .fromLTRB(right: kDefaultBorder),
        ),
        padding: const .symmetric(horizontal: 15),
        alignment: .center,
        child: Row(
          mainAxisAlignment: .end,
          spacing: 15,
          children: [
            const Expanded(flex: 3, child: SizedBox.shrink()),
            const VCardSection(),
            const _UserBar(),
            const SizedBox(width: 0),
            Flexible(
              child: Container(
                constraints: const .new(
                  maxWidth: 300,
                  minWidth: 100,
                ),
                child: const _FriendsBar(),
              ),
            ),
            const VCardSection(),
            CustomIconButton(
              iconData: mt.Icons.settings,
              onPressed: () => null,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBar extends StatelessWidget {
  const _UserBar({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<MaximaCubit>().state.servicePlayer;

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const .symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: const .fromBorderSide(.new(color: decoColor, width: 1)),
        borderRadius: const .all(.circular(6)),
        color: Colors.black.withOpacity(0.5),
      ),
      padding: const .symmetric(horizontal: 3, vertical: 3),
      child: Row(
        spacing: 10,
        children: [
          MaximaAvatar(
            pd: currentUser.pd,
            height: 24,
            width: 24,
          ),
          Text(
            currentUser.displayName,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: FontFamily.battlefrontUI,
              height: 1.1,
            ),
          ),
          const SizedBox.shrink(),
        ],
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
      return buildActiveDownloadButton(state: downloadManagerState);
    }

    return buildDownloadButton();
  }

  Widget buildDownloadButton() {
    return ButtonBuilder(
      onClick: () => router.push('/downloads/overview'),
      builder: (context, hovered) {
        final itemColor = switch (hovered) {
          true => kActiveColor,
          false => const Color(0xFFD9D9D9),
        };

        return Container(
          child: IconTheme(
            data: .new(
              color: itemColor,
            ),
            child: DefaultTextStyle(
              style: .new(
                color: itemColor,
                fontFamily: FontFamily.battlefrontUI,
              ),
              child: const Padding(
                padding: .symmetric(vertical: 4, horizontal: 16),
                child: Row(
                  mainAxisAlignment: .center,
                  children: [
                    Icon(mt.Icons.download),
                    Padding(
                      padding: .symmetric(horizontal: 6),
                      child: Text('DOWNLOADS'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildActiveDownloadButton({required DownloadLoaded state}) {
    final progress = switch (state.progressUpdate) {
      null => state.currentDownload?.progress ?? 1.0,
      final update => update.progress,
    };
    final progressText = '${(progress * 100).toStringAsFixed(0)}%';

    final expectedSize = switch (state.progressUpdate) {
      null => state.currentDownload?.expectedFileSize ?? 0,
      final update => update.expectedFileSize,
    };
    final expectedSizeText = formatBytes(expectedSize, 1);

    final currentSize = (expectedSize * progress).toInt();
    final currentSizeText = formatBytes(currentSize, 1);

    return ButtonBuilder(
      onClick: () => router.push('/downloads/overview'),
      builder: (context, hovered) {
        final itemColor = switch (hovered) {
          true => kActiveColor,
          false => const Color(0xFFD9D9D9),
        };

        return Stack(
          clipBehavior: .antiAliasWithSaveLayer,
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
                      widthFactor: progress >= 0.0 ? progress : 0.01,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kActiveColor,
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
                style: .new(
                  color: itemColor,
                  fontFamily: FontFamily.battlefrontUI,
                ),
                child: Padding(
                  padding: const .symmetric(vertical: 4, horizontal: 16),
                  child: Row(
                    spacing: 5,
                    mainAxisAlignment: .center,
                    children: [
                      const Icon(mt.Icons.download),
                      Text(
                        '$progressText ($currentSizeText / $expectedSizeText)',
                        style: const .new(
                          fontSize: 15,
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
        );
      },
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
            final maxItems = ((constraints.maxWidth - 20) / 40).floor();
            final displayedFriends = friends.take(maxItems).toList();

            return Row(
              mainAxisSize: .min,
              spacing: 10,
              children: [
                for (final friend in displayedFriends)
                  MaximaAvatar(pd: friend.pd, height: 28, width: 28),
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
