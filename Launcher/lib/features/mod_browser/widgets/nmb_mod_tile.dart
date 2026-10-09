import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:nexus_gql/nexus_gql.dart';

class NMBModTile extends StatelessWidget {
  const NMBModTile({required this.mod, super.key});

  final Query$modsByCategory$mods$nodes mod;

  @override
  Widget build(BuildContext context) {
    return ButtonBuilder(
      onClick: () {
        router.push('/mods/mod_browser/${mod.modId}');
      },
      builder: (context, hovered) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
            border: Border.all(
              color: hovered ? kActiveColor : decoColor,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius - 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: -1,
                  left: -1,
                  right: -1,
                  bottom: -1,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                        ],
                      ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height),
                      );
                    },
                    blendMode: BlendMode.dstOut,
                    child: Assets.images.kyberNoImage.image(
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  top: -1,
                  left: -1,
                  right: -1,
                  bottom: -1,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                        ],
                      ).createShader(
                        Rect.fromLTRB(0, 0, rect.width, rect.height),
                      );
                    },
                    blendMode: BlendMode.dstOut,
                    child: CachedNetworkImage(
                      imageUrl:
                          mod.thumbnailUrl ??
                          mod.pictureUrl ??
                          'https://via.placeholder.com/375x211',
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                    ),
                  ),
                ),
                // Installed version badge
                Builder(
                  builder: (context) {
                    final installedVersion =
                        ModHelper.getInstalledVersion(mod.name);
                    if (installedVersion == null) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kActiveColor.withOpacity(.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'v$installedVersion',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: FontFamily.battlefrontUI,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: hovered ? 1 : 0,
                    child: Container(
                      color: Colors.black.withOpacity(.5),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    reverseDuration: const Duration(milliseconds: 150),
                    child: hovered
                        ? Container(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 14,
                                top: 14,
                                right: 14,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    mod.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 19,
                                      color: kActiveColor,
                                      height: 1,
                                    ),
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 15),
                                  Expanded(
                                    child: Text(
                                      mod.summary.trimLeft(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        letterSpacing: 0.05,
                                        wordSpacing: 0,
                                        fontWeight: FontWeight.w400,
                                        height: 1.1,
                                      ),
                                      overflow: TextOverflow.fade,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  mod.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 19,
                                    color: Colors.white,
                                    height: 1,
                                  ),
                                  maxLines: 2,
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Text(
                                      formatKiloBytes(mod.fileSize!, 1),
                                      style: const TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 14,
                                        color: kWhiteColor,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(
                                      FluentIcons.download,
                                      size: 16,
                                      color: kWhiteColor,
                                    ),
                                    Text(
                                      NumberFormat(
                                        '#,###',
                                      ).format(mod.downloads),
                                      style: const TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 14,
                                        color: kWhiteColor,
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
