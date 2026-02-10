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
  String? path;

  @override
  void initState() {
    avatarImage(
      pd: widget.pd,
      width: 208,
      height: 208,
    ).then((value) {
      setState(() {
        path = value;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
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
