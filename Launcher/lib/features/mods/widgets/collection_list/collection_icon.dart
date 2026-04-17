import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';

class CollectionIcon extends StatefulWidget {
  const CollectionIcon({required this.collection, super.key});

  final ModCollectionMetaData collection;

  @override
  State<CollectionIcon> createState() => _CollectionIconState();
}

class _CollectionIconState extends State<CollectionIcon> {
  late FrostyMod? largestMod;

  @override
  void initState() {
    final sortedMods = widget.collection.getLocalMods()
      ..sort((a, b) => b?.size.compareTo(a?.size ?? 0) ?? -1);
    largestMod = sortedMods.firstOrNull;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collection.icon != null) {
      return Image.memory(
        widget.collection.icon!,
        fit: BoxFit.cover,
      );
    }

    if (largestMod == null || largestMod!.icon == null) {
      return Assets.images.kyberNoImage.image(fit: BoxFit.cover);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Assets.images.kyberNoImage.image(fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: Image.memory(
            largestMod!.icon!,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }
}
