import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/server_settings_box.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class IngameSettings extends StatelessWidget {
  const IngameSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return KyberTable(
      itemStyle: const TextStyle(fontSize: 17),
      items: [
        KyberTableItem.custom(
          title: 'Shuffle Teams',
          onClick: () {
            final value =
                !(hostingForm.currentState!.fields['shuffleTeams']!.value
                    as bool);
            hostingForm.currentState?.fields['shuffleTeams']?.didChange(value);
            context.read<ModerationCubit>().sendCommand(
              '/Kyber.EnableShuffleTeams ${value ? '1' : '0'}',
            );
          },
          builder: (hovered) {
            return FormBuilderField<bool>(
              name: 'shuffleTeams',
              initialValue: false,
              builder: (field) {
                return KyberTableSwitch(
                  value: field.value,
                  hover: hovered,
                  onChanged: (value) {},
                );
              },
            );
          },
        ),
        KyberTableItem.custom(
          title: 'Inactivity Timeout',
          builder: (hovered) {
            return FormBuilderField<Duration>(
              name: 'inactivityTimeout',
              initialValue: .zero,
              builder: (field) {
                return KyberTableSelector<Duration>(
                  items: const [
                    KyberSelectorItem(title: 'Disabled', value: .zero),
                    KyberSelectorItem(
                      title: '30 seconds',
                      value: .new(seconds: 30),
                    ),
                    KyberSelectorItem(
                      title: '1 minute',
                      value: .new(minutes: 1),
                    ),
                    KyberSelectorItem(
                      title: '3 minutes',
                      value: .new(minutes: 3),
                    ),
                    KyberSelectorItem(
                      title: '5 minutes',
                      value: .new(minutes: 5),
                    ),
                  ],
                  value: field.value,
                  hover: hovered,
                  onChanged: (value) {
                    field.didChange(value);
                    context.read<ModerationCubit>().sendCommand(
                      '/Whiteshark.NoInteractivityTimeoutTime ${value.inSeconds}',
                    );
                  },
                );
              },
            );
          },
        ),
        KyberTableItem.custom(
          title: 'Bot Difficulty',
          builder: (hovered) {
            return FormBuilderField<int>(
              name: 'botDifficulty',
              initialValue: 3,
              builder: (field) {
                return KyberTableSelector<int>(
                  items: const [
                    KyberSelectorItem(title: 'Easy', value: 12),
                    KyberSelectorItem(title: 'Medium', value: 9),
                    KyberSelectorItem(title: 'Hard', value: 6),
                    KyberSelectorItem(title: 'Knight', value: 3),
                    KyberSelectorItem(title: 'Master', value: 0),
                  ],
                  value: field.value,
                  hover: hovered,
                  onChanged: (value) {
                    field.didChange(value);
                    context.read<ModerationCubit>().sendCommand(
                      '/AutoPlayers.AimNoiseScale $value',
                    );
                  },
                );
              },
            );
          },
        ),
        KyberTableItem.custom(
          title: 'Bots Team 1',
          builder: (hovered) {
            return FormBuilderField<int>(
              name: 'botsTeam1',
              initialValue: 0,
              builder: (field) {
                return KyberTableSlider(
                  min: 0,
                  max: 32,
                  value: field.value!,
                  hover: hovered,
                  onChanged: (value) {
                    field.didChange(value);
                    context.read<ModerationCubit>().botChangeStream!.add((
                      1,
                      value,
                    ));
                  },
                );
              },
            );
          },
        ),
        KyberTableItem.custom(
          title: 'Bots Team 2',
          builder: (hovered) {
            return FormBuilderField<int>(
              name: 'botsTeam2',
              initialValue: 0,
              builder: (field) {
                return KyberTableSlider(
                  min: 0,
                  max: 32,
                  value: field.value!,
                  hover: hovered,
                  onChanged: (value) {
                    //TODO: throttle
                    field.didChange(value);
                    context.read<ModerationCubit>().botChangeStream!.add((
                      2,
                      value,
                    ));
                  },
                );
              },
            );
          },
        ),
        KyberTableItem.custom(
          title: 'Freeze Bots',
          onClick: () {
            final value =
                !(hostingForm.currentState!.fields['freezeBots']!.value
                    as bool);
            hostingForm.currentState?.fields['freezeBots']?.didChange(value);
            context.read<ModerationCubit>().sendCommand(
              '/AutoPlayers.UpdateAI ${value ? '0' : '1'}',
            );
          },
          builder: (hovered) {
            return FormBuilderField<bool>(
              name: 'freezeBots',
              initialValue: false,
              builder: (field) {
                return KyberTableSwitch(
                  value: field.value,
                  hover: hovered,
                  onChanged: (value) {},
                );
              },
            );
          },
        ),
        KyberTableItem.custom(
          title: 'Bots Ignore Players',
          onClick: () {
            final value =
                !(hostingForm.currentState!.fields['botsIgnorePlayers']!.value
                    as bool);
            hostingForm.currentState?.fields['botsIgnorePlayers']?.didChange(
              value,
            );
            context.read<ModerationCubit>().sendCommand(
              '/AutoPlayers.IgnoreHumanPlayers ${value ? '1' : '0'}',
            );
          },
          builder: (hovered) {
            return FormBuilderField<bool>(
              name: 'botsIgnorePlayers',
              initialValue: false,
              builder: (field) {
                return KyberTableSwitch(
                  value: field.value,
                  hover: hovered,
                  onChanged: (value) {},
                );
              },
            );
          },
        ),
      ],
    );
  }
}
