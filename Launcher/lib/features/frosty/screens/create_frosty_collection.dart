import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/frosty/helper/frosty_collection_writer.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:path/path.dart' as p;

class CreateFrostyCollection extends StatefulWidget {
  const CreateFrostyCollection({super.key});

  @override
  State<CreateFrostyCollection> createState() => _CreateFrostyCollectionState();
}

class _CreateFrostyCollectionState extends State<CreateFrostyCollection> {
  final nameController = TextEditingController();
  final versionController = TextEditingController();
  final descriptionController = TextEditingController();
  final categoryController = TextEditingController();
  final authorController = TextEditingController();

  final mods = <FrostyMod>[];
  Uint8List? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 15,
      children: [
        Expanded(
          child: KyberCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      KyberButton(
                        text: 'LOAD MODS',
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            allowedExtensions: ['fbmod'],
                            allowMultiple: true,
                            dialogTitle: 'Select mods',
                            type: .custom,
                          );

                          if (result.isEmpty) {
                            return;
                          }

                          final paths = result.map((e) => e.path!).toList();

                          for (final path in List<String>.from(paths)) {
                            if (mods.map((e) => e.filename).contains(path)) {
                              paths.remove(path);
                              NotificationService.error(
                                message:
                                    'Ignoring ${p.basename(path)}. (Duplicate)',
                              );
                            }
                          }

                          final loadedMods = await compute(
                            _loadMods,
                            paths as List<dynamic>,
                          );

                          String? mostCommonCategory;
                          if (loadedMods.isNotEmpty) {
                            final categories = loadedMods
                                .map((e) => e.details.category)
                                .toList();
                            final categoryCount = categories
                                .fold<Map<String, int>>({}, (prev, element) {
                                  prev[element] = (prev[element] ?? 0) + 1;
                                  return prev;
                                });
                            final sortedCategories =
                                categoryCount.entries.toList()
                                  ..sort((a, b) => b.value.compareTo(a.value));
                            mostCommonCategory = sortedCategories.first.key;
                          }

                          if (categoryController.text.isEmpty &&
                              mostCommonCategory != null) {
                            categoryController.text = mostCommonCategory;
                          }

                          setState(() {
                            mods.addAll(loadedMods);
                          });
                        },
                      ),
                      KyberButton(
                        text: 'EXPORT',
                        onPressed: () async {
                          //final targetFile = await FilePicker.platform.saveFile(
                          //  dialogTitle: 'Save collection',
                          //  allowedExtensions: ['fbcollection'],
                          //  fileName: 'collection.fbcollection',
                          //  type: FileType.custom,
                          //);
                          final targetFileZip = await FilePicker.saveFile(
                            dialogTitle: 'Save collection',
                            allowedExtensions: ['zip'],
                            fileName: 'collection.zip',
                            bytes: Uint8List(0),
                            type: FileType.custom,
                          );
                          if (targetFileZip == null) {
                            return;
                          }

                          final paths = mods.map((e) => e.filename).toList();

                          final data = FrostyCollectionWriter(
                            FrostyCollection(
                              manifest: FrostyCollectionManifest(
                                link: '',
                                title: nameController.text,
                                author: authorController.text,
                                version: versionController.text,
                                description: descriptionController.text,
                                category: categoryController.text,
                                mods: mods
                                    .map((e) => p.basename(e.filename))
                                    .toList(),
                                modVersions: mods
                                    .map((e) => e.details.version)
                                    .toList(),
                              ),
                              icon: icon,
                            ),
                          ).write();

                          await showKyberDialog(
                            context: context,
                            builder: (_) => _ExportCollectionDialog(
                              filePaths: paths,
                              targetFile: targetFileZip!.path,
                              collectionData: data,
                              title: nameController.text,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const CardSection(),
                Expanded(
                  child: ReorderableListView.builder(
                    itemExtent: 42,
                    proxyDecorator: (child, index, animation) {
                      return child;
                    },
                    itemBuilder: (context, index) {
                      final mod = mods[index];
                      return BackgroundBlur(
                        key: ValueKey(index),
                        child: ButtonBuilder(
                          onClick: () {},
                          hoverEffectOnly: true,
                          builder: (context, hovered) {
                            final borderSide = BorderSide(
                              color: hovered ? kActiveColor : decoColor,
                              width: 1.25,
                            );
                            final child = ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                alignment: Alignment.centerLeft,
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: borderSide,
                                    bottom: borderSide,
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.zero.copyWith(right: 25),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        height: 42,
                                        width: 42,
                                        child: Stack(
                                          children: [
                                            if (mod.icon != null)
                                              Image.memory(
                                                mod.icon!,
                                                width: 42,
                                                height: 42,
                                              ),
                                            if (hovered)
                                              Positioned.fill(
                                                child: ColoredBox(
                                                  color: Colors.black
                                                      .withValues(alpha: .6),
                                                  child: Container(
                                                    height: 42,
                                                    width: 42,
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    child: CustomIconButton(
                                                      iconData:
                                                          FluentIcons.delete,
                                                      size: 18,
                                                      onPressed: () {
                                                        setState(() {
                                                          mods.remove(mod);
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          style: TextStyle(
                                            color: hovered
                                                ? kActiveColor
                                                : kWhiteColor,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                mod.details.name,
                                                style: const TextStyle(
                                                  fontFamily:
                                                      FontFamily.battlefrontUI,
                                                  fontSize: 17,
                                                  height: 1,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                mod.details.version,
                                                style: const TextStyle(
                                                  fontFamily:
                                                      FontFamily.battlefrontUI,
                                                  fontSize: 14,
                                                  color: kButtonBorder,
                                                  height: 1,
                                                ),
                                                overflow: TextOverflow.ellipsis,
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
                            return child;
                          },
                        ),
                      );
                    },
                    itemCount: mods.length,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final mod = mods.removeAt(oldIndex);
                        mods.insert(newIndex, mod);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Flexible(
          child: KyberCard(
            child: Column(
              spacing: 15,
              children: [
                Row(
                  spacing: 15,
                  children: [
                    ButtonBuilder(
                      onClick: () async {
                        final result = await FilePicker.pickFiles(
                          allowedExtensions: ['png', 'jpg', 'jpeg'],
                          dialogTitle: 'Select icon',
                          type: FileType.custom,
                        );

                        if (result.isEmpty) {
                          return;
                        }

                        final file = File(result.single.path!);
                        icon = await file.readAsBytes();
                        setState(() {});
                      },
                      builder: (context, hovered) {
                        return Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: hovered
                                  ? kActiveColor
                                  : kDefaultBorder.color,
                              width: kDefaultBorder.width,
                            ),
                            borderRadius: BorderRadius.circular(
                              kDefaultInnerBorderRadius,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              kDefaultInnerBorderRadius,
                            ),
                            child: SizedBox(
                              height: 42,
                              width: 42,
                              child: Stack(
                                children: [
                                  if (icon != null)
                                    Image.memory(
                                      icon!,
                                      width: 42,
                                      height: 42,
                                    ),
                                  if (icon == null)
                                    Center(
                                      child: Text(
                                        'ICON',
                                        style: TextStyle(
                                          color: kButtonBorder,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  if (hovered)
                                    Positioned.fill(
                                      child: ColoredBox(
                                        color: Colors.black.withValues(
                                          alpha: .6,
                                        ),
                                        child: Container(
                                          height: 42,
                                          width: 42,
                                          padding: const EdgeInsets.all(5),
                                          child: Icon(
                                            FluentIcons.add,
                                            color: kActiveColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: KyberInput(
                        placeholder: 'Name',
                        controller: nameController,
                      ),
                    ),
                  ],
                ),
                KyberInput(
                  placeholder: 'Author',
                  controller: authorController,
                ),
                KyberInput(
                  placeholder: 'Version',
                  controller: versionController,
                ),
                KyberInput(
                  placeholder: 'Category',
                  controller: categoryController,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Future<List<FrostyMod>> _loadMods(List<dynamic> args) async {
  final loadedMods = <FrostyMod>[];

  await Future.forEach(List<String>.from(args), (String x) async {
    try {
      final file = await File(x).open();
      final mod = ModReader(file, x).readMod();
      if (mod != null) {
        loadedMods.add(mod);
      }
    } catch (e) {
      print('Failed to load mod: $e');
    }
  });

  return loadedMods;
}

class _ExportCollectionDialog extends StatefulWidget {
  const _ExportCollectionDialog({
    required this.filePaths,
    required this.targetFile,
    required this.collectionData,
    required this.title,
    super.key,
  });

  final List<String> filePaths;
  final String targetFile;
  final String title;
  final Uint8List collectionData;

  @override
  State<_ExportCollectionDialog> createState() =>
      _ExportCollectionDialogState();
}

class _ExportCollectionDialogState extends State<_ExportCollectionDialog> {
  late (int, int) progress;

  @override
  void initState() {
    /*progress = (1, widget.filePaths.length);
    print(widget.filePaths);
    compress(filePaths: widget.filePaths, targetFile: widget.targetFile).listen((event) {
      print(event);
      if (event.$2 - 1 == event.$1) {
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        progress = event;
      });
    });*/
    progress = (0, widget.filePaths.length - 1);
    Timer.run(() async {
      final encoder = ZipFileEncoder()
        ..create(widget.targetFile)
        ..addArchiveFile(
          ArchiveFile.bytes(
            '${widget.title}.fbcollection',
            widget.collectionData,
          ),
        );

      for (final file in widget.filePaths) {
        print('Adding file: $file');
        await encoder.addFile(File(file));
        setState(() {
          progress = (progress.$1 + 1, progress.$2);
        });
      }

      await encoder.close();
      Navigator.of(context).pop();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('EXPORT COLLECTION'),
      constraints: BoxConstraints(maxWidth: 600, maxHeight: 400),
      content: Column(
        children: [
          Text('Exporting collection...'),
          ProgressBar(
            value: ((progress.$1) / progress.$2) * 100,
          ),
          Text(p.basename(widget.filePaths[progress.$1])),
        ],
      ),
    );
  }
}
