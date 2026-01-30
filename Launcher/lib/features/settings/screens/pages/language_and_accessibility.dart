import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/i18n/app_locale.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/settings/dialogs/settings_reset_dialog.dart';
import 'package:kyber_launcher/features/settings/screens/settings.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LanguageAndAccessibility extends StatelessWidget {
  const LanguageAndAccessibility({super.key});

  // NOTE: Helper method to show a dialog for language selection
  void _showLanguageDialog(BuildContext context) async {
    await showKyberDialog(
      context: context,
      builder: (context) => KyberContentDialog(
        title: const Text('SELECT LANGUAGE'),
        content: SizedBox(
          // Limit height if list gets too long
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LanguageOption(
                  label: 'English',
                  localeCode: 'en',
                  onSelected: () => _setLocale(context, 'en'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Deutsch', // German
                  localeCode: 'de',
                  onSelected: () => _setLocale(context, 'de'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Français', // French
                  localeCode: 'fr',
                  onSelected: () => _setLocale(context, 'fr'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Español', // Spanish
                  localeCode: 'es',
                  onSelected: () => _setLocale(context, 'es'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Polski', // Polish
                  localeCode: 'pl',
                  onSelected: () => _setLocale(context, 'pl'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Русский', // Russian
                  localeCode: 'ru',
                  onSelected: () => _setLocale(context, 'ru'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Português', // Portuguese
                  localeCode: 'pt',
                  onSelected: () => _setLocale(context, 'pt'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Українська', // Ukrainian
                  localeCode: 'uk',
                  onSelected: () => _setLocale(context, 'uk'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Svenska', // Swedish
                  localeCode: 'sv',
                  onSelected: () => _setLocale(context, 'sv'),
                ),
                const SizedBox(height: 5),
                _LanguageOption(
                  label: 'Nederlands', // Dutch
                  localeCode: 'nl',
                  onSelected: () => _setLocale(context, 'nl'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          KyberButton(
            text: AppLocalizations.of(context)!.cancel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _setLocale(BuildContext context, String code) {
    AppLocale.setLocale(Locale(code));
    Navigator.of(context).pop();
  }

  // Helper method to get the display name for the button
  String _getCurrentLanguageName(String code) {
    switch (code) {
      case 'en': return 'ENGLISH';
      case 'de': return 'DEUTSCH';
      case 'fr': return 'FRANÇAIS';
      case 'es': return 'ESPAÑOL';
      case 'pl': return 'POLSKI';
      case 'ru': return 'РУССКИЙ';
      case 'pt': return 'PORTUGUÊS';
      case 'uk': return 'УКРАЇНСЬКА';
      case 'sv': return 'SVENSKA';
      case 'nl': return 'NEDERLANDS';
      default: return 'ENGLISH';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentCode = AppLocale.getLocale().languageCode;

    return SuperListView(
      padding: const EdgeInsets.only(bottom: 15),
      children: [
        Row(
          children: [
            SettingsHeader(title: l10n.accessibility),
          ],
        ),
        const CardSection(),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 21),
          child: Text(
            l10n.colorblindProfiles,
            style: const TextStyle(
              color: kWhiteColor,
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        HiveListener(
          keys: const ['activeColor'],
          box: box,
          builder: (bx) => Padding(
            padding: const EdgeInsets.only(left: 20, top: 10),
            child: Row(
              spacing: 30,
              children: [
                _ColorOption(
                  title: l10n.defaultColor,
                  color: kDefaultActiveColor.withValues(),
                ),
                _ColorOption(
                  title: l10n.protanomaly,
                  color: kProtanopia.withValues(),
                ),
                _ColorOption(
                  title: l10n.deuteranomaly,
                  color: kDeuteranopia.withValues(),
                ),
                _ColorOption(
                  title: l10n.tritanomaly,
                  color: kTritanopia.withValues(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        HiveListener(
          keys: const ['rememberWindowPosition', 'locale'],
          box: box,
          builder: (context) {
            return BlocBuilder<KyberProxyCubit, KyberProxyState>(
              builder: (context, state) {
                return KyberTable(
                  items: [
                    // Language selection entry
                    KyberTableItem.button(
                      title: l10n.language,
                      onClick: () => _showLanguageDialog(context),
                      text: _getCurrentLanguageName(currentCode),
                    ),
                    KyberTableItem.button(
                      title: l10n.resetSettings,
                      onClick: () => showKyberDialog(
                        context: context,
                        builder: (_) => const SettingsResetDialog(),
                      ),
                      text: l10n.reset,
                    ),
                    KyberTableItem.switchButton(
                      title: l10n.rememberWindowPosition,
                      value: Preferences.customization.rememberWindowPosition,
                      onChange: (value) async {
                        Preferences.customization.rememberWindowPosition =
                            value;
                      },
                    ),
                  ],
                );
              },
            );
          },
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.all(
            8,
          ).copyWith(left: 20).copyWith(top: 30 + 8),
          child: Row(
            spacing: 15,
            children: [
              Text(
                l10n.customization,
                style: FluentTheme.of(context).typography.title!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: kInactiveColor,
                  fontFamily: FontFamily.battlefrontUI,
                ),
              ),
              ButtonBuilder(
                onClick: () =>
                    launchUrlString('https://www.patreon.com/KyberServers'),
                builder: (context, _) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: kActiveColor),
                      bottom: BorderSide(color: kActiveColor),
                    ),
                  ),
                  child: Text(
                    l10n.patreonExclusive,
                    style: TextStyle(
                      fontFamily: FontFamily.battlefrontUI,
                      color: kActiveColor,
                      fontSize: 12,
                      height: 1,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
        HiveListener(
          box: box,
          keys: const [
            'removeBackground',
            'window',
            'disableHeadless',
            'dummyServer',
            'apiEnv',
            'activeColor',
          ],
          builder: (_) => KyberTable(
            items: [
              KyberTableItem.button(
                title: l10n.changeHighlightColor,
                text: l10n.change,
                onClick: !context.read<MaximaCubit>().state.canUsePerks()
                    ? null
                    : () async {
                        await showKyberDialog(
                          context: context,
                          builder: (context) => KyberContentDialog(
                            constraints: const BoxConstraints(
                              maxWidth: 700,
                              maxHeight: 600,
                            ),
                            title: Text(l10n.changeColor),
                            content: SingleChildScrollView(
                              child: ColorPicker(
                                isAlphaEnabled: false,
                                isMoreButtonVisible: false,
                                isColorChannelTextInputVisible: false,
                                minValue: 50,
                                color: kActiveColor,
                                onChanged: (color) {
                                  kActiveColor = color;
                                  Preferences.customization.activeColor = color;
                                },
                              ),
                            ),
                            actions: <Widget>[
                              KyberButton(
                                text: l10n.cancel,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              KyberButton(
                                text: l10n.reset,
                                onPressed: () {
                                  kActiveColor = const Color(0xFFfab20a);
                                  Preferences.customization.activeColor =
                                      kActiveColor;
                                  Navigator.of(context).pop();
                                },
                              ),
                              KyberButton(
                                text: l10n.save,
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        );
                      },
              ),
              KyberTableItem.button(
                title: l10n.changeBackground,
                text: l10n.change,
                onClick: !context.read<MaximaCubit>().state.canUsePerks()
                    ? null
                    : () {
                        router.push('/settings/backgrounds');
                      },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// NOTE: Custom widget for Language Menu items
class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.localeCode,
    required this.onSelected,
  });

  final String label;
  final String localeCode;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final currentLocale = AppLocale.getLocale().languageCode;
    final isSelected = currentLocale == localeCode;

    return ButtonBuilder(
      onClick: onSelected,
      builder: (context, hovered) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: hovered ? kActiveColor.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? kActiveColor : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: kWhiteColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  // NOTE: Use specific font for the language name preview
                  // English gets Battlefront, everyone else gets IBM Plex Mono for safety
                  fontFamily: localeCode == 'en'
                      ? FontFamily.battlefrontUI
                      : FontFamily.iBMPlexMono,
                ),
              ),
              if (isSelected)
                Icon(FluentIcons.check_mark, color: kActiveColor, size: 16),
            ],
          ),
        );
      },
    );
  }
}

class _ColorOption extends StatelessWidget {
  const _ColorOption({required this.title, required this.color, super.key});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final active =
        kActiveColor == color ||
        ![
              kProtanopia,
              kDeuteranopia,
              kTritanopia,
              kDefaultActiveColor,
            ].contains(kActiveColor) &&
            color == kDefaultActiveColor;
    return StatefulBuilder(
      builder: (context, setState) {
        return ButtonBuilder(
          onClick: () {
            kActiveColor = color;
            Preferences.customization.activeColor = color;
            setState(() {});
          },
          builder: (context, hovered) {
            return Column(
              children: [
                (active || hovered
                        ? Assets.icons.colorBlindness.colourSelected
                        : Assets.icons.colorBlindness.colourUnselected)
                    .svg(
                      color: hovered ? kActiveColor : kWhiteColor,
                    ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: hovered ? kActiveColor : kWhiteColor,
                    fontSize: 12,
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