import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/rust/api/archive.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:path/path.dart' as p;

class CollectionExportDialog extends StatefulWidget {
  const CollectionExportDialog({
    required this.collection,
    super.key,
  });

  final ModCollectionMetaData collection;

  @override
  State<CollectionExportDialog> createState() => _CollectionExportDialogState();
}

class _CollectionExportDialogState extends State<CollectionExportDialog> {
  late List<File> modFiles;
  bool exporting = false;
  bool exportFiles = false;

  int current = 0;
  late int total;

  @override
  void initState() {
    final basePath = ModService.getBasePath();
    final mods = widget.collection.getLocalMods().map((e) {
      return File(p.join(basePath, e!.filename));
    }).toList();

    for (final col in widget.collection.getLocalMods().where(
      (x) => x!.isCollection,
    )) {
      for (final mod in col!.getMods()!) {
        mods.add(File(p.join(basePath, mod)));
      }
    }

    modFiles = mods;

    super.initState();
  }

  Future<void> exportCollection(File file) async {
    await ModCollection.writeCollection(file, metaData: widget.collection);
  }

  Future<void> exportCollectionWithFiles(File file) {
    total = modFiles.length - 1;
    return ModCollection.writeCollection(
      file,
      metaData: widget.collection,
      modFiles: modFiles,
      onProgress: (current, total) {
        if (!mounted) return;

        setState(() {
          this.current = current;
        });

        if (total == current) {
          setState(() => exporting = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: const Text('Exporting Collection'),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 400),
      content: Builder(
        builder: (context) {
          if (!exporting) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Exporting ${widget.collection.title}',
                style: FluentTheme.of(context).typography.subtitle?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ProgressBar(
                value: current == 0 ? 0 : (current / total) * 100,
              ),
              const SizedBox(height: 5),
              Text(
                'Exported $current of $total files',
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: FontFamily.battlefrontUI,
                  color: kWhiteColor,
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        if (!exporting) ...[
          KyberButton(
            text: 'CLOSE',
            onPressed: () => Navigator.of(context).pop(),
          ),
          KyberButton(
            text: 'EXPORT FILES',
            onPressed: () async {
              total = modFiles.length - 1;
              await Future<void>.value().then((_) async {
                print('Exporting collection with files');
                final file = await FilePicker.platform.saveFile(
                  allowedExtensions: ['tar'],
                  dialogTitle: 'Export Collection',
                  type: FileType.custom,
                );

                if (file == null) {
                  print('User cancelled');
                  return;
                }

                final tempDir = await Directory.systemTemp.createTemp(
                  'kyber_launcher',
                );
                final tempCollectionFile = p.join(
                  tempDir.path,
                  '${widget.collection.title}.kbcollection',
                );
                print('Exporting collection to $tempCollectionFile');
                await exportCollection(File(tempCollectionFile));
                await Future.delayed(Duration(seconds: 1));

                setState(() => exporting = true);
                final completer = Completer<void>();
                final paths = modFiles.map((e) => e.path).toList()
                  ..add(tempCollectionFile);
                compressTar(
                  filePaths: paths,
                  targetFile: file,
                ).listen(
                  (event) {
                    setState(() {
                      current = event.$1;
                      total = event.$2;
                    });

                    if (event.$1 == event.$2) {
                      completer.complete();
                    }
                  },
                  onDone: completer.complete,
                  onError: completer.complete,
                  cancelOnError: true,
                );

                await completer.future;

                setState(() => exporting = false);
              });
            },
          ),
        ],
      ],
    );
  }
}
