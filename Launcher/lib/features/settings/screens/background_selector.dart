import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class BackgroundSelector extends StatefulWidget {
  const BackgroundSelector({super.key});

  @override
  State<BackgroundSelector> createState() => _BackgroundSelectorState();
}

class _BackgroundSelectorState extends State<BackgroundSelector> {
  final List<AssetGenImage> backgrounds = [
    Assets.images.backgrounds.kyberDefault,
    Assets.images.backgrounds.kyberNew,
  ];

  int selectedBackground = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 100,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: BackgroundBlur(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: decoColor, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 14,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.selectBackground,
                                  style: TextStyle(
                                    fontFamily: currentFont,
                                    fontSize: 28,
                                    height: 1.2,
                                    color: kActiveColor,
                                  ),
                                ),
                                Text(
                                  // either 8 already done backgrounds or user can select a custom background
                                  l10n.chooseBackgroundDesc.toUpperCase(),
                                  style: TextStyle(
                                    fontFamily: currentFont,
                                    fontSize: 19,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      color: decoColor,
                    ),
                    Expanded(
                      flex: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    KyberButton(
                                      text: l10n.customBackground,
                                      onPressed: () async {
                                        await showKyberDialog(
                                          context: context,
                                          builder: (context) => KyberContentDialog(
                                            title: Text(
                                              l10n.changeBackground,
                                            ),
                                            constraints: const BoxConstraints(
                                              maxWidth: 600,
                                              maxHeight: 400,
                                            ),
                                            content: Column(
                                              children: [
                                                Text(
                                                  l10n.selectImageDesc,
                                                  style: const TextStyle(
                                                    color: kWhiteColor,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  l10n.minResolutionDesc,
                                                  style: const TextStyle(
                                                    color: kWhiteColor,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              KyberButton(
                                                text: l10n.cancel.toUpperCase(),
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                              ),
                                              KyberButton(
                                                text: l10n.reset,
                                                onPressed: () async {
                                                  try {
                                                    await File(
                                                      join(
                                                        FileHelper.getLauncherDirectory()
                                                            .path,
                                                        'background',
                                                      ),
                                                    ).delete();
                                                  } catch (e) {
                                                    Logger.root.warning(
                                                      'Failed to delete background image',
                                                      e,
                                                    );
                                                  }

                                                  Preferences
                                                          .customization
                                                          .customBackground =
                                                      false;
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                              KyberButton(
                                                text: l10n.selectImage,
                                                onPressed: () async {
                                                  final result = await FilePicker
                                                      .platform
                                                      .pickFiles(
                                                        allowedExtensions: [
                                                          'jpg',
                                                          'jpeg',
                                                          'png',
                                                          'gif',
                                                        ],
                                                        dialogTitle:
                                                            l10n.selectImagePickerTitle,
                                                        type: FileType.custom,
                                                      );

                                                  if (result == null) {
                                                    return;
                                                  }

                                                  if (result.files.single.size >
                                                      1024 * 1024 * 10) {
                                                    NotificationService.showNotification(
                                                      message:
                                                          l10n.fileTooLarge,
                                                      severity:
                                                          InfoBarSeverity.error,
                                                    );
                                                    return;
                                                  }

                                                  final file = File(
                                                    result.files.single.path!,
                                                  );
                                                  final bytes = await file
                                                      .readAsBytes();
                                                  final image =
                                                      await decodeImageFromList(
                                                        bytes,
                                                      );
                                                  if (image.width < 1920 ||
                                                      image.height < 1080) {
                                                    NotificationService.showNotification(
                                                      message:
                                                          l10n.resolutionTooLow,
                                                      severity:
                                                          InfoBarSeverity.error,
                                                    );
                                                    return;
                                                  }

                                                  NotificationService.info(
                                                    message: l10n.copyingImage,
                                                  );
                                                  if (Preferences
                                                      .customization
                                                      .customBackground) {
                                                    imageCache
                                                      ..clear()
                                                      ..clearLiveImages();
                                                  }

                                                  File(
                                                    join(
                                                      FileHelper.getLauncherDirectory()
                                                          .path,
                                                      'background',
                                                    ),
                                                  ).writeAsBytesSync(bytes);
                                                  Preferences
                                                          .customization
                                                          .customBackground =
                                                      true;
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                        setState(() => null);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 16 / 9,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
            ),
            padding: EdgeInsets.zero,
            itemBuilder: (context, index) {
              final image = backgrounds[index];
              return _BackgroundTile(
                image: image,
                selected:
                    Preferences.customization.backgroundImage == image.path &&
                    !Preferences.customization.customBackground,
                onClick: () async {
                  Preferences.customization.backgroundImage = image.path;
                  if (Preferences.customization.customBackground) {
                    Preferences.customization.customBackground = false;
                  }

                  setState(() {});
                },
              );
            },
            itemCount: backgrounds.length,
          ),
        ),
      ],
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  const _BackgroundTile({
    required this.onClick,
    required this.selected,
    required this.image,
  });

  final VoidCallback onClick;
  final bool selected;
  final AssetGenImage image;

  @override
  Widget build(BuildContext context) {
    return ButtonBuilder(
      onClick: onClick,
      builder: (context, hovered) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hovered ? kActiveColor : decoColor,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                        ],
                      ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height),
                      );
                    },
                    blendMode: BlendMode.dstOut,
                    child: image.image(
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: hovered ? 1 : 0,
                    child: Container(
                      color: Colors.black.withOpacity(.5),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    reverseDuration: const Duration(milliseconds: 150),
                    child: hovered
                        ? const Padding(
                            padding: EdgeInsets.only(
                              left: 14,
                              top: 14,
                              right: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                            ),
                          )
                        : Padding(
                            key: UniqueKey(),
                            padding: const EdgeInsets.all(14),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.end,
                            ),
                          ),
                  ),
                ),
                if (selected)
                  Positioned(
                    top: 15,
                    left: 15,
                    child: Container(
                      width: 35,
                      height: 35,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        border: Border.all(color: kActiveColor, width: 2),
                        color: Colors.black.withOpacity(.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Icon(
                          FluentIcons.check_mark,
                          color: kActiveColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}