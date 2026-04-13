import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:path/path.dart';

class MoveModsDirectoryDialog extends StatefulWidget {
  const MoveModsDirectoryDialog({super.key, this.isInvalid = false});

  final bool isInvalid;

  @override
  State<MoveModsDirectoryDialog> createState() =>
      _MoveModsDirectoryDialogState();
}

class _MoveModsDirectoryDialogState extends State<MoveModsDirectoryDialog> {
  late TextEditingController controller;
  bool moveMods = false;

  @override
  void initState() {
    controller = TextEditingController(text: ModService.getBasePath());
    super.initState();
  }

  Future<bool> requiresAdminPermissions(String directoryPath) async {
    try {
      final testFile = File('$directoryPath/test_permission_check.tmp');
      await testFile.writeAsString('test', flush: true);
      await testFile.delete();
      return false;
    } catch (e) {
      if (e is FileSystemException) {
        return true;
      }

      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return KyberContentDialog(
      constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
      title: Text(l10n.moveModsDirectory),
      content: Column(
        children: [
          if (widget.isInvalid) ...[
            BackgroundBlur(
              borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    kDefaultInnerBorderRadius,
                  ),
                  border: Border.all(color: kActiveColor, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                  child: Text(
                    l10n.invalidDirectoryWarning,
                    style: TextStyle(
                      fontFamily: currentFont,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
          ],
          Center(
            child: Text(
              l10n.selectNewDirectoryDesc,
              style: FluentTheme.of(
                context,
              ).typography.body?.copyWith(color: kWhiteColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: Text(
              l10n.nonAsciiWarning,
              style: FluentTheme.of(
                context,
              ).typography.body?.copyWith(color: kWhiteColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: KyberInput(
                  controller: controller,
                  disabled: true,
                ),
              ),
              const SizedBox(width: 20),
              KyberButton(
                onPressed: () async {
                  var path = await getDirectoryPath();
                  if (path == null) {
                    return;
                  }

                  if (path.substring(3).isEmpty) {
                    path = join(path, 'Mods');
                  }

                  final requiresAdmin = await requiresAdminPermissions(path);
                  if (requiresAdmin) {
                    NotificationService.error(
                      message: l10n.adminPermissionError,
                    );
                    return;
                  }

                  final containsNonAscii = path.codeUnits.any(
                    (element) => element > 127,
                  );
                  if (containsNonAscii) {
                    NotificationService.error(
                      message: l10n.selectedDirNonAsciiError,
                    );
                    return;
                  }

                  setState(() => controller.text = path!);
                },
                text: l10n.browse,
              ),
            ],
          ),
        ],
      ),
      actions: [
        KyberButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          text: l10n.cancel,
        ),
        KyberButton(
          text: l10n.resetToDefault,
          onPressed: () async {
            if (!FileHelper.getModsDirectory().existsSync()) {
              await FileHelper.getModsDirectory().create(recursive: true);
            }

            final path = FileHelper.getModsDirectory().path;
            if (path.codeUnits.any((element) => element > 127)) {
              NotificationService.error(
                message: l10n.defaultDirNonAsciiError,
              );
              return;
            }

            await ModService.setBasePath(path);

            await sl.unregister<ModService>();
            sl.registerSingletonAsync<ModService>(ModService.getInstance);

            Navigator.of(context).pop();
          },
        ),
        KyberButton(
          onPressed: () async {
            if (controller.text.codeUnits.any((element) => element > 127)) {
              NotificationService.error(
                message: l10n.defaultDirNonAsciiError,
              );
              return;
            }

            await ModService.setBasePath(controller.text);
            await sl.unregister<ModService>();
            sl.registerSingletonAsync<ModService>(ModService.getInstance);
            Navigator.of(context).pop();
          },
          text: l10n.change,
        ),
      ],
    );
  }
}