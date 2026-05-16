import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/background_image.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/settings_box_header.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/ingame_sub_pages/ingame_actions.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/ingame_sub_pages/ingame_players.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/ingame_sub_pages/ingame_settings.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/settings/server_settings.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

final hostingForm = GlobalKey<FormBuilderState>();

class ServerSettingsBox extends StatefulWidget {
  const ServerSettingsBox({super.key});

  @override
  State<ServerSettingsBox> createState() => _ServerSettingsBoxState();
}

class _ServerSettingsBoxState extends State<ServerSettingsBox> {
  int selectedPage = 0;

  @override
  Widget build(BuildContext context) {
    return FormBuilder(
      key: hostingForm,
      initialValue: {
        'serverName': Preferences.hostServer.name,
        'description': Preferences.hostServer.description,
        'password': Preferences.hostServer.password,
        'maxPlayers': Preferences.hostServer.maxPlayers,
        'maxSpectators': Preferences.hostServer.maxSpectators,
        'lanMode': false,
        'serverPort': '25200',
      },
      onChanged: () async {
        final state = context.read<ModerationCubit>().state;
        if (!state.selected && state.id == null) {
          Preferences.hostServer.name =
              hostingForm.currentState?.fields['serverName']?.value as String;
          Preferences.hostServer.description =
              (hostingForm.currentState?.fields['description']?.value ?? '')
                  as String;
          Preferences.hostServer.password =
              (hostingForm.currentState?.fields['password']?.value ?? '')
                  as String;
          Preferences.hostServer.maxPlayers =
              (hostingForm.currentState?.fields['maxPlayers']?.value ?? 40)
                  as int;
          Preferences.hostServer.maxSpectators =
              (hostingForm.currentState?.fields['maxSpectators']?.value ?? 0)
                  as int;
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 180,
            child: Panel(
              background: const HostingBackgroundImage(),
              child: SettingsBoxHeader(
                selectedPage: selectedPage,
                onPageChanged: (page) => setState(() => selectedPage = page),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(kDefaultOuterBorderRadius),
              ),
              child: BackgroundBlur(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(kDefaultOuterBorderRadius),
                          ),
                          color: Colors.black.withOpacity(.3),
                          border: const Border(
                            left: kDefaultBorder,
                            right: kDefaultBorder,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child:
                          BlocBuilder<ModerationCubit, ModerationServerState>(
                            builder: (context, state) {
                              if (state.selected) {
                                return SuperListView(
                                  children: const [
                                    KyberSectionDropdown(
                                      initialExpanded: true,
                                      title: 'AUTOPLAYERS',
                                      child: IngameSettings(),
                                    ),
                                    KyberSectionDropdown(
                                      initialExpanded: true,
                                      title: 'PLAYERS (APPLIES ON SPAWN)',
                                      child: IngamePlayers(),
                                    ),
                                    KyberSectionDropdown(
                                      initialExpanded: true,
                                      title: 'INGAME ACTIONS',
                                      child: IngameActions(),
                                    ),
                                  ],
                                );
                              }

                              if (selectedPage == 1) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'DESCRIPTION',
                                        style: TextStyle(
                                          fontFamily: FontFamily.battlefrontUI,
                                          fontSize: 16,
                                          color: kInactiveColor,
                                        ),
                                      ),
                                    ),
                                    const CardSection(),
                                    SizedBox(
                                      height: 300,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: FormBuilderTextField(
                                          decoration: const mt.InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 14,
                                                ),
                                            hintText: 'SERVER DESCRIPTION',
                                            border: mt.InputBorder.none,
                                            hintStyle: TextStyle(
                                              fontFamily:
                                                  FontFamily.battlefrontUI,
                                              fontSize: 16,
                                              color: decoColor,
                                            ),
                                          ),
                                          style: const mt.TextStyle(
                                            fontFamily:
                                                FontFamily.battlefrontUI,
                                            fontSize: 16,
                                            color: kWhiteColor,
                                          ),
                                          name: 'description',
                                          expands: true,
                                          maxLines: null,
                                        ),
                                      ),
                                    ),
                                    const CardSection(),
                                  ],
                                );
                              }

                              return const ServerSettings();
                            },
                          ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(
                                kDefaultOuterBorderRadius,
                              ),
                            ),
                            border: Border(
                              bottom: kDefaultBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
