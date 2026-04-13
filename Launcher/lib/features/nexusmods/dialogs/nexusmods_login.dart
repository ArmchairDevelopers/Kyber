import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/windows_utils.dart';
import 'package:kyber_launcher/features/setup/widgets/nexus_login_screen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';

Future<bool> showNexusLoginDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => const NexusmodsLogin(),
  );

  if (result == null || !result) {
    if (result == null) {
      NotificationService.error(message: l10n.abortingNexusLogin);
    }

    return false;
  }

  return result;
}

class NexusmodsLogin extends StatefulWidget {
  const NexusmodsLogin({super.key});

  @override
  State<NexusmodsLogin> createState() => _NexusmodsLoginState();
}

class _NexusmodsLoginState extends State<NexusmodsLogin> {
  int _currentStep = 0;

  bool browserOpen = false;
  bool showOverlay = false;

  @override
  void initState() {
    super.initState();
    Logger.root.info('Checking installed WebView');
    if (Platform.isWindows) {
      WebViewEnvironment.getAvailableVersion().then((value) async {
        if (value == null) {
          if (mounted) {
            Navigator.of(context).pop();
          }

          NotificationService.showNotification(
            message: AppLocalizations.of(context)!.installWebViewError,
            severity: InfoBarSeverity.error,
          );
          return;
        }

        if (WindowsUtils.isWindowsCompMode()) {
          setState(() {
            _currentStep = 3;
          });
          return;
        }

        await CookieManager.instance(
          webViewEnvironment: webViewEnvironment,
        ).deleteAllCookies();

        if (!mounted) {
          return;
        }

        setState(() {
          _currentStep = 1;
        });
      });
    } else {
      _currentStep = 1;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return KyberContentDialog(
      title: Text(l10n.nexusModsAuthorization.toUpperCase()),
      constraints: BoxConstraints(
        maxWidth: browserOpen ? 1000 : 600,
        maxHeight: browserOpen ? 857 : 400,
      ),
      style: const ContentDialogThemeData(
        barrierColor: Colors.transparent,
      ),
      actions: [
        KyberButton(
          text: l10n.skip,
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        if (_currentStep == 1)
          KyberButton(
            onPressed: browserOpen
                ? null
                : () async {
                    setState(() => browserOpen = true);
                  },
            text: !browserOpen ? l10n.continueText : l10n.wait,
          ),
      ],
      content: Builder(
        builder: (context) {
          if (_currentStep == 3) {
            return Center(
              child: Column(
                children: [
                  Text(
                    l10n.win7CompatibilityDetected,
                    style: TextStyle(fontFamily: currentFont),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    l10n.disableWin7CompMode,
                    style: TextStyle(fontFamily: currentFont),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    l10n.reEnableWin7CompMode,
                    style: TextStyle(fontFamily: currentFont),
                  ),
                ],
              ),
            );
          }

          if (_currentStep == 0) {
            return Center(
              child: Row(
                children: [
                  const ProgressRing(),
                  const SizedBox(width: 15),
                  Text(
                    l10n.checkingWebView,
                    style: TextStyle(fontFamily: currentFont),
                  ),
                ],
              ),
            );
          }

          return SizedBox(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: browserOpen
                  ? [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: NexusLoginScreen(
                                onShowOverlay: (showOverlay) {
                                  setState(() => this.showOverlay = showOverlay);
                                },
                                onSuccess: () async {
                                  if (!mounted) return;
                                  Preferences.nexusMods.isLoggedIn = true;
                                  Navigator.of(context).pop(true);
                                },
                              ),
                            ),
                            if (showOverlay)
                              Positioned.fill(
                                child: Container(
                                  color: FluentTheme.of(
                                    context,
                                  ).micaBackgroundColor.withOpacity(.9),
                                  alignment: Alignment.center,
                                  child: const Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 30,
                                          width: 30,
                                          child: ProgressRing(),
                                        ),
                                        SizedBox(width: 15),
                                        Text(
                                          'Waiting for NexusMods...',
                                          style: TextStyle(fontSize: 19),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ]
                  : [
                      Text(
                        l10n.nexusLoginIntro,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: currentFont,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.nexusLoginDataNotice,
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: currentFont,
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