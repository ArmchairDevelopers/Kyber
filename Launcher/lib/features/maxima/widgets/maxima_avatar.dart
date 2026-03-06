import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';

class MaximaAvatar extends StatefulWidget {
  const MaximaAvatar({required this.pd, this.height = 64, this.width = 64, super.key});

  final String pd;
  final double width;
  final double height;

  @override
  State<MaximaAvatar> createState() => _MaximaAvatarState();
}

class _MaximaAvatarState extends State<MaximaAvatar> {
  bool loaded = false;
  String? path;

  @override
  void initState() {
    _load(widget.pd);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant MaximaAvatar oldWidget) {
    if (oldWidget.pd != widget.pd) {
      _load(widget.pd);
    }

    super.didUpdateWidget(oldWidget);
  }

  void _load(String pd) async {
    if (!mounted) return;

    if (loaded) {
      setState(() {
        loaded = false;
        path = null;
      });
    }

    final result = await avatarImage(
      pd: pd,
      width: 208,
      height: 208,
    );
    setState(() {
      loaded = true;
      path = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return Container(
        width: 24,
        height: 24,
        alignment: .center,
        child: const ProgressRing(),
      );
    }

    if (path == null) {
      return Assets.images.usericonTmp.image(
        width: widget.width,
        height: widget.height,
      );
    }

    return Image.file(
      File(path ?? ''),
      width: widget.width,
      height: widget.height,
    );
  }
}
