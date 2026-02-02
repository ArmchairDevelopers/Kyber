import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/kyber/dialogs/kyber_anti_virus_exclusion.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_expired_session_dialog.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_game_locator_dialog.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_game_not_found_dialog.dart';
import 'package:kyber_launcher/features/maxima/helper/maxima_helper.dart';
import 'package:kyber_launcher/features/mods/helper/preloaded_mods_helper.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class MaximaStartGameDialog extends StatefulWidget {
  const MaximaStartGameDialog({
    super.key,
    this.gameDataDir,
    this.initializeRequest,
    this.mods,
  });

  final String? gameDataDir;
  final List<FrostyMod>? mods;
  final InitializeRequest? initializeRequest;

  @override
  State<MaximaStartGameDialog> createState() => _MaximaStartGameDialogState();
}

class _MaximaStartGameDialogState extends State<MaximaStartGameDialog> {
  Timer? _gameStatusTimer;
  StreamSubscription<String>? _gameEvents;

  bool updating = false;
  bool preloadingMods = false;
  String? lastEvent;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final available = await ModuleVersionService().updateAvailable(
        module: VersionModule.module,
      );
      if (available) {
        try {
          setState(() => updating = true);

          await ModuleVersionService().updateVersion(
            module: VersionModule.module,
          );

          if (!mounted) {
            return;
          }

          setState(() => updating = false);
        } catch (e, st) {
          if (mounted) {
            setState(() => updating = false);
          }

          final message = switch (e) {
            AnyhowException() => e.message,
            PanicException() => e.message,
            _ => e.toString(),
          };

          Logger.root.severe('Failed to update Kyber Module', e, st);
          await Sentry.captureException(e, stackTrace: st);
          NotificationService.showNotification(
            message: 'Failed to update Kyber Module: $message',
            severity: InfoBarSeverity.error,
          );

          Navigator.of(context).pop();

          return;
        }
      }

      final req = widget.initializeRequest ?? .new();
      if (Preferences.general.enabledPreloadMods) {
        setState(() => preloadingMods = true);
        final preloadedMods = await PreloadedModsHelper.preloadMods();
        if (!mounted) {
          return;
        }

        req.modData = .new(
          mods: req.modData.mods,
          explodedMods: req.modData.explodedMods,
          basePath: req.modData.basePath,
          modPaths: [
            ...req.modData.modPaths,
            ...preloadedMods,
          ],
        );
      }

      await checkService();

      // TODO: figure out why maxima returns 0 for the game pid
      await MaximaHelper.startGame(
            gameDataPath: widget.gameDataDir,
            initializeRequest: widget.initializeRequest,
            mods: widget.mods,
          )
          .then((value) async {
            if (!mounted) {
              return;
            }

            _gameEvents = value.eventStream.listen(
              (e) {
                setState(() => lastEvent = e);

                if ([
                      'IsProgressiveInstallationAvailable',
                      'GetGameInfo',
                      'GetInfo',
                    ].contains(e) &&
                    mounted) {
                  _gameEvents?.cancel();
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
              onDone: () {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              cancelOnError: true,
              onError: (_) {
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
            );
          })
          .onError((error, stackTrace) {
            _gameEvents?.cancel();
            if (error is AnyhowException) {
              if (mounted) {
                Navigator.of(context).pop();
              }

              if (error.message.contains('Game not found')) {
                showKyberDialog(
                  context: navigatorKey.currentContext!,
                  builder: (_) => const MaximaGameNotFoundDialog(),
                );
                return;
              } else if (error.message.contains('Game not installed')) {
                showKyberDialog(
                  context: navigatorKey.currentContext!,
                  builder: (_) => const MaximaGameLocatorDialog(),
                );
                return;
              } else if (error.message.contains('remote io error')) {
                showKyberDialog(
                  context: navigatorKey.currentContext!,
                  builder: (_) => const KyberAntiVirusExclusion(),
                );
                return;
              } else if (error.message.contains('invalid redirect')) {
                showKyberDialog(
                  context: navigatorKey.currentContext!,
                  builder: (_) => const MaximaExpiredSessionDialog(),
                );
              }

              NotificationService.showNotification(
                message: 'Failed to start game: ${error.message}',
                severity: InfoBarSeverity.error,
              );
            } else if (error is PanicException) {
              if (mounted) {
                Navigator.of(context).pop();
              }

              showKyberDialog(
                context: navigatorKey.currentContext!,
                builder: (context) {
                  return KyberContentDialog(
                    title: Text('Failed to start game'.toUpperCase()),
                    content: Text(
                      error.message,
                      style: const TextStyle(
                        fontFamily: FontFamily.battlefrontUI,
                        fontSize: 17,
                      ),
                    ),
                    actions: [
                      KyberButton(
                        onPressed: () => Navigator.of(context).pop(),
                        text: 'Close',
                      ),
                    ],
                  );
                },
              );
            } else {
              NotificationService.showNotification(
                message: 'Failed to start game: $error',
                severity: InfoBarSeverity.error,
              );
            }


            Sentry.captureException(error, stackTrace: stackTrace);
            Logger.root.severe(
              'Failed to start game: $error',
              error,
              stackTrace,
            );
          });
    });
    super.initState();
  }

  @override
  void dispose() {
    _gameEvents?.cancel();
    _gameStatusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('GAME LAUNCHING'.toUpperCase()),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 300),
      content: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 15,
                width: 15,
                child: RepaintBoundary(child: ProgressRing()),
              ),
              const SizedBox(
                width: 15,
              ),
              if (updating)
                Text(
                  'Updating Kyber Module...',
                  style: FluentTheme.of(context).typography.bodyLarge,
                ),
              if (!updating)
                Text(
                  'Starting Game...',
                  style: FluentTheme.of(context).typography.bodyLarge,
                ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            'Please wait while the game is starting. This may take a few seconds.',
            style: FluentTheme.of(context).typography.body?.copyWith(
              color: kWhiteColor,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            lastEvent ?? '',
            style: FluentTheme.of(context).typography.body,
          ),
        ],
      ),
    );
  }
}
