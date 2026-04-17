import 'package:auto_size_text/auto_size_text.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/frosty/widgets/mod_icon.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_details/mod_images.dart';
import 'package:kyber_launcher/features/mod_collections/dialogs/duplicated_file_dialog.dart';
import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/features/mods/providers/collection_editor_cubit.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list_header.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:path/path.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:tinycolor2/tinycolor2.dart';

class ModListEntry extends StatelessWidget {
  const ModListEntry({
    required this.index,
    required this.hovered,
    required this.onHover,
    required this.mod,
    required this.selected,
    required this.expanded,
    required this.onExpandCollection,
    this.onSelected,
    this.isLastSubItem,
    this.subIndex,
    super.key,
    this.onClick,
  });

  final FrostyMod mod;
  final int? subIndex;
  final bool? isLastSubItem;
  final ValueChanged<bool> onHover;
  final VoidCallback? onSelected;
  final VoidCallback? onClick;
  final VoidCallback? onExpandCollection;
  final bool selected;
  final int index;
  final bool expanded;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    return DragItemWidget(
      dragItemProvider: (request) async {
        if (mod.isCollection) {
          return null;
        }

        final item =
            DragItem(localData: '', suggestedName: basename(mod.filename))..add(
              Formats.fileUri(
                Uri.file(
                  join(ModService.getBasePath(), mod.filename),
                  windows: true,
                ),
              ),
            );
        return item;
      },
      allowedOperations: () => [DropOperation.copy],
      child: DraggableWidget(
        child: AnimatedContainer(
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(
                color: hovered ? kActiveColor : decoColor,
                width: 2,
              ),
            ),
          ),
          duration: const Duration(milliseconds: 150),
          height: 50,
          child: ColoredBox(
            color: index.isEven
                ? Colors.transparent
                : Colors.white.withOpacity(.025),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onHover(true),
              onExit: (_) => onHover(false),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: hovered
                      ? kActiveColor.lighten(0)
                      : FluentTheme.of(context).typography.bodyLarge?.color,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: hovered
                        ? kActiveColor.lighten(5)
                        : FluentTheme.of(context).typography.bodyLarge?.color,
                  ),
                  child: Row(
                    children: [
                      if (subIndex != null && subIndex != -1) ...[
                        Container(
                          width: 50,
                          height: 50,
                          alignment: Alignment.center,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (subIndex != null && subIndex != -1)
                                Positioned(
                                  top: -2,
                                  bottom: isLastSubItem! ? 15 : 0,
                                  left: 25,
                                  child: SizedBox(
                                    width: 2,
                                    height: isLastSubItem! ? 35 : 50,
                                    child: CustomPaint(
                                      size: const Size(15, 2),
                                      painter: DashedLineVerticalPainter(),
                                      child: const SizedBox(height: 2),
                                    ),
                                  ),
                                ),
                              if (subIndex != null) ...[
                                Positioned(
                                  top: 25,
                                  left: 25,
                                  child: SizedBox(
                                    width: 25,
                                    height: 2,
                                    child: CustomPaint(
                                      size: const Size(20, 2),
                                      painter: DashedLinePainter(),
                                      child: const SizedBox(height: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 2,
                          color: decoColor,
                        ),
                      ],
                      if (subIndex == null || subIndex == -1)
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: GestureDetector(
                            onTap: onSelected,
                            child: Selector(
                              selected: selected,
                              hovered: hovered,
                              child: ModIcon(mod: mod),
                            ),
                          ),
                        ),
                      if (subIndex != null && subIndex != -1)
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: ModIcon(mod: mod),
                        ),
                      Container(
                        width: 2,
                        color: decoColor,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AutoSizeText(
                                mod.details.name,
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 17,
                                ),
                                maxLines: 1,
                              ),
                              Text(
                                mod.details.version,
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  color: kWhiteColor,
                                  height: 1,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 150,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: AutoSizeText(
                            mod.details.category,
                            style: const TextStyle(
                              fontFamily: FontFamily.battlefrontUI,
                              color: kWhiteColor,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 78,
                        child: Text(
                          formatBytes(mod.size, 1),
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            color: kWhiteColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 5,
                          children: [
                            Text(
                              mod.isCollection ? 'PACK' : 'MOD',
                              style: const TextStyle(
                                fontFamily: FontFamily.battlefrontUI,
                                color: kWhiteColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (mod.isCollection) ...[
                              Container(
                                height: 15,
                                width: 2,
                                color: decoColor,
                              ),
                              Text(
                                mod.mods!.length.toString(),
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  color: kWhiteColor1,
                                ),
                              ),
                              ButtonBuilder(
                                onClick: onExpandCollection,
                                builder: (context, hovered) {
                                  return AbsorbPointer(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 8,
                                      ),
                                      child: SvgPicture.asset(
                                        expanded
                                            ? Assets
                                                  .icons
                                                  .kblDropdownFlipped
                                                  .path
                                            : Assets.icons.kblDropdown.path,
                                        height: 12,
                                        width: 12,
                                        color: hovered
                                            ? kActiveColor
                                            : kWhiteColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      BlocBuilder<CollectionEditorCubit, CollectionEditorState>(
                        builder: (context, state) => Container(
                          width: 60,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: decoColor,
                                width: 2,
                              ),
                            ),
                          ),
                          child: CustomSvgButton(
                            path: Assets.icons.kblCollection.path,
                            onPressed:
                                (state.editing &&
                                    context
                                        .read<CollectionEditorCubit>()
                                        .containsMod(mod))
                                ? null
                                : () async {
                                    if (!state.editing &&
                                        state.selectedCollection == null) {
                                      return;
                                    }

                                    if (state.selectedCollection != null &&
                                        !state.editing) {
                                      context
                                          .read<CollectionEditorCubit>()
                                          .editCollection();
                                    }

                                    final collectionMods = context
                                        .read<CollectionEditorCubit>()
                                        .state
                                        .selectedCollection!
                                        .getLocalMods(expandCollections: true);
                                    if (collectionMods.any(
                                      (element) {
                                        final eleNum =
                                            num.tryParse(
                                              element?.details.version ?? '0',
                                            ) ??
                                            0;
                                        final modNum =
                                            num.tryParse(mod.details.version) ??
                                            0;
                                        final eleNumValue = eleNum % 1 > 0
                                            ? eleNum.toDouble()
                                            : eleNum.toInt();
                                        final modNumValue = modNum % 1 > 0
                                            ? modNum.toDouble()
                                            : modNum.toInt();
                                        return element?.details.name.replaceAll(
                                              eleNumValue.toString(),
                                              '',
                                            ) ==
                                            mod.details.name.replaceAll(
                                              modNumValue.toString(),
                                              '',
                                            );
                                      },
                                    )) {
                                      final result =
                                          await showKyberDialog<bool?>(
                                            context: context,
                                            builder: (context) =>
                                                const DuplicatedFileDialog(),
                                          );
                                      if (result == null || !result) {
                                        return;
                                      }
                                    }

                                    context
                                        .read<CollectionEditorCubit>()
                                        .addMod(mod);
                                  },
                            size: 20,
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
      ),
    );
  }
}

class Selector extends StatelessWidget {
  const Selector({
    required this.selected,
    required this.child,
    required this.hovered,
    super.key,
  });

  final bool selected;
  final bool hovered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: child,
        ),
        if (hovered && !selected)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(.4),
            ),
          ),
        if (selected)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(.60),
            ),
          ),
        if (selected)
          Positioned(
            top: 3,
            right: 3,
            child: Assets.icons.selectorSelected.svg(),
          ),
        Positioned(
          top: 3,
          right: 3,
          child: AnimatedOpacity(
            opacity: hovered ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Assets.icons.selectorUnselected.svg(),
          ),
        ),
      ],
    );
  }
}
