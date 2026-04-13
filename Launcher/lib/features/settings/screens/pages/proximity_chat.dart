import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/voip_service.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/settings/screens/settings.dart';
import 'package:kyber_launcher/features/settings/widgets/voip_key_picker.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ProximityChat extends StatelessWidget {
  const ProximityChat({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SuperListView(
      children: [
        SettingsHeader(title: l10n.ingame),
        HiveListener(
          box: box,
          keys: const ['ingameHotkeyEnabled'],
          builder: (context) {
            return KyberTable(
              items: [
                KyberTableItem.switchButton(
                  title: l10n.ingameHotkey,
                  value: Preferences.general.ingameHotkeyEnabled,
                  onChange: (value) async {
                    Preferences.general.ingameHotkeyEnabled = value;
                    if (sl.isRegistered<MaximaGameInstance>()) {
                      NotificationService.showNotification(
                        message: l10n.restartGameWarning,
                      );
                    }
                  },
                  enabledText: l10n.enabled,
                  disabledText: l10n.disabled,
                ),
              ],
            );
          },
        ),
        SettingsHeader(title: l10n.proximityChat),
        ListenableBuilder(
          listenable: sl.get<VoipService>(),
          builder: (_, __) {
            final service = sl.get<VoipService>();

            final child = KyberTable(
              items: [
                KyberTableItem.switchButton(
                  title: l10n.proximityChat,
                  onChange: (value) => service.setVoiceChat(enabled: value),
                  value: service.isEnabled,
                ),
                KyberTableItem.switchButton(
                  title: l10n.inputMode,
                  onChange: (value) => service.setPushToTalk(enabled: value),
                  value: service.isPushToTalkEnabled,
                  disabledText: l10n.openMic,
                  enabledText: l10n.pushToTalk,
                ),
                if (service.isPushToTalkEnabled)
                  KyberTableItem.custom(
                    title: l10n.pushToTalkKey,
                    builder: (context) {
                      return CharKeyPicker(
                        value: VoipKeyResponse(
                          display: Preferences.general.pushToTalkKeyDisplay,
                          keyId: service.pushToTalkKey,
                        ),
                        onChanged: (k) => service.setPushToTalkKey(key: k),
                      );
                    },
                  ),
                KyberTableItem.slider(
                  title: l10n.inputVolume,
                  value: Preferences.general.defaultInputVolume,
                  onChanged: (value) async {
                    Preferences.general.defaultInputVolume = value;
                    service.setGameVoipSettings();
                  },
                  min: 0,
                  max: 100,
                ),
                KyberTableItem.slider(
                  title: l10n.outputVolume,
                  value: Preferences.general.defaultOutputVolume,
                  onChanged: (value) async {
                    Preferences.general.defaultOutputVolume = value;
                    service.setGameVoipSettings();
                  },
                  min: 0,
                  max: 100,
                ),
                KyberTableItem.selector(
                  title: l10n.inputDevice,
                  items: service.inputDevices.isEmpty
                      ? [
                          KyberSelectorItem(
                            title: l10n.noDevicesFound,
                            value: '',
                          ),
                        ]
                      : service.inputDevices.map((e) {
                          return KyberSelectorItem<String>(
                            title: e.name,
                            value: e.id,
                          );
                        }).toList(),
                  value: service.inputDevices.isEmpty
                      ? ''
                      : service.selectedInputDevice,
                  onChange: service.inputDevices.isEmpty
                      ? null
                      : (value) async {
                          Preferences.general.selectedInputDevice =
                              value as String;
                          service.setInputDevice(value);
                        },
                ),
                KyberTableItem.selector(
                  title: l10n.outputDevice,
                  items: service.outputDevices.isEmpty
                      ? [
                          KyberSelectorItem(
                            title: l10n.noDevicesFound,
                            value: '',
                          ),
                        ]
                      : service.outputDevices.map((e) {
                          return KyberSelectorItem<String>(
                            title: e.name,
                            value: e.id,
                          );
                        }).toList(),
                  value: service.outputDevices.isEmpty
                      ? ''
                      : service.selectedOutputDevice,
                  onChange: service.outputDevices.isEmpty
                      ? null
                      : (dynamic value) async {
                          service.setOutputDevice(value as String);
                        },
                ),
              ],
            );

            return child;
          },
        ),
      ],
    );
  }
}