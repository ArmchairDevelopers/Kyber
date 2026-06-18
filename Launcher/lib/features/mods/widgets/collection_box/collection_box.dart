import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/helper/maxima_helper.dart';
import 'package:kyber_launcher/features/mod_browser/dialogs/export_collection_dialog.dart';
import 'package:kyber_launcher/features/mod_collections/dialogs/delete_collection_dialog.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mods/dialogs/collection_export_dialog.dart';
import 'package:kyber_launcher/features/mods/dialogs/image_crop_dialog.dart';
import 'package:kyber_launcher/features/mods/providers/collection_editor_cubit.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_icon.dart';
import 'package:kyber_launcher/features/plugin_manager/services/plugin_manager.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/dropdown/kyber_dropdown_button.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tooltip.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:path/path.dart' hide Context, context;
import 'package:uuid/uuid.dart';

class CollectionBox extends StatefulWidget {
  const CollectionBox({super.key});

  @override
  State<CollectionBox> createState() => _CollectionBoxState();
}

class _CollectionBoxState extends State<CollectionBox> {
  int? dragIndex;
  int pageIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  void pickIcon() async {
    final currentCollection = context
        .read<CollectionEditorCubit>()
        .state
        .selectedCollection!;
    if (currentCollection.icon != null) {
      context.read<CollectionEditorCubit>().changeIcon(null);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
      dialogTitle: 'Select Collection Icon',
      type: FileType.custom,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = File(result.files.first.path!);
    final bytes = await file.readAsBytes();
    final imageCropResult = switch (extension(file.path)) {
      '.gif' => bytes,
      _ => await showKyberDialog<Uint8List?>(
        context: context,
        builder: (context) => ImageCropDialog(
          imageData: bytes,
        ),
      ),
    };

    if (imageCropResult == null) {
      return;
    }

    context.read<CollectionEditorCubit>().changeIcon(imageCropResult);
  }

  @override
  Widget build(BuildContext context) {
    final collection = context
        .watch<CollectionEditorCubit>()
        .state
        .selectedCollection!;
    return KyberCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
            builder: (context, state) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 61,
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'COLLECTION',
                                  style: TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 21,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  'A COLLECTION IS A READY TO PLAY MOD LIST',
                                  style: TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 14,
                                    color: kWhiteColor,
                                    height: 0.9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          KyberIconButton(
                            onPressed: () => context
                                .read<CollectionEditorCubit>()
                                .clearCollection(),
                            iconData: mt.Icons.close,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const CardSection(),
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 45,
                              width: 45,
                              child: ClipRRect(
                                borderRadius: .circular(
                                  kDefaultInnerBorderRadius,
                                ),
                                child: Stack(
                                  children: [
                                    CollectionIcon(
                                      key: ValueKey(
                                        collection.mods.length + pageIndex,
                                      ),
                                      collection: state.selectedCollection!,
                                    ),
                                    if (state.editing)
                                      Positioned.fill(
                                        child: ColoredBox(
                                          color: Colors.black.withOpacity(.5),
                                          child: CustomIconButton(
                                            onPressed: () => pickIcon(),
                                            iconData:
                                                state
                                                        .selectedCollection
                                                        ?.icon !=
                                                    null
                                                ? mt.Icons.delete
                                                : mt.Icons.edit,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!state.editing) ...[
                                  Text(
                                    collection.title,
                                    style: const TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 19,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    '${collection.getModPaths().length} Mods',
                                    style: const TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 15,
                                      color: kWhiteColor,
                                    ),
                                  ),
                                ],
                                if (state.editing)
                                  SizedBox(
                                    width: 250,
                                    child: KyberInput(
                                      initialValue: collection.title,
                                      placeholder: 'Collection Name',
                                      onFieldSubmitted: (_) => context
                                          .read<CollectionEditorCubit>()
                                          .saveCollection(),
                                      onChanged: context
                                          .read<CollectionEditorCubit>()
                                          .changeTitle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!state.editing)
                              KyberButton(
                                text: 'PLAY',
                                icon: const Icon(mt.Icons.play_arrow_rounded),
                                onPressed: () => MaximaHelper.requestGameLaunch(
                                  context,
                                  modCollection: collection,
                                ),
                              ),
                            if (state.editing)
                              KyberButton(
                                text: 'SAVE',
                                icon: const Icon(mt.Icons.save),
                                onPressed: () => context
                                    .read<CollectionEditorCubit>()
                                    .saveCollection(),
                              ),
                            //SizedBox(
                            //  width: 100,
                            //  height: 35,
                            //  child: KyberTabBar(
                            //    tabs: [
                            //      Icon(mt.Icons.storage),
                            //      Text('0 GB'),
                            //    ],
                            //    selectedIndex: -1,
                            //  ),
                            //),
                            SizedBox(
                              width: 200,
                              child: KyberDropdownSelector(
                                items: [
                                  if (sl.get<PluginManager>().bsmPlugin != null)
                                    DropdownOption(
                                      label: 'BETTER SABERS (PLUGIN)',
                                      icon: Assets.icons.laserSword.svg(
                                        width: 15,
                                        height: 15,
                                      ),
                                      onClick: () async {
                                        final result = await sl
                                            .get<PluginManager>()
                                            .bsmPlugin!
                                            .generateFile(
                                              ModService.getBasePath(),
                                              collection.getModPaths(),
                                              collection.title,
                                            );

                                        if (result.isEmpty) {
                                          return;
                                        }

                                        final bsmIndex = collection.mods
                                            .indexWhere(
                                              (e) =>
                                                  e.filename!.contains('.bsm.'),
                                            );
                                        if (bsmIndex != -1) {
                                          await context
                                              .read<CollectionEditorCubit>()
                                              .removeMod(bsmIndex);
                                        }

                                        NotificationService.showNotification(
                                          message: 'Reloading mods',
                                          severity: InfoBarSeverity.info,
                                        );

                                        final newPath = join(
                                          ModService.getBasePath(),
                                          basename(result),
                                        );
                                        await File(result).copy(newPath);
                                        await sl.get<ModService>().refresh();

                                        final mod = sl
                                            .get<ModService>()
                                            .hiddenMods
                                            .firstWhere(
                                              (e) =>
                                                  e.filename ==
                                                  basename(result),
                                            );
                                        context
                                            .read<CollectionEditorCubit>()
                                            .addMod(
                                              mod,
                                              force: true,
                                              save: true,
                                            );
                                        context
                                            .read<CollectionEditorCubit>()
                                            .saveCollection();

                                        NotificationService.showNotification(
                                          message: 'Generated BetterSabers',
                                          severity: InfoBarSeverity.success,
                                        );
                                      },
                                    ),
                                  DropdownOption(
                                    label: 'EXPORT COLLECTION TAR',
                                    icon: const Icon(
                                      mt.Icons.account_balance_wallet,
                                    ),
                                    onClick: () async {
                                      await showKyberDialog(
                                        context: context,
                                        builder: (context) =>
                                            CollectionExportDialog(
                                              collection: collection,
                                            ),
                                      );
                                    },
                                  ),
                                  DropdownOption(
                                    label: 'EDIT COLLECTION',
                                    icon: const Icon(mt.Icons.edit),
                                    onClick: () async {
                                      context
                                          .read<CollectionEditorCubit>()
                                          .editCollection();
                                    },
                                  ),
                                  DropdownOption(
                                    label: 'EXPORT COLLECTION',
                                    icon: Icon(mt.Icons.upload),
                                    onClick: () async {
                                      await showKyberDialog(
                                        context: context,
                                        builder: (context) =>
                                            ExportCollectionDialog(
                                              collection: collection,
                                            ),
                                      );
                                    },
                                  ),
                                  DropdownOption(
                                    label: 'CREATE A COPY',
                                    icon: Icon(FluentIcons.copy),
                                    onClick: () {
                                      final currentCollection = context
                                          .read<CollectionEditorCubit>()
                                          .state
                                          .selectedCollection!;
                                      final newCollection = currentCollection
                                          .copyWith(
                                            localId: const Uuid().v4(),
                                            title:
                                                '${currentCollection.title} (Copy)',
                                          );

                                      context.read<CollectionEditorCubit>()
                                        ..selectCollection(newCollection)
                                        ..editCollection();
                                    },
                                  ),
                                  DropdownOption(
                                    label: 'DELETE COLLECTION',
                                    icon: Icon(
                                      FluentIcons.delete,
                                      color: Colors.red,
                                    ),
                                    baseColor: Colors.red,
                                    onClick: () async {
                                      final result = await showKyberDialog(
                                        context: context,
                                        builder: (context) =>
                                            DeleteCollectionDialog(
                                              collection: collection,
                                            ),
                                      );
                                      if (result == true) {
                                        context
                                            .read<CollectionEditorCubit>()
                                            .clearCollection();
                                      }
                                    },
                                  ),
                                ],
                                placeholder: 'OPTIONS',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const CardSection(),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: state.editing,
                      onReorderStart: (index) {
                        setState(() {
                          dragIndex = index;
                        });
                      },
                      onReorderEnd: (index) {
                        setState(() {
                          dragIndex = null;
                        });
                      },
                      itemExtent: 42,
                      proxyDecorator: (child, index, animation) {
                        return child;
                      },
                      itemBuilder: (context, index) {
                        final collectionMod = collection.mods.elementAt(index);
                        final bigMods = collection
                            .getLocalMods()
                            .where(
                              (mod) =>
                                  (mod?.size ?? 0) > 1 * 1024 * 1024 * 1024,
                            )
                            .toList();
                        final isBigMod = bigMods.any(
                          (mod) => mod?.filename == collectionMod.filename,
                        );
                        final mod = collection.getLocalMods().elementAt(index);
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
                                enabled: state.editing,
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
                                    padding: EdgeInsets.zero.copyWith(
                                      right: 25,
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          height: 42,
                                          width: 42,
                                          child: Stack(
                                            children: [
                                              if (mod?.icon != null)
                                                Image.memory(
                                                  mod!.icon!,
                                                  width: 42,
                                                  height: 42,
                                                ),
                                              if (mod?.icon == null &&
                                                  (!hovered && state.editing ||
                                                      !state.editing))
                                                const SizedBox(
                                                  width: 42,
                                                  height: 42,
                                                  child: Placeholder(),
                                                ),
                                              if ((!state.editing &&
                                                      mod == null) &&
                                                  (!hovered && state.editing ||
                                                      !state.editing))
                                                Positioned.fill(
                                                  child: ColoredBox(
                                                    color: Colors.black
                                                        .withOpacity(.5),
                                                    child: Icon(
                                                      FluentIcons.error_badge,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              if ((isBigMod &&
                                                      bigMods.length > 1) &&
                                                  (!hovered && state.editing ||
                                                      !state.editing))
                                                Positioned.fill(
                                                  child: ColoredBox(
                                                    color: Colors.black
                                                        .withOpacity(.5),
                                                    child: KyberTooltip(
                                                      message:
                                                          "Using multiple large or complex mods isn't recommended, as they often conflict with each other.",
                                                      child: Icon(
                                                        FluentIcons.warning,
                                                        color: Colors.yellow,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              if (state.editing && hovered)
                                                Positioned.fill(
                                                  child: Container(
                                                    height: 42,
                                                    width: 42,
                                                    color: Colors.black
                                                        .withOpacity(.5),
                                                    padding:
                                                        const EdgeInsets.all(5),
                                                    child: CustomIconButton(
                                                      iconData:
                                                          FluentIcons.delete,
                                                      size: 18,
                                                      onPressed: () {
                                                        context
                                                            .read<
                                                              CollectionEditorCubit
                                                            >()
                                                            .removeMod(index);
                                                      },
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
                                                  mod?.details.name ??
                                                      collectionMod.name,
                                                  style: const TextStyle(
                                                    fontFamily: FontFamily
                                                        .battlefrontUI,
                                                    fontSize: 17,
                                                    height: 1,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  mod?.details.version ??
                                                      collectionMod.version,
                                                  style: const TextStyle(
                                                    fontFamily: FontFamily
                                                        .battlefrontUI,
                                                    fontSize: 14,
                                                    color: kButtonBorder,
                                                    height: 1,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                      itemCount: collection.mods.length,
                      onReorder: (oldIndex, newIndex) => context
                          .read<CollectionEditorCubit>()
                          .moveMod(oldIndex, newIndex),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
