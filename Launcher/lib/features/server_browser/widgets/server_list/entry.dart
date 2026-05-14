import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/kyber/models/maps.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/models/modes.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/server_browser/helpers/server_browser_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:tinycolor2/tinycolor2.dart';

final Map<String, String> regionIcons = {
  'na': Assets.icons.regions.kblPlayRegionNa.path,
  'eu': Assets.icons.regions.kblPlayRegionEu.path,
  'as': Assets.icons.regions.kblPlayRegionAs.path,
  'af': Assets.icons.regions.kblPlayRegionAf.path,
  'sa': Assets.icons.regions.kblPlayRegionSa.path,
  'oc': Assets.icons.regions.kblPlayRegionOc.path,
};

class ServerListEntry extends StatelessWidget {
  const ServerListEntry({
    required this.index,
    required this.hoveredIndex,
    required this.onHover,
    required this.mode,
    required this.map,
    required this.server,
    this.isLast = false,
    super.key,
    this.onClick,
    this.withoutQuickJoin = false,
  });

  factory ServerListEntry.fromServer({
    required int hoveredIndex,
    required ValueChanged<bool> onHover,
    required Server server,
    Key? key,
  }) {
    final mode =
        modes
            .where((element) => element.mode == server.levelSetup.mode)
            .firstOrNull ??
        Mode.customMode();
    final dynamic map = mode.maps.isEmpty
        ? maps.first
        : maps.singleWhere(
            (element) => element['map'] == server.levelSetup.map,
          );

    return ServerListEntry(
      key: key,
      index: -1,
      hoveredIndex: hoveredIndex,
      onHover: onHover,
      map: Map<dynamic, String>.from(map as Map<dynamic, dynamic>),
      mode: mode,
      server: SingleServer(server: server),
    );
  }

  final ServerEntry server;
  final ValueChanged<bool> onHover;
  final void Function()? onClick;
  final int index;
  final int hoveredIndex;
  final Map map;
  final Mode mode;
  final bool isLast;
  final bool withoutQuickJoin;

  @override
  Widget build(BuildContext context) {
    final hovered = hoveredIndex == index + 1;
    final serverInfo = server.serverInfo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: Border(
          top: index == 0
              ? BorderSide(color: hovered ? kActiveColor : decoColor, width: 2)
              : BorderSide.none,
          left: BorderSide(
            color: hovered ? kActiveColor : decoColor,
            width: 2,
          ),
          right: BorderSide(
            color: hovered ? kActiveColor : decoColor,
            width: 2,
          ),
          bottom: BorderSide(
            color: hovered || hoveredIndex == index + 2
                ? kActiveColor
                : decoColor,
            width: 2,
          ),
        ),
      ),
      child: SizedBox(
        height: 65,
        child: GestureDetector(
          onTap:
              onClick ??
              () {
                context.read<ServerBrowserCubit>().selectServer(server);
              },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover.call(false),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                fontFamily: FontFamily.battlefrontUI,
                color: hovered
                    ? kActiveColor.lighten(0)
                    : FluentTheme.of(context).typography.bodyLarge?.color,
                shadows: hovered
                    ? [
                        BoxShadow(
                          color: kActiveColor.withOpacity(.5),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: hovered
                      ? kActiveColor.lighten(5)
                      : FluentTheme.of(context).typography.bodyLarge?.color,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 150,
                      height: 65,
                      child: Builder(
                        builder: (context) {
                          if (serverInfo.mapImageHash.isNotEmpty) {
                            return CachedNetworkImage(
                              imageUrl:
                                  'https://${sl.get<KyberGRPCService>().httpHostname}/images/${serverInfo.mapImageHash}.jpeg',
                              fit: BoxFit.cover,
                              alignment: Alignment.centerLeft,
                              colorBlendMode: BlendMode.darken,
                              color: Colors.black.withOpacity(.12),
                              fadeInDuration: .zero,
                            );
                          }

                          return MapHelper.getImageForMap(
                            map['map'] as String,
                          )!.image(
                            fit: BoxFit.cover,
                            alignment: Alignment.centerLeft,
                            colorBlendMode: BlendMode.darken,
                            color: Colors.black.withOpacity(.12),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TableServerName(server: serverInfo),
                                _ServerInfoBar(
                                  server: serverInfo,
                                  map: map,
                                  mode: mode,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Builder(
                            builder: (context) {
                              if (server is GroupedServer) {
                                return Text(
                                  server.totalPlayerCount.toString(),
                                  textAlign: TextAlign.center,
                                );
                              }

                              return Text(
                                '${serverInfo.playerCount}/${serverInfo.maxPlayerCount}',
                                style: const .new(
                                  fontSize: 15,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      alignment: Alignment.center,
                      width: 120,
                      child: Text(
                        (serverInfo.official ? 'Official' : 'Custom')
                            .toUpperCase(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!withoutQuickJoin) ...[
                      _JoinButton(
                        key: ValueKey(serverInfo.id),
                        server: serverInfo,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatefulWidget {
  const _JoinButton({required this.server, super.key});

  final Server server;

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 70,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(
            color: decoColor,
          ),
        ),
      ),
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap:
                ServerBrowserHelper.canJoinServer(
                  context,
                  server: widget.server,
                )
                ? () {
                    context.read<ServerBrowserCubit>()
                      ..selectServer(SingleServer(server: widget.server))
                      ..joinServer(enabledDownload: false);
                  }
                : null,
            child: Builder(
              builder: (context) {
                return CustomIconButton(
                  onPressed:
                      ServerBrowserHelper.canJoinServer(
                        context,
                        server: widget.server,
                      )
                      ? () {
                          context.read<ServerBrowserCubit>()
                            ..selectServer(SingleServer(server: widget.server))
                            ..joinServer(enabledDownload: false);
                        }
                      : null,
                  iconData: FluentIcons.play_solid,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TableServerName extends StatelessWidget {
  const _TableServerName({required this.server, super.key});

  final Server server;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (server.official)
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 2, bottom: 2),
            child: Builder(
              builder: (context) {
                final mods = server.mods;
                if (mods.length == 1) {
                  if (mods.first.name == 'Battlefront Plus') {
                    return Assets.icons.kblBattlefrontPlusIcon.svg(
                      height: 15,
                    );
                  } else if (mods.first.name ==
                      'Vanilla Plus - Curated Mod Pack for KYBER V2') {
                    return Assets.icons.kblVanillaPlusIcon.svg(
                      height: 15,
                    );
                  }
                }
                return Assets.icons.kyberLogo.svg(
                  height: 15,
                );
              },
            ),
          ),
        if (context.read<MaximaRtmCubit>().state.friends.any(
          (e) => e.displayName == server.creator,
        ))
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 2, bottom: 4),
            child: Assets.icons.kblLink.svg(
              color: kWhiteColor,
              height: 15,
            ),
          ),
        Flexible(
          child: AutoSizeText(
            server.name.trimRight(),
            maxFontSize: 18,
            minFontSize: 17,
            maxLines: 1,
            style: const TextStyle(
              letterSpacing: .6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (server.requiresPassword) const Icon(FluentIcons.lock, size: 14),
      ],
    );
  }
}

class _ServerInfoBar extends StatelessWidget {
  const _ServerInfoBar({
    required this.server,
    required this.map,
    required this.mode,
    super.key,
  });

  final Server server;
  final Map map;
  final Mode mode;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: FontFamily.battlefrontUI,
        color: kWhiteColor,
        fontSize: 14,
        letterSpacing: 0.5,
      ),
      child: Row(
        children: [
          if (server.hasRegion() &&
              regionIcons.containsKey(server.region.toLowerCase())) ...[
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: SvgPicture.asset(
                regionIcons[server.region.toLowerCase()]!,
                width: 20,
                height: 15,
              ),
            ),
            const _Divider(),
          ],
          Text(
            server.levelSetup.modeName.isNotEmpty
                ? server.levelSetup.modeName.toUpperCase()
                : mode.name.toUpperCase(),
          ),
          const _Divider(),
          Text(
            server.levelSetup.mapName.isNotEmpty
                ? server.levelSetup.mapName.toUpperCase()
                : (map['name'] as String).toUpperCase(),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 1,
      width: 5,
      color: kInactiveColor,
    );
  }
}
