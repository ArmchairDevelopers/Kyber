import 'package:background_downloader/background_downloader.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_friends_dialog.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/reports.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';

class MaximaNavigationBarWidget extends StatefulWidget {
  const MaximaNavigationBarWidget({super.key});

  @override
  State<MaximaNavigationBarWidget> createState() =>
      _MaximaNavigationBarWidgetState();
}

class _MaximaNavigationBarWidgetState extends State<MaximaNavigationBarWidget> {
  int hoveredItem = -1;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaximaCubit, MaximaState>(
      buildWhen: (previous, current) {
        return previous.status != current.status;
      },
      builder: (context, state) {
        if (state.status != MaximaStatus.loaded || !state.loggedIn) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            children: [
              BlocBuilder<KyberStatusCubit, KyberStatusState>(
                builder: (context, state) {
                  if (state is! KyberStatusPlaying) {
                    return const SizedBox.shrink();
                  }

                  return Row(
                    children: [
                      SizedBox(
                        height: 30,
                        width: 2,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: hoveredItem == 0
                                ? kActiveColor
                                : kWhiteColor,
                          ),
                        ),
                      ),
                      ButtonBuilder(
                        onEvent: (hovered) {
                          setState(() => hoveredItem = hovered ? 0 : -1);
                        },
                        onClick: () => router.push('/ingame'),
                        builder: (_, hovered) => SizedBox(
                          height: 30,
                          child: Row(
                            children: [
                              SizedBox(
                                height: 30,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.1),
                                  ),
                                  child: RepaintBoundary(
                                    child: Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        style: TextStyle(
                                          fontFamily: FontFamily.battlefrontUI,
                                          color: hovered
                                              ? kActiveColor
                                              : Colors.white,
                                        ),
                                        child: Row(
                                          spacing: 7.5,
                                          children: [
                                            const Icon(FluentIcons.game),
                                            // when a user clicks on it a page opens with a list of all ingame users and an event chat
                                            Text('INGAME PANEL'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (context.read<MaximaCubit>().state.isEntitled(
                UserEntitlement.staff,
              )) ...[
                SizedBox(
                  height: 30,
                  width: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: hoveredItem == 10 || hoveredItem == 0
                          ? kActiveColor
                          : kWhiteColor,
                    ),
                  ),
                ),
                ButtonBuilder(
                  onEvent: (hovered) {
                    setState(() => hoveredItem = hovered ? 10 : -1);
                  },
                  onClick: () => router.push('/staff/reports'),
                  builder: (_, hovered) => SizedBox(
                    height: 30,
                    child: Row(
                      children: [
                        SizedBox(
                          height: 30,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.1),
                            ),
                            child: RepaintBoundary(
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(
                                    milliseconds: 150,
                                  ),
                                  style: TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    color: hovered
                                        ? kActiveColor
                                        : Colors.white,
                                  ),
                                  child: const Reports(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              ButtonBuilder(
                onEvent: (hovered) {
                  setState(() => hoveredItem = hovered ? 1 : -1);
                },
                onClick: () {
                  if (!Preferences.general.setup) {
                    return;
                  }

                  if (router
                          .routerDelegate
                          .currentConfiguration
                          .last
                          .matchedLocation ==
                      '/downloads/overview') {
                    return;
                  }

                  router.push('/downloads/overview');
                },
                builder: (_, hovered) => _DownloadItem(
                  hovered: hovered,
                  hoveredItem: hoveredItem,
                ),
              ),
              SizedBox(
                height: 30,
                width: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: hoveredItem == 1 || hoveredItem == 2
                        ? kActiveColor
                        : kWhiteColor,
                  ),
                ),
              ),
              ButtonBuilder(
                onEvent: (hovered) {
                  setState(() => hoveredItem = hovered ? 2 : -1);
                },
                onClick: () {
                  router.go('/social');
                  return;
                  showKyberDialog(
                    context: context,
                    builder: (_) => const MaximaFriendsDialog(),
                  );
                },
                builder: (_, hovered) => SizedBox(
                  height: 30,
                  child: Row(
                    children: [
                      SizedBox(
                        height: 30,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.1),
                          ),
                          child: RepaintBoundary(
                            child: Center(
                              child: Row(
                                children: [
                                  if (context
                                          .read<MaximaCubit>()
                                          .state
                                          .servicePlayer
                                          ?.avatar !=
                                      null)
                                    Image.network(
                                      context
                                          .read<MaximaCubit>()
                                          .state
                                          .servicePlayer!
                                          .avatar!
                                          .small
                                          .path,
                                      width: 20,
                                      height: 20,
                                    ),
                                  if (context
                                          .read<MaximaCubit>()
                                          .state
                                          .servicePlayer
                                          ?.avatar ==
                                      null)
                                    Assets.images.usericonTmp.image(
                                      height: 20,
                                      width: 20,
                                    ),
                                  const SizedBox(width: 5),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(
                                      milliseconds: 150,
                                    ),
                                    style: TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      color: hovered
                                          ? kActiveColor
                                          : Colors.white,
                                    ),
                                    child: Text(
                                      '${context.read<MaximaCubit>().state.servicePlayer?.displayName}',
                                      style: const TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 30,
                        width: 2,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: hovered ? kActiveColor : kWhiteColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DownloadItem extends StatelessWidget {
  const _DownloadItem({
    required this.hovered,
    required this.hoveredItem,
    super.key,
  });

  final int hoveredItem;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        final currentDownload = state is DownloadLoaded
            ? state.currentDownload
            : null;
        final progressUpdate = state is DownloadLoaded
            ? state.progressUpdate
            : null;
        final extractingProgress = state is DownloadLoaded
            ? state.extractionProgressUpdate
            : null;
        return SizedBox(
          height: 30,
          child: Row(
            children: [
              SizedBox(
                height: 30,
                width: 2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color:
                        hoveredItem ==
                                (context.read<MaximaCubit>().state.isEntitled(
                                      UserEntitlement.staff,
                                    )
                                    ? 10
                                    : 0) ||
                            hoveredItem == 1
                        ? kActiveColor
                        : kWhiteColor,
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                width: currentDownload != null ? 280 : 180,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.1),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontFamily: FontFamily.battlefrontUI,
                      color: hovered ? kActiveColor : Colors.white,
                    ),
                    child: RepaintBoundary(
                      child: Center(
                        child: Builder(
                          builder: (context) {
                            if (currentDownload != null) {
                              var progress =
                                  progressUpdate?.progress ??
                                  currentDownload.progress;
                              final expectedFileSize =
                                  progressUpdate?.expectedFileSize ?? 0;
                              final xProgress = progress >= 1 ? 1.0 : progress;
                              late String displayText;
                              if (xProgress >= 1 &&
                                  extractingProgress != null) {
                                progress = extractingProgress.total > 0
                                    ? (extractingProgress.extracted /
                                          extractingProgress.total)
                                    : 1.0;

                                final extracted = extractingProgress.extracted;
                                final total = extractingProgress.total;
                                if (extractingProgress.total == 1) {
                                  displayText = 'FINALIZING COLLECTION';
                                } else {
                                  if (currentDownload.task is CallbackTask) {
                                    displayText =
                                        'COPYING FILES ($extracted/$total)';
                                  } else {
                                    displayText =
                                        'EXTRACTING FILE ($extracted/$total)';
                                  }
                                }
                              } else if (xProgress >= 1) {
                                if (currentDownload.task is CallbackTask) {
                                  displayText = 'INITIALIZING DOWNLOAD';
                                } else {
                                  displayText = 'EXTRACTING FILE';
                                }
                              } else {
                                displayText =
                                    'DOWNLOADING (${(progress * 100).toInt()}% ${formatBytes((expectedFileSize * progress).toInt(), 1)}/${formatBytes(expectedFileSize, 1)})';
                              }
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        spacing: 6,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          if (xProgress >= 1)
                                            const SizedBox(
                                              width: 15,
                                              height: 15,
                                              child: ProgressRing(
                                                strokeWidth: 3,
                                              ),
                                            )
                                          else
                                            const Icon(
                                              FluentIcons.download,
                                              color: kWhiteColor,
                                              size: 15,
                                            ),
                                          Text(
                                            displayText,
                                            style: const TextStyle(
                                              fontFamily:
                                                  FontFamily.battlefrontUI,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            kActiveColor,
                                            Colors.transparent,
                                          ],
                                          stops: [
                                            progress,
                                            progress,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            return const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 6,
                              children: [
                                Icon(
                                  FluentIcons.download,
                                  color: kWhiteColor,
                                  size: 15,
                                ),
                                Text(
                                  'DOWNLOAD MANAGER',
                                  style: TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
