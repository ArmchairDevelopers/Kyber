import 'package:background_downloader/background_downloader.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class ServerDownloadProgress extends StatefulWidget {
  const ServerDownloadProgress({super.key});

  @override
  State<ServerDownloadProgress> createState() => _ServerDownloadProgressState();
}

class _ServerDownloadProgressState extends State<ServerDownloadProgress> {
  @override
  void dispose() {
    super.dispose();
  }

  int calcProgress(TaskRecord? activeDownload, int downloadProgress) {
    final selectedServer = context
        .read<ServerBrowserCubit>()
        .state
        .selectedServer;
    final mods = selectedServer!.serverInfo.mods;

    var total = 0;
    for (final mod in mods) {
      total += mod.fileSize.toInt();
    }

    var current = 0;
    for (final mod in mods) {
      if (ModHelper.isInstalled(mod.name, mod.version)) {
        current += mod.fileSize.toInt();
      } else if (activeDownload?.task.displayName == mod.name &&
          downloadProgress > 0) {
        current += mod.fileSize.toInt() * downloadProgress ~/ 100;
      }
    }

    if (current == total) {
      return 100;
    }

    return (current / total * 100).toInt();
  }

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
        final progress = ((progressUpdate?.progress ?? 0) * 100).toInt();

        return RepaintBoundary(
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: <Color>[
                        kActiveColor,
                        Colors.transparent,
                      ],
                      stops: <double>[
                        calcProgress(currentDownload, progress) / 100,
                        calcProgress(currentDownload, progress) / 100,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: BackgroundBlur(
                    child: Container(
                      color: Colors.black,
                      height: 30,
                    ),
                  ),
                ),
              ),
              Positioned(
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      colors: <Color>[
                        Colors.black,
                        kActiveColor,
                      ],
                      stops: <double>[
                        calcProgress(currentDownload, progress) / 100,
                        calcProgress(currentDownload, progress) / 100,
                      ],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.srcIn,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Text(
                      'Downloading & Applying - ${formatBytes(((progressUpdate?.networkSpeed ?? 0) * 1024 * 1024).toInt(), 1)}/s (${calcProgress(currentDownload, progress)}%)'
                          .toUpperCase(),
                      style: const TextStyle(
                        fontFamily: FontFamily.battlefrontUI,
                        color: Colors.white,
                        fontSize: 15,
                        height: 1,
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
