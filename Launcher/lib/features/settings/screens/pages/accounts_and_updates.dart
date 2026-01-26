import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/nexusmods/dialogs/nexusmods_login.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/features/settings/dialogs/change_background_dialog.dart';
import 'package:kyber_launcher/features/settings/dialogs/connect_patreon_dialog.dart';
import 'package:kyber_launcher/features/settings/dialogs/environment_selector.dart';
import 'package:kyber_launcher/features/settings/dialogs/release_channel_selector_dialog.dart';
import 'package:kyber_launcher/features/settings/dialogs/reset_token_dialog.dart';
import 'package:kyber_launcher/features/settings/dialogs/set_token_dialog.dart';
import 'package:kyber_launcher/features/settings/dialogs/update_dialog.dart';
import 'package:kyber_launcher/features/settings/screens/settings.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class AccountsAndUpdates extends StatelessWidget {
  const AccountsAndUpdates({super.key});

  @override
  Widget build(BuildContext context) {
    return SuperListView(
      children: [
        const SettingsHeader(title: 'ACCOUNTS'),
        HiveListener(
          box: box,
          keys: const ['nexusmods_login'],
          builder: (bx) => BlocBuilder<KyberProxyCubit, KyberProxyState>(
            builder: (context, state) => KyberTable(
              items: [
                KyberTableItem.selector(
                  title: 'PROXY',
                  items: state.proxies.map((e) {
                    final ping = e.ping == 99999
                        ? 'UNAVAILABLE'
                        : '${e.ping}ms';
                    return KyberSelectorItem<String>(
                      title: '${e.proxy.name} ($ping)',
                      value: e.proxy.id,
                    );
                  }).toList(),
                  value: state.selectedProxy,
                  onChange: (dynamic value) async {
                    value as String;
                    context.read<KyberProxyCubit>().selectProxy(value);
                  },
                ),
                KyberTableItem.button(
                  title: 'Reset Kyber Token',
                  onClick: () async {
                    final result = await showKyberDialog<bool?>(
                      context: context,
                      builder: (_) => const ResetTokenDialog(),
                    );
                    
                    if (result != true) {
                      return;
                    }

                    await sl<KyberGRPCService>().authClient.resetToken(.new());

                    await context.read<MaximaCubit>().requestLogin();
                  },
                  text: 'Reset',
                ),
                KyberTableItem.button(
                  title: 'NexusMods',
                  onClick: () async {
                    if (Preferences.nexusMods.isLoggedIn) {
                      await sl.get<NexusModsService>().deleteToken();
                      Preferences.nexusMods.isLoggedIn = false;
                      Preferences.nexusMods.apiToken = null;
                      Preferences.nexusMods.refreshToken = null;
                      await CookieManager.instance(
                        webViewEnvironment: webViewEnvironment,
                      ).deleteAllCookies();
                    } else {
                      await showKyberDialog(
                        context: context,
                        builder: (_) => const NexusmodsLogin(),
                        routeSettings: const RouteSettings(
                          name: 'nexusmods_login',
                        ),
                      );
                    }
                  },
                  text: Preferences.nexusMods.isLoggedIn ? 'Logout' : 'Login',
                ),
                KyberTableItem.button(
                  title: 'Logout',
                  text: 'EA Logout',
                  onClick: () async {
                    await File(
                      '${Platform.environment['APPDATA']}\\ArmchairDevelopers\\Maxima\\data\\auth.toml',
                    ).delete();
                    await launchUrlString(
                      'https://accounts.ea.com/connect/logout?client_id=EADOTCOM-WEB-SERVER&redirect_uri=https://ea.com',
                    );

                    final executable = Platform.resolvedExecutable;
                    final args = <String>['--restart'];
                    final workingDirectory = Directory.current.path;

                    await Process.start(
                      executable,
                      args,
                      workingDirectory: workingDirectory,
                    );
                    exit(0);
                  },
                ),
              ],
            ),
          ),
        ),
        const SettingsHeader(title: 'LINKED ACCOUNTS'),
        BlocBuilder<MaximaCubit, MaximaState>(
          bloc: context.read<MaximaCubit>(),
          builder: (context, _) => KyberTable(
            items: [
              if (context.read<MaximaCubit>().state.discordData != null)
                KyberTableItem.custom(
                  title: 'Discord',
                  onClick: () async {
                    await sl
                        .get<KyberGRPCService>()
                        .authClient
                        .unlinkDiscordAccount(Empty());

                    context.read<MaximaCubit>().removeDiscordData();
                  },
                  builder: (hovered) {
                    final discord = context
                        .read<MaximaCubit>()
                        .state
                        .discordData!;
                    return KyberTableButton(
                      hover: hovered,
                      onPressed: () async {
                        await sl
                            .get<KyberGRPCService>()
                            .authClient
                            .unlinkDiscordAccount(Empty());

                        context.read<MaximaCubit>().removeDiscordData();
                      },
                      widget: IgnorePointer(
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                getAvatarUrl(
                                  discord.id,
                                  hash: discord.avatarHash,
                                ),
                                height: 24,
                                width: 24,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${discord.globalName}   |   Unlink',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                fontFamily: FontFamily.battlefrontUI,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              else
                KyberTableItem.button(
                  title: 'Discord',
                  text: 'Connect',
                  onClick: () async {
                    final service = sl.get<KyberGRPCService>();
                    final host = service.httpHostname;
                    final token = service.token;

                    await launchUrlString(
                      'https://$host/discord/auth?token=$token',
                    );
                    //await sl.get<KyberGRPCService>().linkDiscordAccount();
                    //context.read<MaximaCubit>().refreshDiscordData();
                  },
                ),
              if (!context.read<MaximaCubit>().state.isPatron)
                KyberTableItem.button(
                  title: 'Connect Patreon',
                  text: 'Connect',
                  onClick: () async {
                    await showKyberDialog(
                      context: context,
                      builder: (_) => BlocProvider.value(
                        value: context.read<MaximaCubit>(),
                        child: const ConnectPatreonDialog(),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        const SettingsHeader(title: 'UPDATES'),
        KyberTable(
          items: [
            KyberTableItem.switchButton(
              title: 'Automatically Update',
              value: true,
            ),
            KyberTableItem.button(
              title: 'Release Channel',
              text: 'Select',
              onClick: () async {
                await showKyberDialog(
                  context: context,
                  builder: (_) => const ReleaseChannelSelectorDialog(),
                );
                await Sentry.configureScope((scope) async {
                  await scope.setTag(
                    'release-channel',
                    VersionModule.installer.releaseChannel,
                  );
                });
              },
            ),
            KyberTableItem.button(
              title: 'Force update',
              text: 'UPDATE NOW',
              onClick: () => showKyberDialog(
                context: context,
                builder: (_) => const UpdateDialog(),
              ),
            ),
          ],
        ),
        const SettingsHeader(title: 'OTHER'),
        HiveListener(
          box: box,
          keys: const [
            'removeBackground',
            'window',
            'disableHeadless',
            'dummyServer',
            'apiEnv',
            'developerMode',
          ],
          builder: (_) => KyberTable(
            items: [
              KyberTableItem.switchButton(
                title: 'Remember Window Position',
                value: Preferences.customization.rememberWindowPosition,
                onChange: (value) async {
                  Preferences.customization.rememberWindowPosition = value;
                },
              ),
              KyberTableItem.button(
                title: 'Licenses',
                onClick: () {
                  Navigator.of(context).push(
                    mt.MaterialPageRoute<void>(
                      builder: (_) => mt.Theme(
                        data: mt.ThemeData(
                          brightness: FluentTheme.of(context).brightness,
                          primaryColor: kActiveColor,
                          colorScheme: mt.ColorScheme.dark(
                            primary: kActiveColor,
                            brightness: FluentTheme.of(context).brightness,
                          ),
                        ),
                        child: FutureBuilder(
                          future: PackageInfo.fromPlatform(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const mt.Center(
                                child: ProgressRing(),
                              );
                            }

                            return mt.LicensePage(
                              applicationIcon: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Assets.icons.kyberLogo.svg(
                                  height: 40,
                                ),
                              ),
                              applicationLegalese: '© 2024 ArmchairDevelopers',
                              applicationName: 'KYBER Launcher',
                              applicationVersion: snapshot.data?.version,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                text: 'Show Licenses',
              ),
              KyberTableItem.button(
                title: 'Logout',
                text: 'EA Logout',
                onClick: () async {
                  await File(
                    '${Platform.environment['APPDATA']}\\ArmchairDevelopers\\Maxima\\data\\auth.toml',
                  ).delete();
                  await launchUrlString(
                    'https://accounts.ea.com/connect/logout?client_id=EADOTCOM-WEB-SERVER&redirect_uri=https://ea.com',
                  );
                  final executable = Platform.resolvedExecutable;
                  final args = <String>['--restart'];
                  final workingDirectory = Directory.current.path;

                  await Process.start(
                    executable,
                    args,
                    workingDirectory: workingDirectory,
                  );
                  exit(0);
                },
              ),
              KyberTableItem.switchButton(
                title: 'Developer Mode',
                value: Preferences.general.developerMode,
                onChange: (value) {
                  Preferences.general.developerMode = value;
                },
              ),
              if (Preferences.general.developerMode) ...[
                KyberTableItem.button(
                  title: 'Environment',
                  text: 'Select',
                  onClick: () {
                    showKyberDialog(
                      context: context,
                      builder: (_) => const EnvironmentSelector(),
                    );
                  },
                ),
              ],
              if (context.read<MaximaCubit>().state.entitlements!.contains(
                UserEntitlement.admin,
              )) ...[
                ...[
                  KyberTableItem<String>.selector(
                    title: 'API Environment',
                    items: ['prod', 'stage'].map((e) {
                      return KyberSelectorItem<String>(
                        title: e,
                        value: e,
                      );
                    }).toList(),
                    value: Preferences.admin.apiEnv,
                    onChange: (value) async {
                      Preferences.admin.apiEnv = value;
                      if (kDebugMode) {
                        return;
                      }

                      final executable = Platform.resolvedExecutable;
                      final args = <String>['--restart'];
                      final workingDirectory = Directory.current.path;

                      await box.close();
                      await collectionBox.close();
                      await mapRotationBox.close();

                      await Process.start(
                        executable,
                        args,
                        workingDirectory: workingDirectory,
                      );
                      exit(0);
                    },
                  ),
                  KyberTableItem.button(
                    title: 'Set Nexus API Token',
                    text: 'Set token',
                    onClick: () async {
                      final token = await showKyberDialog<String?>(
                        context: context,
                        builder: (_) => const SetTokenDialog(),
                      );

                      if (token == null || token.isEmpty) {
                        return;
                      }

                      await sl.get<NexusModsService>().setApiToken(token);
                    },
                  ),
                  KyberTableItem.button(
                    title: 'Set Background Image',
                    text: 'Set Image',
                    onClick: () async {
                      final result = await showKyberDialog<String?>(
                        context: context,
                        builder: (_) => const ChangeBackgroundDialog(),
                      );

                      if (result == null) {
                        return;
                      }

                      if (result.isEmpty) {
                        Preferences.customization.backgroundImage = null;
                        return;
                      }

                      Preferences.customization.backgroundImage = result;
                    },
                  ),
                  KyberTableItem.switchButton(
                    title: 'Dummy Server',
                    onChange: (value) => Preferences.admin.dummyServer = value,
                    value: Preferences.admin.dummyServer,
                  ),
                ],
                KyberTableItem.switchButton(
                  title: 'Remove Background',
                  value: Preferences.admin.removeBackground,
                  onChange: (value) =>
                      Preferences.admin.removeBackground = value,
                ),
                KyberTableItem.button(
                  title: 'Copy Kyber Token',
                  text: 'Copy',
                  onClick: () async {
                    final token = sl.get<KyberGRPCService>().token;
                    if (token == null) {
                      return;
                    }

                    await Clipboard.setData(ClipboardData(text: token));
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String getAvatarUrl(String userId, {required String hash}) {
    return 'https://cdn.discordapp.com/avatars/$userId/$hash.png?size=512';
  }
}
