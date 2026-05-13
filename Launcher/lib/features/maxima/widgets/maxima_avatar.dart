import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';

class MaximaAvatar extends StatefulWidget {
  const MaximaAvatar({
    required this.pd,
    this.height = 64,
    this.width = 64,
    this.borderRadius = 3,
    super.key,
  });

  final String pd;
  final double width;
  final double height;
  final double borderRadius;

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

    if (!mounted) return;

    setState(() {
      loaded = true;
      path = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    if (!loaded) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: .center,
          child: const ProgressRing(),
        ),
      );
    }

    if (path == null) {
      return ClipRRect(
        borderRadius: radius,
        child: Assets.images.usericonTmp.image(
          width: widget.width,
          height: widget.height,
        ),
      );
    }

    ImageProvider imageProvider = switch (path) {
      final String p when p.startsWith('http') => NetworkImage(p),
      final String p => FileImage(File(p)),
      _ => Assets.images.usericonTmp.provider(),
    };

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: .cover,
        ),
        borderRadius: radius,
      ),
    );
  }
}
