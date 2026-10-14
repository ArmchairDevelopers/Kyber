import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/voip_service.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/settings/screens/settings.dart';
import 'package:kyber_launcher/features/settings/widgets/voip_key_picker.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ProximityChat extends StatelessWidget {
  const ProximityChat({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperListView(
      children: [
        const SettingsHeader(title: 'INGAME'),
        HiveListener(
          box: box,
          keys: const ['ingameHotkeyEnabled'],
          builder: (context) {
            return KyberTable(
              items: [
                KyberTableItem.switchButton(
                  title: 'Ingame Hotkey (Moderation Menu)',
                  value: Preferences.general.ingameHotkeyEnabled,
                  onChange: (value) async {
                    Preferences.general.ingameHotkeyEnabled = value;
                    if (sl.isRegistered<MaximaGameInstance>()) {
                      NotificationService.showNotification(
                        message: 'To apply changes, restart the game',
                      );
                    }
                  },
                  enabledText: 'Enabled',
                  disabledText: 'Disabled',
                ),
              ],
            );
          },
        ),
        const SettingsHeader(title: 'Proximity Chat'),
        ListenableBuilder(
          listenable: sl.get<VoipService>(),
          builder: (_, __) {
            final service = sl.get<VoipService>();

            final child = KyberTable(
              items: [
                KyberTableItem.switchButton(
                  title: 'Proximity Chat',
                  onChange: (value) => service.setVoiceChat(enabled: value),
                  value: service.isEnabled,
                ),
                KyberTableItem.switchButton(
                  title: 'Input Mode',
                  onChange: (value) => service.setPushToTalk(enabled: value),
                  value: service.isPushToTalkEnabled,
                  disabledText: 'Open Mic',
                  enabledText: 'Push to Talk',
                ),
                if (service.isPushToTalkEnabled)
                  KyberTableItem.custom(
                    title: 'Push to Talk Key',
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
                  title: 'Input Volume',
                  value: Preferences.general.defaultInputVolume,
                  onChanged: (value) async {
                    Preferences.general.defaultInputVolume = value;
                    service.setGameVoipSettings();
                  },
                  min: 0,
                  max: 100,
                ),
                KyberTableItem.slider(
                  title: 'Output Volume',
                  value: Preferences.general.defaultOutputVolume,
                  onChanged: (value) async {
                    Preferences.general.defaultOutputVolume = value;
                    service.setGameVoipSettings();
                  },
                  min: 0,
                  max: 100,
                ),
                KyberTableItem.selector(
                  title: 'Input Device',
                  items: service.inputDevices.isEmpty
                      ? [
                          const KyberSelectorItem(
                            title: 'No devices found',
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
                  title: 'Output Device',
                  items: service.outputDevices.isEmpty
                      ? [
                          const KyberSelectorItem(
                            title: 'No devices found',
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
        const SettingsHeader(title: 'EXPERIMENTAL SETTINGS'),
        HiveListener(
          box: box,
          keys: const ['disableForceNoHDR', 'disableForceDX11'],
          builder: (context) {
            return KyberTable(
              items: [
                KyberTableItem.switchButton(
                  title: 'Disable Force No HDR',
                  value: Preferences.general.disableForceNoHDR,
                  onChange: (value) async {
                    Preferences.general.disableForceNoHDR = value;
                    if (sl.isRegistered<MaximaGameInstance>()) {
                      NotificationService.showNotification(
                        message: 'To apply changes, restart the game',
                      );
                    }
                  },
                ),
                KyberTableItem.switchButton(
                  title: 'Disable Force DX11',
                  value: Preferences.general.disableForceDX11,
                  onChange: (value) async {
                    Preferences.general.disableForceDX11 = value;
                    if (sl.isRegistered<MaximaGameInstance>()) {
                      NotificationService.showNotification(
                        message: 'To apply changes, restart the game',
                      );
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
