import 'package:background_downloader/background_downloader.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/models/download_type.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DownloadManager extends StatefulWidget {
  const DownloadManager({super.key});

  @override
  State<DownloadManager> createState() => _DownloadManagerState();
}

class _DownloadManagerState extends State<DownloadManager> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .all(10),
      child: Row(
        mainAxisAlignment: .center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 550,
              maxHeight: 900,
              maxWidth: 900,
            ),
            child: ClipRRect(
              borderRadius: .circular(kDefaultOuterBorderRadius),
              child: BackgroundBlur(
                child: Container(
                  alignment: .center,
                  decoration: BoxDecoration(
                    borderRadius: .circular(
                      kDefaultOuterBorderRadius,
                    ),
                    border: kDefaultAllBorder,
                  ),
                  child: ClipRRect(
                    borderRadius: .circular(
                      kDefaultOuterBorderRadius - 2,
                    ),
                    child: BlocBuilder<DownloadCubit, DownloadState>(
                      builder: (context, state) {
                        final tasks =
                            state is DownloadLoaded ? state.tasks : <TaskRecord>[];
                        final progressUpdate =
                            state is DownloadLoaded ? state.progressUpdate : null;
                        final currentDownload =
                            state is DownloadLoaded ? state.currentDownload : null;

                        final activeTasks = tasks
                            .where(
                              (e) =>
                                  e.status.isNotFinalState &&
                                  e.status != .paused,
                            )
                            .toList();

                        final pausedTasks = tasks
                            .where((e) => e.status == .paused)
                            .toList();

                        return Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            const _DownloadManagerHeader(),
                            const CardSection(),
                            Expanded(
                              child: Column(
                                children: [
                                  if (activeTasks.isNotEmpty)
                                    _ActiveDownloadsList(
                                      tasks: activeTasks,
                                      progressUpdate: progressUpdate,
                                    ),
                                  if (pausedTasks.isNotEmpty)
                                    _PausedDownloadsSection(tasks: pausedTasks),
                                ],
                              ),
                            ),
                            if (currentDownload != null)
                              _CurrentDownloadFooter(
                                currentDownload: currentDownload,
                                progressUpdate: progressUpdate,
                                tasks: tasks,
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
  }
}

class _DownloadManagerHeader extends StatelessWidget {
  const _DownloadManagerHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                const Text(
                  'DOWNLOAD MANAGER', 
                  style: TextStyle(
                    fontFamily: FontFamily.aurebesh,
                    fontSize: 14,
                    color: kWhiteColor1,
                    height: 1,
                  ),
                ),
                Text(
                  l10n.downloadManager.toUpperCase(),
                  style: TextStyle(
                    fontFamily: currentFont, 
                    fontSize: 24,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          KyberIconButton(
            iconData: FluentIcons.cancel,
            onPressed: router.pop,
          ),
        ],
      ),
    );
  }
}

class _ActiveDownloadsList extends StatelessWidget {
  const _ActiveDownloadsList({
    required this.tasks,
    required this.progressUpdate,
  });

  final List<TaskRecord> tasks;
  final TaskProgressUpdate? progressUpdate;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: ListView.separated(
        separatorBuilder: (context, index) => const CardSection(),
        itemCount: tasks.length + 1,
        itemBuilder: (context, index) {
          if (index >= tasks.length) {
            return const SizedBox.shrink();
          }
          final task = tasks[index];
          return _DownloadTaskItem(
            task: task,
            progressUpdate:
                task.status == TaskStatus.running ? progressUpdate : null,
          );
        },
      ),
    );
  }
}

class _PausedDownloadsSection extends StatelessWidget {
  const _PausedDownloadsSection({required this.tasks});

  final List<TaskRecord> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Text(
            l10n.pausedDownloads.toUpperCase(),
            style: TextStyle(
              fontFamily: currentFont,
              fontSize: 20,
              color: kWhiteColor,
            ),
            textAlign: .left,
          ),
        ),
        const CardSection(),
        Flexible(
          child: ListView.separated(
            separatorBuilder: (context, index) => const CardSection(),
            itemCount: tasks.length + 1,
            itemBuilder: (context, index) {
              if (index >= tasks.length) {
                return const SizedBox.shrink();
              }
              final task = tasks[index];
              return _DownloadTaskItem(task: task, isPaused: true);
            },
          ),
        ),
      ],
    );
  }
}

class _DownloadTaskItem extends StatelessWidget {
  const _DownloadTaskItem({
    required this.task,
    this.progressUpdate,
    this.isPaused = false,
  });

  final TaskRecord task;
  final TaskProgressUpdate? progressUpdate;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ButtonBuilder(
        builder: (context, hovered) {
          return Row(
            children: [
              _buildLeadingIcon(),
              const VCardSection(),
              Expanded(child: _buildTaskInfo(context)),
              if (task.status.isNotFinalState) ...[
                const VCardSection(),
                _buildCancelButton(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildLeadingIcon() {
    if (isPaused || task.status == .paused) {
      return SizedBox(
        width: 50,
        height: 45,
        child: CustomIconButton(
          iconData: FluentIcons.play,
          padding: const EdgeInsets.all(13),
          onPressed: () async {
            await FileDownloader().resume(task.task as DownloadTask);
          },
        ),
      );
    }

    if (task.status == .running) {
      return SizedBox(
        width: 50,
        height: 45,
        child: Icon(
          FluentIcons.download,
          color: kActiveColor,
          size: 25,
        ),
      );
    }

    return const SizedBox(
      width: 50,
      height: 45,
      child: Icon(
        mt.Icons.timelapse,
        color: kWhiteColor,
        size: 25,
      ),
    );
  }

  Widget _buildTaskInfo(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  task.task.displayName,
                  style: TextStyle(
                    fontFamily: currentFont,
                    fontSize: 18,
                    height: 1,
                    color: kWhiteColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (task.status == TaskStatus.running && progressUpdate != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kActiveColor, Colors.transparent],
                  stops: [
                    progressUpdate?.progress ?? 1 / 100,
                    progressUpdate?.progress ?? 1 / 100,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: 50,
      height: 45,
      child: CustomIconButton(
        iconData: FluentIcons.cancel,
        onPressed: () async {
          await FileDownloader().cancelTaskWithId(task.taskId);
        },
      ),
    );
  }
}

class _CurrentDownloadFooter extends StatelessWidget {
  const _CurrentDownloadFooter({
    required this.currentDownload,
    required this.progressUpdate,
    required this.tasks,
  });

  final TaskRecord? currentDownload;
  final TaskProgressUpdate? progressUpdate;
  final List<TaskRecord> tasks;

  bool get _shouldShowPremiumBanner {
    if (currentDownload == null) return false;

    final isNexusDownload = currentDownload!.task.url.contains('nexusmods') ||
        currentDownload!.task.url.contains('nexus-cdn');
    if (!isNexusDownload) return false;

    final isPremium =
        sl.get<NexusModsService>().nexusUser?.isPremium ?? true;

    return isNexusDownload && !isPremium;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_shouldShowPremiumBanner) const _NexusPremiumBanner(),
        const CardSection(),
        _buildProgressSection(),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Container(
      alignment: Alignment.center,
      height: 85,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            _PauseResumeButton(
              currentDownload: currentDownload,
              tasks: tasks,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _DownloadProgressIndicator(
                currentDownload: currentDownload,
                progressUpdate: progressUpdate,
                tasks: tasks,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NexusPremiumBanner extends StatelessWidget {
  const _NexusPremiumBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Center(
      child: Container(
        padding: const EdgeInsets.all(15),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: l10n.unCapSpeedPrefix,
                style: TextStyle(
                  color: kGrayColor,
                  fontFamily: currentFont,
                  fontSize: 16,
                ),
              ),
              TextSpan(
                text: l10n.nexusModsPremium,
                style: TextStyle(
                  color: kActiveColor,
                  fontFamily: currentFont,
                  fontSize: 16,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => launchUrlString(
                        'https://users.nexusmods.com/account/billing/premium',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseResumeButton extends StatelessWidget {
  const _PauseResumeButton({
    required this.currentDownload,
    required this.tasks,
  });

  final TaskRecord? currentDownload;
  final List<TaskRecord> tasks;

  Future<void> _onPressed() async {
    if (currentDownload != null) {
      await FileDownloader().pause(currentDownload!.task as DownloadTask);
    } else {
      final pausedTask = tasks.firstWhere(
        (e) => e.status == TaskStatus.paused,
      );
      await FileDownloader().resume(pausedTask.task as DownloadTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 55,
      child: ClipRRect(
        borderRadius: .circular(100),
        child: ButtonBuilder(
          onClick: _onPressed,
          builder: (context, hovered) {
            return Stack(
              children: [
                Positioned.fill(
                  child: Assets.icons.kblPauseCircle.svg(),
                ),
                Positioned.fill(
                  child: Container(
                    margin: const .all(10),
                    decoration: BoxDecoration(
                      borderRadius: .circular(100),
                      border: .all(
                        color: hovered ? kActiveColor : kWhiteColor,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        currentDownload != null
                            ? mt.Icons.pause
                            : mt.Icons.play_arrow,
                        size: 18,
                        color: hovered ? kActiveColor : kWhiteColor,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DownloadProgressIndicator extends StatelessWidget {
  const _DownloadProgressIndicator({
    required this.currentDownload,
    required this.progressUpdate,
    required this.tasks,
  });

  final TaskRecord? currentDownload;
  final TaskProgressUpdate? progressUpdate;
  final List<TaskRecord> tasks;

  @override
  Widget build(BuildContext context) {
    final download = currentDownload ??
        tasks.firstWhere(
          (e) => e.status == TaskStatus.paused || e.status == TaskStatus.enqueued,
        );
    final size = progressUpdate?.expectedFileSize ?? download.expectedFileSize;
    final progress = progressUpdate?.progress ?? (download.progress) * 100;
    final downloadType = DownloadTypeHelper.getDownloadType(download.task.url);

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildSourceIcon(downloadType),
        _buildProgressBar(progress),
        _buildProgressText(size, progress),
        Positioned.fill(
          child: Assets.icons.kblDownloadProgress.svg(),
        ),
      ],
    );
  }

  Widget _buildSourceIcon(DownloadType downloadType) {
    return Positioned(
      top: 15,
      left: 5,
      child: SizedBox(
        height: 20,
        width: 20,
        child: switch (downloadType) {
          .kyber => Assets.logos.kyberLight.svg(),
          .nexus => Assets.logos.nexusMods.svg(),
          .online => const Icon(
              FluentIcons.globe,
              color: kWhiteColor,
            ),
        },
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Positioned(
      top: 15,
      left: 33,
      right: 229,
      bottom: 20,
      child: AnimatedFractionallySizedBox(
        widthFactor: progress >= 0.0 ? progress : 0.01,
        alignment: Alignment.centerLeft,
        duration: const Duration(milliseconds: 200),
        child: Container(color: kActiveColor),
      ),
    );
  }

  Widget _buildProgressText(int size, double progress) {
    final downloadedBytes = formatBytes((size * progress).toInt(), 1);
    final totalBytes = formatBytes(size, 1);
    final speed = formatBytes(
      (progressUpdate?.networkSpeed.toInt() ?? 0) * 1000000,
      1,
    );
    final percentage = (progress * 100).toInt();

    return Positioned(
      top: 15,
      left: 563,
      right: 5,
      bottom: 19,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            downloadedBytes,
            style: TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 15,
              color: kActiveColor,
            ),
          ),
          Text(
            ' / $totalBytes ($speed/s) $percentage%',
            style: const TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 15,
              color: kWhiteColor,
            ),
          ),
        ],
      ),
    );
  }
}