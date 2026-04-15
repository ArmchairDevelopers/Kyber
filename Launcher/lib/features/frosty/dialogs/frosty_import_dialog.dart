import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/disk_helper.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/frosty/helper/frosty_migration_helper.dart';
import 'package:kyber_launcher/features/frosty/models/frosty_pack.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class FrostyImportDialog extends StatefulWidget {
  const FrostyImportDialog({super.key});

  @override
  State<FrostyImportDialog> createState() => _FrostyImportDialogState();
}

class _FrostyImportDialogState extends State<FrostyImportDialog> {
  final _logger = Logger('frosty_import');

  ModService? modService;
  Directory? frostyModDir;

  Map<String, List<String>> invalidPacks = {};
  List<FrostyPack> packs = [];

  Set<int> selectedPacks = {};
  Set<String> modsToImport = {};

  int page = 0;
  int current = 0;

  void updateModsToImport() {
    modsToImport.clear();
    for (final index in selectedPacks) {
      final pack = packs[index];
      for (final mod in pack.mods) {
        modsToImport.add(mod.filename);
      }
    }
  }

  List<String> getModsToImport() {
    final mods = <String>[];
    for (final index in selectedPacks) {
      final pack = packs[index];
      for (final mod in pack.mods) {
        mods.add(mod.filename);
        if (mod.isCollection) {
          for (final collectionMod in mod.mods!) {
            mods.add(collectionMod);
          }
        }
      }
    }

    return mods;
  }

  Future<void> copyMods() async {
    NotificationService.showNotification(
      message: 'Starting import...',
      severity: InfoBarSeverity.info,
    );

    final baseModDir = ModService.getBasePathAsDir();
    if (!Directory(p.join(baseModDir.path, 'frosty_import')).existsSync()) {
      Directory(p.join(baseModDir.path, 'frosty_import')).createSync();
    }

    for (final mod in getModsToImport()) {
      final file = File(p.join(frostyModDir!.path, mod));
      final newFile = File(p.join(baseModDir.path, 'frosty_import', mod));

      if (!newFile.existsSync()) {
        await file.copy(newFile.path);
      }

      if (current < getModsToImport().length - 1) {
        current++;
      }
      setState(() {});
    }

    _logger.info('Imported ${modsToImport.length} mods');
    await FrostyMigrationHelper.importFrostyPacks(
      packs: selectedPacks.map((e) => packs[e]).toList(),
    );
    await sl.get<ModService>().refresh();

    NotificationService.showNotification(
      message: 'Imported ${getModsToImport().length} mods',
      severity: InfoBarSeverity.success,
    );
    Navigator.of(context).pop();
  }

  int getModsToImportSize() {
    var size = 0;

    for (final file in modsToImport) {
      final fileSize =
          modService?.mods
              .firstWhereOrNull((element) => element.filename == file)
              ?.size ??
          0;
      size += fileSize;
    }

    return size;
  }

  @override
  void dispose() {
    modService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: const Text('FROSTY CONVERTER'),
      constraints: const BoxConstraints(
        maxWidth: 700,
        maxHeight: 500,
      ),
      content: Builder(
        builder: (context) {
          if (page == 0) {
            return const Text(
              'To import your Frosty packs into Kyber, you need to locate your Frosty Mod Manager executable.',
            );
          }

          if (page == 1) {
            return const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20, width: 20, child: ProgressRing()),
                  SizedBox(width: 10),
                  Text('Loading mod data...'),
                ],
              ),
            );
          }

          if (page == 3) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontSize: 17,
                      height: 1,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Copying mods...'),
                        Text('$current/${getModsToImport().length}'),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 20,
                    width: 200,
                    child: ProgressBar(
                      value: (current / getModsToImport().length) * 100,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Current File: ${getModsToImport().elementAt(current)}',
                    style: const TextStyle(
                      fontFamily: FontFamily.battlefrontUI,
                      fontSize: 15,
                      color: kWhiteColor,
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            );
          }

          if (page == 2) {
            return Column(
              children: [
                Text(
                  'Found ${packs.length} packs. Please select the packs you want to import.',
                  style: const TextStyle(
                    fontFamily: FontFamily.battlefrontUI,
                    color: kWhiteColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total size: ${formatBytes(getModsToImportSize(), 1)}',
                  style: const TextStyle(
                    fontFamily: FontFamily.battlefrontUI,
                    color: kWhiteColor,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      const itemHeight = 50;
                      final containerHeight =
                          (packs.length > 3 ? 3 : packs.length) * itemHeight;

                      return SizedBox(
                        height: containerHeight.toDouble() + 70,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CustomPainter(),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(.5),
                                margin: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 13,
                                ),
                                alignment: Alignment.center,
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(
                                    12,
                                  ).copyWith(top: 0, bottom: 0),
                                  shrinkWrap: true,
                                  itemBuilder: (context, index) {
                                    final pack = packs.elementAt(index);
                                    return Container(
                                      height: 50,
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      child: RadioGroup<int>(
                                        groupValue:
                                            selectedPacks.contains(index)
                                            ? index
                                            : null,
                                        onChanged: (value) {
                                          if (value != null) {
                                            selectedPacks.add(index);
                                          } else {
                                            selectedPacks.remove(index);
                                          }

                                          updateModsToImport();
                                          setState(() {});
                                        },
                                        child: RadioButton<int>(
                                          value: index,
                                          style: RadioButtonThemeData(
                                            checkedDecoration:
                                                WidgetStateProperty.resolveWith((
                                                  states,
                                                ) {
                                                  return BoxDecoration(
                                                    color: Colors.transparent,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: (states.isHovered)
                                                          ? kActiveColor
                                                          : kWhiteColor,
                                                      width: !states.isDisabled
                                                          ? states.isHovered &&
                                                                    !states
                                                                        .isPressed
                                                                ? 3.4
                                                                : 5.0
                                                          : 4.0,
                                                    ),
                                                  );
                                                }),
                                          ),
                                          content: Row(
                                            children: [
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: DefaultTextStyle.merge(
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: kButtonBorder,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            !invalidPacks.keys
                                                                    .contains(
                                                                      pack.packName,
                                                                    )
                                                                ? mt.Icons.check
                                                                : mt
                                                                      .Icons
                                                                      .warning,
                                                            color:
                                                                !invalidPacks
                                                                    .keys
                                                                    .contains(
                                                                      pack.packName,
                                                                    )
                                                                ? Colors.green
                                                                : Colors.red,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            pack.packName,
                                                            style: const TextStyle(
                                                              fontFamily: FontFamily
                                                                  .battlefrontUI,
                                                              fontSize: 20,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      if (invalidPacks.keys
                                                          .contains(
                                                            pack.packName,
                                                          ))
                                                        Expanded(
                                                          child: Text(
                                                            'Missing files: ${invalidPacks[pack.packName]!.join(', ')}',
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        )
                                                      else
                                                        Text(
                                                          '${formatBytes(pack.size, 1)} | ${pack.mods.length} Mods',
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  itemCount: packs.length,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }

          return const Placeholder();
        },
      ),
      actions: [
        if (page != 3)
          KyberButton(
            text: 'CLOSE',
            onPressed: () => Navigator.of(context).pop(),
          ),
        if (page == 0)
          KyberButton(
            text: 'LOCATE',
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                allowedExtensions: ['exe'],
                dialogTitle: 'Select the Frosty Mod Manager executable',
                type: FileType.custom,
              );

              if (result == null) {
                return;
              }

              setState(() => page = 1);

              try {
                _logger.info(
                  'Located Frosty Mod Manager executable at ${result.files.single.path}',
                );
                final directory = Directory(
                  p.dirname(result.files.single.path!),
                );
                final modsDirectory = Directory(
                  p.join(directory.path, 'Mods', 'starwarsbattlefrontii'),
                );
                final config = await FrostyMigrationHelper.readFrostyConfig(
                  frostyDirectory: directory,
                );
                _logger.fine('Frosty config: ${config.toJson()}');

                if (!config.games.containsKey('starwarsbattlefrontii') ||
                    !modsDirectory.existsSync()) {
                  NotificationService.showNotification(
                    message:
                        'No Star Wars Battlefront II game found in Frosty config',
                    severity: InfoBarSeverity.error,
                  );
                  return;
                }

                _logger.info('Loading mods...');
                modService = await ModService.getInstance(modsDirectory);
                frostyModDir = modsDirectory;
                final allMods = List.of(modService!.mods)
                  ..addAll(modService!.hiddenMods);
                final packData = config.games['starwarsbattlefrontii']!.packs;

                final packs = <FrostyPack>[];
                _logger.info('Loading ${packData!.length} packs...');
                for (final pack in packData.entries) {
                  final packName = pack.key;
                  final files = pack.value
                      .split('|')
                      .where((e) => e.endsWith(':True'))
                      .map((e) => e.split(':').first);

                  final packMods = files.map(
                    (e) => allMods.firstWhereOrNull((m) => m.filename == e),
                  );
                  if (packMods.any((element) => element == null)) {
                    final missingMods = files.where(
                      (e) =>
                          allMods.firstWhereOrNull((m) => m.filename == e) ==
                          null,
                    );
                    invalidPacks[pack.key] = missingMods.toList();
                  }

                  final validMods = packMods.whereType<FrostyMod>();
                  if (validMods
                      .where((t) => t.isCollection)
                      .where(
                        (t) => t.mods!.any(
                          (e) =>
                              allMods.firstWhereOrNull(
                                (m) => m.filename == e,
                              ) ==
                              null,
                        ),
                      )
                      .isNotEmpty) {
                    final missingMods = validMods
                        .where((t) => t.isCollection)
                        .expand((element) => element.mods!)
                        .where(
                          (e) =>
                              allMods.firstWhereOrNull(
                                (m) => m.filename == e,
                              ) ==
                              null,
                        );
                    invalidPacks[pack.key] = missingMods.toList();
                  }

                  final size = validMods.fold(
                    0,
                    (value, element) => value += element.size,
                  );
                  packs.add(
                    FrostyPack(
                      packName: packName,
                      size: size,
                      mods: validMods.toList(growable: false),
                    ),
                  );
                }

                final invalidIndexes = invalidPacks.keys
                    .map(
                      (e) =>
                          packs.indexWhere((element) => element.packName == e),
                    )
                    .toList();

                setState(() {
                  this.packs = packs;
                  selectedPacks = List.generate(
                    packs.length,
                    (index) => index,
                  ).toSet()..removeAll(invalidIndexes);
                  updateModsToImport();
                  page = 2;
                });
              } catch (e, s) {
                _logger.severe('Failed prepare import', e, s);
                NotificationService.showNotification(
                  title: 'Failed to prepare import',
                  message: e.toString(),
                  severity: InfoBarSeverity.error,
                );
                setState(() => page = 0);
              }
            },
          ),
        if (page == 2)
          KyberButton(
            text: 'IMPORT',
            onPressed: () async {
              NotificationService.showNotification(
                message: 'Starting import...',
                severity: InfoBarSeverity.success,
              );

              final size = getModsToImportSize();
              final diskInfo = DiskHelper.getDiskInfo(ModService.getBasePath());

              if (diskInfo.freeSpace < size) {
                NotificationService.showNotification(
                  message: 'Not enough space to import mods',
                  severity: InfoBarSeverity.error,
                );
                return;
              }

              setState(() => page = 3);
              copyMods();
            },
          ),
      ],
    );
  }
}

class _CustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path_0 = Path();
    path_0.moveTo(0, 18);
    path_0.lineTo(size.width, 18);

    path_0.moveTo(0, size.height - 18);
    path_0.lineTo(size.width, size.height - 18);

    // dash border on the left side. 10 pixels long, 4 pixels apart
    for (var i = 0; i < size.height; i += 20) {
      path_0.moveTo(12, i.toDouble());
      path_0.lineTo(12, i.toDouble() + 10);
    }

    for (var i = 0; i < size.height; i += 20) {
      path_0.moveTo(size.width - 12, i.toDouble());
      path_0.lineTo(size.width - 12, i.toDouble() + 10);
    }

    final paint_0 = Paint()
      ..color = kGrayColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path_0, paint_0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
