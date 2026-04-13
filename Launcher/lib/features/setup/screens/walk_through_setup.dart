import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/navigation_bar/providers/status_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/action_bar.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/title_bar.dart' as kl;
import 'package:kyber_launcher/features/setup/widgets/setup_container.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';

class WalkThroughSetup extends StatefulWidget {
  const WalkThroughSetup({super.key});

  @override
  State<WalkThroughSetup> createState() => _WalkThroughSetupState();
}

class _WalkThroughSetupState extends State<WalkThroughSetup> {
  bool disabled = false;
  bool showNexusLogin = false;

  int setupPage = 0;

  @override
  void initState() {
    Preferences.general.modsPath = FileHelper.getModsDirectory().path;
    Timer.run(() => BlocProvider.of<DownloadCubit>(context));

    ModuleVersionService().updateVersion(module: VersionModule.module);

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return NavigationView(
      key: const Key('navigation_view'),
      titleBar: const SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: Padding(padding: .only(left: 16), child: kl.TitleBar()),
            ),
            Expanded(child: ActionBar()),
          ],
        ),
      ),
      content: ScaffoldPage(
        content: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            LogicalKeySet(
              LogicalKeyboardKey.control,
              LogicalKeyboardKey.shift,
              LogicalKeyboardKey.alt,
            ): () {
              Preferences.debug.frbDebugLogs = !Preferences.debug.frbDebugLogs;
              NotificationService.info(
                message: l10n.debugLogsToggled(
                  Preferences.debug.frbDebugLogs ? l10n.enabled : l10n.disabled,
                ),
              );
            },
          },
          child: Focus(
            autofocus: true,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 120,
                ).copyWith(top: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: BlocConsumer<MaximaCubit, MaximaState>(
                        listener: (context, state) {
                          if (state.loggedIn) {
                            setState(() => setupPage = 1);
                          }
                        },
                        builder: (context, state) {
                          return SetupContainer(
                            showWebView: showNexusLogin,
                            page: setupPage,
                            onNexusSuccess: _finishSetup,
                            onNexusLogin: () =>
                                setState(() => showNexusLogin = true),
                            onNexusCancel: () async {
                              setState(() => showNexusLogin = false);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      height: 74,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: decoColor, width: 2),
                          bottom: BorderSide(color: decoColor, width: 2),
                        ),
                      ),
                      child: BackgroundBlur(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 10,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              const SizedBox(
                                height: 40,
                                width: 140,
                                child: SizedBox.shrink(),
                              ),
                              const SizedBox(width: 60),
                              Row(
                                children: [
                                  ProgressItem(
                                    iconPath: Assets.logos.eaPlay.path,
                                    text: l10n.eaAccount,
                                    done: setupPage > 0,
                                    active: setupPage == 0,
                                  ),
                                  const SizedBox(width: 10),
                                  Assets.icons.launcherUILine1.image(
                                    height: 12,
                                    color: setupPage > 0
                                        ? kActiveColor
                                        : kWhiteColor,
                                  ),
                                  const SizedBox(width: 10),
                                  ProgressItem(
                                    iconPath: Assets.logos.nexusMods.path,
                                    text: l10n.nexusMods,
                                    done: setupPage > 1,
                                    active: setupPage == 1,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 60),
                              KyberButton(
                                text: setupPage == 1 ? l10n.finish : l10n.skip,
                                icon: const Icon(FluentIcons.game),
                                onPressed: _finishSetup,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _finishSetup() {
    final defaultModsPath = FileHelper.getModsDirectory().path;
    if (Preferences.general.modsPath.isEmpty) {
      Preferences.general.modsPath = defaultModsPath;
    }

    Preferences.general.setup = true;

    Directory(
      defaultModsPath,
    ).createSync(recursive: true);
    BlocProvider.of<StatusCubit>(
      context,
    ).setInitialized(true);
    sl.get<ModService>().refresh();
  }
}

class ProgressItem extends StatelessWidget {
  const ProgressItem({
    required this.iconPath,
    required this.text,
    required this.done,
    required this.active,
    super.key,
  });

  final String iconPath;
  final String text;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    final color = active
        ? kWhiteColor
        : done
        ? kActiveColor
        : decoColor;
    return Container(
      width: 170,
      height: 40,
      alignment: Alignment.centerLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: BackgroundBlur(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      const SizedBox(width: 10),
                      SvgPicture.asset(
                        iconPath,
                        height: 15,
                        width: 15,
                        colorFilter: ColorFilter.mode(
                          color,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        text.toUpperCase(),
                        style: TextStyle(
                          fontFamily: currentFont,
                          color: color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 5),
                    ],
                  ),
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Icon(
                        active
                            ? mt.Icons.circle_outlined
                            : done
                            ? mt.Icons.check
                            : mt.Icons.close,
                        size: active ? 17 : 20,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}