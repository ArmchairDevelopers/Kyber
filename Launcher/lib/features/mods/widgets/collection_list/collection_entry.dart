import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_icon.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';

class CollectionEntry extends StatefulWidget {
  const CollectionEntry({
    required this.modCollection,
    super.key,
    this.onTap,
    this.selected = false,
  });

  final ModCollectionMetaData modCollection;
  final VoidCallback? onTap;
  final bool selected;

  @override
  State<CollectionEntry> createState() => _CollectionEntryState();
}

class _CollectionEntryState extends State<CollectionEntry> {
  bool hovered = false;
  late FrostyMod? largestMod;

  @override
  void initState() {
    final sortedMods = widget.modCollection.getLocalMods()
      ..sort((a, b) => b?.size.compareTo(a?.size ?? 0) ?? -1);
    largestMod = sortedMods.firstOrNull;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            border: Border.all(
              color: hovered
                  ? kActiveColor
                  : widget.selected
                  ? kInactiveColor
                  : decoColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
            color: Colors.black,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius - 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: -1,
                  left: -1,
                  right: widget.modCollection.localId == 'no-mods' ? -4 : -1,
                  bottom: -1,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.3, 1],
                        colors: [
                          Colors.transparent.withOpacity(0.1),
                          Colors.black,
                        ],
                      ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height),
                      );
                    },
                    blendMode: BlendMode.dstIn,
                    child: CollectionIcon(collection: widget.modCollection),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.modCollection.title,
                        style: TextStyle(
                          fontFamily: currentFont,
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.clip,
                      ),
                    ],
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

class CreateCollectionEntry extends StatelessWidget {
  const CreateCollectionEntry({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return ButtonBuilder(
      onClick: onTap,
      builder: (context, hovered) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          border: Border.all(
            color: hovered ? kActiveColor : decoColor,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
          color: Colors.black.withOpacity(.7),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius - 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Assets.icons.kblCollection.svg(
                height: 70,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.createNewCollection,
                      style: TextStyle(
                        fontFamily: currentFont,
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                    ),
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