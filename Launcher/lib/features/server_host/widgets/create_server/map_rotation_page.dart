import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/kyber/extensions/map_extension.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/map_rotation/dialogs/export_rotation_dialog.dart';
import 'package:kyber_launcher/features/map_rotation/models/map_rotation_entry.dart';
import 'package:kyber_launcher/features/map_rotation/providers/map_rotation_cubit.dart';
import 'package:kyber_launcher/features/mods/services/level_declaration_service.dart';
import 'package:kyber_launcher/features/server_host/providers/host_collection_cubit.dart';
import 'package:kyber_launcher/features/server_host/providers/host_search_cubit.dart';
import 'package:kyber_launcher/features/server_host/widgets/create_server/map_rotation/map_list.dart';
import 'package:kyber_launcher/features/server_host/widgets/create_server/map_rotation/mode_list.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/header/kyber_header.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tooltip.dart';
import 'package:tinycolor2/tinycolor2.dart';

class MapRotationPage extends StatefulWidget {
  const MapRotationPage({super.key});

  @override
  State<MapRotationPage> createState() => _MapRotationPageState();
}

class _MapRotationPageState extends State<MapRotationPage> {
  bool edit = false;
  Mode? selectedMode;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MapRotationCubit>();
    final kyberState = context.watch<KyberStatusCubit>().state;

    return BlocListener<MapRotationCubit, MapRotationState>(
      listener: (context, state) => saveRotation(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                KyberHeader(
                  title: 'Active Rotation',
                  headerLength: 130,
                  headerPadding: const EdgeInsets.only(left: 15, right: 10),
                  sections: [
                    ExpandedHeaderSection(
                      children: [
                        HeaderIconButton(
                          icon: mt.Icons.undo,
                          onClick: cubit.undo,
                        ),
                        const HeaderDivider(),
                        HeaderIconButton(
                          icon: mt.Icons.redo,
                          onClick: cubit.redo,
                        ),
                        const HeaderDivider(),
                        HeaderIconButton(
                          icon: mt.Icons.shuffle,
                          onClick: cubit.shuffle,
                        ),
                      ],
                    ),
                    DefaultHeaderSection(
                      children: [
                        const SizedBox(width: 10),
                        HeaderButton(
                          title: 'Reset',
                          onClick: cubit.clear,
                        ),
                        const HeaderDivider(),
                        HeaderButton(
                          title: 'Export',
                          onClick: () async {
                            await showKyberDialog(
                              context: context,
                              builder: (context) => BlocProvider.value(
                                value: context.read<MapRotationCubit>(),
                                child: const ExportRotationDialog(),
                              ),
                            );
                          },
                        ),
                        const HeaderDivider(),
                        HeaderButton(
                          title: 'Import',
                          onClick: () async {
                            final filePath = await FilePicker.pickFiles(
                              allowedExtensions: ['txt', 'json'],
                              dialogTitle: 'Import Map Rotation',
                              type: FileType.custom,
                            );

                            if (filePath.isEmpty) {
                              return;
                            }

                            final file = filePath.first;
                            if (file.path == null) {
                              return;
                            }

                            final data = await File(file.path!).readAsString();

                            final rotation = <Map<String, String>>[];
                            try {
                              try {
                                final list = List<dynamic>.from(
                                  jsonDecode(data) as List<dynamic>,
                                );
                                for (final entry in list) {
                                  rotation.add({
                                    'mode': ?entry['mode'] as String?,
                                    'map': ?entry['map'] as String?,
                                  });
                                }

                                return;
                              } catch (e) {
                                print(e);
                              }

                              // check if data is base64
                              final decoded = base64.decode(data);
                              final decodedString = utf8.decode(decoded);
                              final lines = decodedString.split('\n');
                              for (final line in lines) {
                                final parts = line.split(';');
                                if (parts.length != 2) {
                                  continue;
                                }
                                rotation.add({
                                  'mode': parts[0],
                                  'map': parts[1],
                                });
                              }
                            } finally {
                              if (rotation.isEmpty) {
                                NotificationService.error(
                                  message: 'Invalid file format',
                                );
                                return;
                              }

                              final maps = <MapRotationEntry>[];
                              for (final entry in rotation) {
                                maps.add(
                                  MapRotationEntry(
                                    mode: entry['mode']!,
                                    map: entry['map']!,
                                  ),
                                );
                              }

                              context.read<MapRotationCubit>().setMaps(maps);
                              NotificationService.info(
                                message: 'Map rotation imported',
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ],
                ),
                const CardSection(),
                Expanded(
                  child: BlocBuilder<MapRotationCubit, MapRotationState>(
                    bloc: context.read<MapRotationCubit>(),
                    builder: (context, state) {
                      if (state.maps.isEmpty) {
                        return Align(
                          alignment: Alignment.topCenter,
                          child: Text(
                            'No maps active'.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontFamily: FontFamily.battlefrontUI,
                              color: kInactiveColor,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ReorderableListView.builder(
                              onReorder: (oldIndex, newIndex) {
                                context.read<MapRotationCubit>().moveMap(
                                  oldIndex,
                                  newIndex,
                                );
                              },
                              itemBuilder: (context, index) {
                                final item = state.maps[index];

                                final customMap = sl
                                    .get<LevelDeclarationService>()
                                    .getMapByMode(
                                      map: item.map,
                                      mode: item.mode,
                                      collection: context
                                          .read<HostCollectionCubit>()
                                          .state
                                          .selectedModCollection,
                                    );

                                final map = MapHelper.getMap(
                                  item.mode,
                                  item.map,
                                );

                                return _ActiveMap(
                                  key: ValueKey(index),
                                  map: customMap ?? map,
                                  mode: context
                                      .read<HostCollectionCubit>()
                                      .state
                                      .getMode(item.mode),
                                  index: index,
                                  onRemove: () {
                                    context.read<MapRotationCubit>().removeMap(
                                      item,
                                    );
                                  },
                                );
                              },
                              buildDefaultDragHandles: false,
                              itemCount: state.maps.length,
                            ),
                          ),
                        ],
                      );
                    },
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
            child: BlocBuilder<MapRotationCubit, MapRotationState>(
              bloc: context.read<MapRotationCubit>(),
              builder: (context, snapshot) {
                if (selectedMode != null) {
                  return MapList(
                    selectedMode: selectedMode,
                    onBack: () {
                      context.read<HostSearchCubit>().clear();
                      setState(() {
                        selectedMode = null;
                      });
                    },
                  );
                }

                return ModeList(
                  onModeSelected: (selectedMode) {
                    context.read<HostSearchCubit>().clear();
                    setState(() => this.selectedMode = selectedMode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> saveRotation() async {
    mapRotationBox.put(
      'current',
      List<MapRotationEntry>.from(
        context.read<MapRotationCubit>().state.maps,
      ),
    );
  }
}

class _ActiveMap extends StatelessWidget {
  const _ActiveMap({
    required this.mode,
    required this.index,
    required this.onRemove,
    this.map,
    super.key,
  });

  final int index;
  final void Function() onRemove;
  final KyberMap? map;
  final Mode mode;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: index,
      child: SizedBox(
        height: 45,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              bottom: BorderSide(
                color: decoColor,
                width: 2,
              ),
            ),
          ),
          child: Stack(
            children: [
              SizedBox(
                width: 350,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      colors: [
                        Colors.black.withOpacity(map == null ? 1 : .3),
                        Colors.transparent,
                      ],
                    ).createShader(
                      Rect.fromLTRB(0, 0, rect.width, rect.height),
                    );
                  },
                  blendMode: BlendMode.dstIn,
                  child:
                      map?.getImage(context) ??
                      Assets.images.kyberNoImage.image(fit: BoxFit.fitWidth),
                ),
              ),
              Center(
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: FluentTheme(
                        data: FluentTheme.of(context),
                        child: CustomSvgButton(
                          path: Assets.icons.kblDelete.path,
                          onPressed: onRemove,
                          size: 16,
                        ),
                      ),
                    ),
                    Container(
                      height: 48,
                      width: 2,
                      color: decoColor,
                    ),
                    const SizedBox(width: 10),
                    if (map == null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: KyberTooltip(
                          message:
                              'Custom map not found, this can happen if the map is not part of the current mod collection.\nThis map will be ignored when starting the server.',
                          child: Icon(
                            mt.Icons.warning_rounded,
                            size: 20,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        map?.name ?? 'Not found',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: FontFamily.battlefrontUI,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        mode.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontFamily: FontFamily.battlefrontUI,
                          color: kInactiveColor.darken(30),
                          height: 1.9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Transform.rotate(
                      // 90 degrees
                      angle: 1.57,
                      child: const Icon(
                        mt.Icons.drag_indicator,
                        size: 20,
                        color: kInactiveColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
