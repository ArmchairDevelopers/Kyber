import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_event_container.dart';
import 'package:url_launcher/url_launcher_string.dart';

class NexusAuthScreen extends StatelessWidget {
  const NexusAuthScreen({super.key, this.onAuthSuccess});

  final VoidCallback? onAuthSuccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      children: [
        KyberEventContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.nexusModsAuthorization.toUpperCase(),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: currentFont,
                ),
              ),
              Text(
                l10n.nexusAuthDescription,
                style: TextStyle(
                  fontSize: 18,
                  color: kWhiteColor,
                  fontFamily: currentFont,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  KyberButton(
                    text: l10n.authorizeKyber,
                    onPressed: () {
                      sl<NexusModsService>()
                          .requestApiToken(onUrl: launchUrlString)
                          .then(
                            (value) {
                              onAuthSuccess?.call();
                              //if (mounted) {
                              //  setState(() {});
                              //}
                            },
                          );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}