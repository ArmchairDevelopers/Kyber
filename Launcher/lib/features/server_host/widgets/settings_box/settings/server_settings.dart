import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/server_settings_box.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ServerSettings extends StatelessWidget {
  const ServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperListView(
      children: [
        KyberSectionDropdown(
          initialExpanded: true,
          title: 'SERVER',
          child: KyberTable(
            itemStyle: const TextStyle(fontSize: 17),
            items: [
              KyberTableItem.custom(
                title: 'MAX PLAYERS',
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
                title: 'Max Spectators',
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
                title: 'Proximity Chat',
                value: true,
                onChange: (value) async {
                  NotificationService.notImplemented();
                },
              ),
              KyberTableItem.custom(
                title: 'LAN Server',
                builder: (hovered) {
                  return FormBuilderField<bool>(
                    name: 'lanMode',
                    builder: (field) {
                      return GestureDetector(
                        onTap: () => field.didChange(!(field.value ?? false)),
                        child: KyberTableSwitch(
                          hover: hovered,
                          disabledText: 'Internet',
                          enabledText: 'LAN',
                          value: field.value ?? false,
                          onChanged: field.didChange,
                        ),
                      );
                    },
                  );
                },
              ),
              KyberTableItem.custom(
                title: 'Server Port',
                builder: (hovered) {
                  return KyberFormInputField(
                    name: 'serverPort',
                    placeholder: '25200',
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.integer(),
                      FormBuilderValidators.min(1),
                      FormBuilderValidators.max(65535),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
        KyberSectionDropdown(
          initialExpanded: true,
          title: 'Privacy',
          child: KyberTable(
            itemStyle: const TextStyle(fontSize: 17),
            items: [
              KyberTableItem.custom(
                title: 'Password',
                builder: (hovered) {
                  return KyberFormInputField(
                    name: 'password',
                    isSensitive: true,
                    placeholder: 'EXAMPLE',
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
