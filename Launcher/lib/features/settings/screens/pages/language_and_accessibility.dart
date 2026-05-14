import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return SuperListView(
      padding: const EdgeInsets.only(bottom: 15),
      children: [
        const Row(
          children: [
            SettingsHeader(title: 'ACCESSIBILITY'),
          ],
        ),
        const CardSection(),
        const SizedBox(height: 15),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 21),
          child: Text(
            'COLORBLIND PROFILES',
            style: TextStyle(
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
                  title: 'DEFAULT',
                  color: kDefaultActiveColor.withValues(),
                ),
                _ColorOption(
                  title: 'PROTANOMALY',
                  color: kProtanopia.withValues(),
                ),
                _ColorOption(
                  title: 'DEUTERANOMALY',
                  color: kDeuteranopia.withValues(),
                ),
                _ColorOption(
                  title: 'TRITANOMALY',
                  color: kTritanopia.withValues(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        HiveListener(
          keys: const ['rememberWindowPosition', 'groupServersByRegion'],
          box: box,
          builder: (context) {
            return BlocBuilder<KyberProxyCubit, KyberProxyState>(
              builder: (context, state) {
                return KyberTable(
                  items: [
                    KyberTableItem.button(
                      title: 'RESET SETTINGS',
                      onClick: () => showKyberDialog(
                        context: context,
                        builder: (_) => const SettingsResetDialog(),
                      ),
                      text: 'Reset',
                    ),
                    KyberTableItem.switchButton(
                      title: 'Remember Window Position',
                      value: Preferences.customization.rememberWindowPosition,
                      onChange: (value) async {
                        Preferences.customization.rememberWindowPosition =
                            value;
                      },
                    ),
                    KyberTableItem.switchButton(
                      title: 'Group Servers by Region',
                      value: Preferences.general.groupServersByRegion,
                      onChange: (value) async {
                        Preferences.general.groupServersByRegion = value;
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
                'CUSTOMIZATION',
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
                    'PATREON EXCLUSIVE',
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
          ],
          builder: (_) => KyberTable(
            items: [
              KyberTableItem.button(
                title: 'CHANGE HIGHLIGHT COLOR',
                text: 'Change',
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
                            title: const Text('CHANGE COLOR'),
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
                                text: 'CANCEL',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              KyberButton(
                                text: 'Reset',
                                onPressed: () {
                                  kActiveColor = const Color(0xFFfab20a);
                                  Preferences.customization.activeColor =
                                      kActiveColor;
                                  Navigator.of(context).pop();
                                },
                              ),
                              KyberButton(
                                text: 'Save',
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
                title: 'CHANGE BACKGROUND',
                text: 'Change',
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
