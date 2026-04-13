import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/server_settings_box.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ServerSettings extends StatelessWidget {
  const ServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return SuperListView(
      children: [
        KyberSectionDropdown(
          initialExpanded: true,
          title: l10n.serverSectionTitle,
          child: KyberTable(
            itemStyle: TextStyle(fontSize: 17, fontFamily: currentFont),
            items: [
              KyberTableItem.custom(
                title: l10n.maxPlayersLabel,
                builder: (hovered) {
                  return FormBuilderField<int>(
                    name: 'maxPlayers',
                    builder: (field) {
                      return KyberTableSlider(
                        hover: hovered,
                        min: 2,
                        max: 64,
                        value: field.value!,
                        onChanged: (value) {
                          field.didChange(value);
                          final maxPlayersField = hostingForm
                              .currentState!
                              .fields['maxSpectators']!;
                          final maxPlayers = maxPlayersField.value as int;
                          if (maxPlayers + value > 64) {
                            hostingForm.currentState!.fields['maxSpectators']!
                                .setValue(64 - value);
                          }
                        },
                      );
                    },
                  );
                },
              ),
              KyberTableItem.custom(
                title: l10n.maxSpectatorsLabel,
                builder: (hovered) {
                  return FormBuilderField<int>(
                    name: 'maxSpectators',
                    builder: (field) {
                      return KyberTableSlider(
                        hover: hovered,
                        min: 0,
                        max: 62,
                        value: field.value!,
                        onChanged: (value) {
                          field.didChange(value);
                          final maxPlayersField =
                              hostingForm.currentState!.fields['maxPlayers']!;
                          final maxPlayers = maxPlayersField.value as int;
                          if (maxPlayers + value > 64) {
                            hostingForm.currentState!.fields['maxPlayers']!
                                .setValue(64 - value);
                          }
                        },
                      );
                    },
                  );
                },
              ),
              KyberTableItem.switchButton(
                title: l10n.proximityChat,
                value: true,
                onChange: (value) async {
                  NotificationService.notImplemented();
                },
              ),
            ],
          ),
        ),
        KyberSectionDropdown(
          initialExpanded: true,
          title: l10n.privacySectionTitle,
          child: KyberTable(
            itemStyle: TextStyle(fontSize: 17, fontFamily: currentFont),
            items: [
              KyberTableItem.custom(
                title: l10n.passwordLabel,
                builder: (hovered) {
                  return KyberFormInputField(
                    name: 'password',
                    isSensitive: true,
                    placeholder: l10n.passwordPlaceholder,
                    validator: FormBuilderValidators.compose(
                      [
                        FormBuilderValidators.maxLength(
                          25,
                          checkNullOrEmpty: false,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}