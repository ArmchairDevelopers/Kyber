import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/rich_presence.dart';
import 'package:kyber_launcher/core/utils/custom_logger.dart';
import 'package:kyber_launcher/features/settings/dialogs/debug_logging_warning_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class LogsAndActivity extends StatelessWidget {
  const LogsAndActivity({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HiveListener(
      box: box,
      keys: const ['discordRPC'],
      builder: (bx) => SuperListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(8).copyWith(left: 20),
            child: Text(
              l10n.activity.toUpperCase(),
              style: FluentTheme.of(context).typography.title!.copyWith(
                fontWeight: FontWeight.bold,
                color: kInactiveColor,
                fontFamily: FontFamily.battlefrontUI,
              ),
            ),
          ),
          KyberTable(
            items: [
              KyberTableItem.switchButton(
                title: l10n.discordRichPresence,
                value: Preferences.general.discordRPC,
                onChange: (value) async {
                  Preferences.general.discordRPC = value;
                  if (!value) {
                    sl.get<RichPresence>().clearPresence();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.all(8).copyWith(left: 20),
            child: Text(
              l10n.loggingAndSentry.toUpperCase(),
              style: FluentTheme.of(context).typography.title!.copyWith(
                fontWeight: FontWeight.bold,
                color: kInactiveColor,
                fontFamily: FontFamily.battlefrontUI,
              ),
            ),
          ),
          HiveListener(
            box: box,
            keys: const [
              'sentryOptedOut',
              'frbDebugLogs',
              'moduleDebugLogs',
              'grpcDebugLogs',
            ],
            builder: (_) => KyberTable(
              items: [
                KyberTableItem.button(
                  title: l10n.logs,
                  text: l10n.exportLogs,
                  onClick: () async {
                    await CustomLogger.requestLogExport();
                  },
                ),
                KyberTableItem.button(
                  title: Preferences.general.sentryOptedOut 
                      ? l10n.optInToSentry 
                      : l10n.optOutOfSentry,
                  text: Preferences.general.sentryOptedOut
                      ? l10n.optIn
                      : l10n.optOut,
                  onClick: () async {
                    Preferences.general.sentryOptedOut =
                        !Preferences.general.sentryOptedOut;
                    if (Preferences.general.sentryOptedOut) {
                      await Sentry.close();
                    } else {
                      final info = await PackageInfo.fromPlatform();
                      initSentry(info.version);
                    }
                  },
                ),
                KyberTableItem.switchButton(
                  title: l10n.launcherDebugMode,
                  value: Preferences.debug.frbDebugLogs,
                  onChange: (value) async {
                    if (value) {
                      await showKyberDialog(
                        context: context,
                        builder: (_) => const DebugLoggingWarningDialog(),
                      );
                    }

                    if (!kDebugMode) {
                      PlatformInAppWebViewController
                              .debugLoggingSettings
                              .enabled =
                          value;
                      PlatformInAppWebViewController
                              .debugLoggingSettings
                              .usePrint =
                          value;
                    }

                    Logger.root.info(
                      '${value ? 'Enabled' : 'Disabled'} debug logs',
                    );
                    Logger.root.level = value ? Level.ALL : Level.INFO;
                    Preferences.debug.frbDebugLogs = value;
                    if (!value) {
                      CustomLogger.clearLogFile();
                    }
                  },
                ),
                KyberTableItem.switchButton(
                  title: l10n.moduleDebugMode,
                  value: Preferences.debug.moduleDebugLogs,
                  onChange: (value) async {
                    if (value) {
                      await showKyberDialog(
                        context: context,
                        builder: (_) => const DebugLoggingWarningDialog(),
                      );
                    }

                    Logger.root.info(
                      '${value ? 'Enabled' : 'Disabled'} module debug logs',
                    );
                    Preferences.debug.moduleDebugLogs = value;
                  },
                ),
                KyberTableItem.switchButton(
                  title: l10n.moduleRpcDebugMode,
                  value: Preferences.debug.grpcDebugLogs,
                  onChange: (value) async {
                    if (value) {
                      await showKyberDialog(
                        context: context,
                        builder: (_) => const DebugLoggingWarningDialog(),
                      );
                    }

                    Logger.root.info(
                      '${value ? 'Enabled' : 'Disabled'} module debug logs',
                    );
                    Preferences.debug.grpcDebugLogs = value;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}