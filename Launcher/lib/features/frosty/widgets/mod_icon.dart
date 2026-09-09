import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tooltip.dart';

class ModIcon extends StatefulWidget {
  const ModIcon({this.mod, super.key});

  final FrostyMod? mod;

  @override
  State<ModIcon> createState() => _ModIconState();
}

class _ModIconState extends State<ModIcon> {
  bool _isCorrupted = false;

  @override
  void initState() {
    super.initState();
    _isCorrupted = _checkCorrupted();
  }

  @override
  void didUpdateWidget(ModIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.mod, widget.mod)) {
      _isCorrupted = _checkCorrupted();
    }
  }

  bool _checkCorrupted() {
    final mod = widget.mod;
    return mod != null && mod.isCollection && mod.isCorrupted();
  }

  @override
  Widget build(BuildContext context) {
    final mod = widget.mod;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Assets.images.kyberNoImage.image(
          height: 50,
          width: 50,
          fit: BoxFit.cover,
          colorBlendMode: BlendMode.modulate,
          color: Colors.white.withOpacity(.5),
        ),
        if (mod?.icon != null)
          Positioned.fill(
            child: Image.memory(
              mod!.icon!,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        if (_isCorrupted)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withOpacity(.5),
              child: KyberTooltip(
                message:
                    'This collection is missing one or more of its mods.${Platform.lineTerminator}Reinstall it to fix.',
                child: Icon(
                  FluentIcons.warning,
                  color: Colors.red,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
