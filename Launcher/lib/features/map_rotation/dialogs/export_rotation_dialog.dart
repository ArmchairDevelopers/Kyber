import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/map_rotation/providers/map_rotation_cubit.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_segmented_control.dart';

enum _ExportType {
  base64,
  json,
}

class ExportRotationDialog extends StatefulWidget {
  const ExportRotationDialog({super.key});

  @override
  State<ExportRotationDialog> createState() => _ExportRotationDialogState();
}

class _ExportRotationDialogState extends State<ExportRotationDialog> {
  int selectedExportTypeIndex = 0;

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('Export Rotation'.toUpperCase()),
      constraints: const BoxConstraints(
        maxWidth: 700,
        maxHeight: 500,
      ),
      content: Column(
        children: [
          const Text('TYPE'),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              KyberSegmentedControl<_ExportType>(
                selectedIndex: selectedExportTypeIndex,
                items: _ExportType.values
                    .map(
                      (e) => KyberSegmentedControlItem(title: e.name, value: e),
                    )
                    .toList(),
                onSelected: (index) =>
                    setState(() => selectedExportTypeIndex = index),
              ),
            ],
          ),
        ],
      ),
      actions: [
        KyberButton(
          icon: const Icon(mt.Icons.save),
          onPressed: () async {
            final filePath = await FilePicker.saveFile(
              allowedExtensions: ['txt'],
              dialogTitle: 'Export Map Rotation',
              fileName: 'map_rotation.txt',
              bytes: Uint8List(0),
              type: .custom,
            );

            if (filePath != null) {
              final data = generateData(
                _ExportType.values[selectedExportTypeIndex],
              );
              await File(filePath.path).writeAsString(data);
              NotificationService.info(message: 'File saved');
              Navigator.of(context).pop();
            }
          },
          text: 'Save File',
        ),
        KyberButton(
          icon: const Icon(mt.Icons.copy),
          onPressed: () async {
            final data = generateData(
              _ExportType.values[selectedExportTypeIndex],
            );
            await Clipboard.setData(ClipboardData(text: data));
            NotificationService.info(message: 'Copied to clipboard');
            Navigator.of(context).pop();
          },
          text: 'COPY TO CLIPBOARD',
        ),
        KyberButton(
          onPressed: () => Navigator.of(context).pop(),
          text: 'Cancel',
        ),
      ],
    );
  }

  String generateData(_ExportType type) {
    final rotation = context.read<MapRotationCubit>().state.maps;
    final list = <Map<String, String>>[];
    for (final entry in rotation) {
      list.add({
        'mode': entry.mode,
        'map': entry.map,
      });
    }

    switch (type) {
      case _ExportType.base64:
        return base64Encode(
          utf8.encode(list.map((e) => '${e['mode']};${e['map']}').join('\n')),
        );
      case _ExportType.json:
        return const JsonEncoder.withIndent('  ').convert(list);
    }
  }
}
