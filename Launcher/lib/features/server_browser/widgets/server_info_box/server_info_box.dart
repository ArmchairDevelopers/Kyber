import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/reports/dialogs/report_player_dialog.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/background_image.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/download_progress.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/header.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/required_mods.dart';
import 'package:kyber_launcher/features/tutorial/models/tutorials/server_browser_tutorial.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class ServerInfoBox extends StatefulWidget {
  const ServerInfoBox({
    required this.server,
    this.moderationMode = false,
    this.onServerSelected,
    this.onClose,
    super.key,
  });

  final ServerEntry server;
  final bool moderationMode;
  final VoidCallback? onServerSelected;
  final VoidCallback? onClose;

  @override
  State<ServerInfoBox> createState() => _ServerInfoBoxState();
}

class _ServerInfoBoxState extends State<ServerInfoBox> {
  late Server serverInfo;
  int selectedIndex = 0;

  KyberMap? get map => MapHelper.getMap(
    serverInfo.levelSetup.mode,
    serverInfo.levelSetup.map,
  );

  @override
  void initState() {
    serverInfo = widget.server.serverInfo;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ServerInfoBox oldWidget) {
    if (oldWidget.server != widget.server) {
      selectedIndex = 0;
    }

    serverInfo = widget.server.serverInfo;

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final selectedServer =
        context.read<ServerBrowserCubit>().state.selectedServer ??
        widget.server;
    return FutureBuilder(
      future: sl.isReady<ModService>(),
      builder: (context, snapshot) {
        return SizedBox(
          key: ServerBrowserTutorial.serverInfoBoxKey,
          child: Column(
            children: [
              SizedBox(
                height:
                    context.read<MaximaCubit>().state.isEntitled(
                      UserEntitlement.admin,
                    )
                    ? 235
                    : 210,
                child: CustomBorder(
                  expand: true,
                  background: ServerBackgroundImage(
                    map: map?.map ?? '',
                    fade: false,
                    imageId: serverInfo.mapImageHash.isNotEmpty
                        ? serverInfo.mapImageHash
                        : null,
                  ),
                  clipper: _KyberContainerClipper(),
                  painter: _KyberContainerCustomPainter(),
                  blur: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 30,
                          top: 36,
                          right: 30,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    serverInfo.name,
                                    style: const TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 26,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                if (!serverInfo.official)
                                  CustomIconButton(
                                    iconData: mt.Icons.report,
                                    onPressed: () => showKyberDialog(
                                      context: context,
                                      builder: (_) => ReportPlayerDialog(
                                        targetPlayer: ServerPlayer(
                                          id: serverInfo.creatorId,
                                          name: serverInfo.creator,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 10),
                                CustomIconButton(
                                  iconData: mt.Icons.copy,
                                  size: 18,
                                  onPressed: () {
                                    final uri = Uri(
                                      scheme: 'https',
                                      host: 'api.prod.kyber.gg',
                                      path: 'redirect',
                                      queryParameters: {
                                        'target':
                                            'join_server?server_id=${serverInfo?.id}',
                                      },
                                    );
                                    Clipboard.setData(
                                      .new(text: uri.toString()),
                                    );
                                    NotificationService.info(
                                      message: 'Copied to clipboard!',
                                    );
                                  },
                                ),
                                const SizedBox(width: 10),
                                CustomIconButton(
                                  iconData: mt.Icons.close,
                                  onPressed:
                                      widget.onClose ??
                                      () => context
                                          .read<ServerBrowserCubit>()
                                          .clearServer(),
                                ),
                              ],
                            ),
                            if (context.read<MaximaCubit>().state.isEntitled(
                              UserEntitlement.admin,
                            )) ...[
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: serverInfo.id),
                                    );
                                    NotificationService.showNotification(
                                      message: 'Server ID copied to clipboard',
                                    );
                                  },
                                  child: Row(
                                    spacing: 5,
                                    children: [
                                      SizedBox(
                                        width: 70,
                                        child: Text(
                                          serverInfo.id,
                                          style: TextStyle(
                                            color: kWhiteColor.withOpacity(.5),
                                            fontFamily:
                                                FontFamily.battlefrontUI,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        mt.Icons.copy_rounded,
                                        size: 15,
                                        color: kWhiteColor.withOpacity(.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(
                              height: 15,
                            ),
                            Row(
                              children: [
                                Text(
                                  serverInfo.levelSetup.modeName.isNotEmpty
                                      ? serverInfo.levelSetup.modeName
                                      : MapHelper.getMode(
                                              serverInfo.levelSetup.mode,
                                            )?.name ??
                                            serverInfo.levelSetup.mode,
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  ' - ${serverInfo.levelSetup.mapName.isNotEmpty ? serverInfo.levelSetup.mapName : map?.name ?? serverInfo.levelSetup.map}',
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 16,
                                    color: kInactiveColor,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                /*const Text(
                                  'US',
                                  style: TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 15,
                                  ),
                                ),*/
                                if (!serverInfo.official)
                                  Text(
                                    serverInfo.creator,
                                    style: const TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 15,
                                      color: kInactiveColor,
                                    ),
                                  ),
                                if (serverInfo.official)
                                  const Text(
                                    'Official',
                                    style: TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 15,
                                      color: kInactiveColor,
                                    ),
                                  ),
                                Text(
                                  ' - ${serverInfo.playerCount}/${serverInfo.maxPlayerCount}',
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 15,
                                    color: kInactiveColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 15,
                            ),
                            if (!snapshot.hasData)
                              const SizedBox.shrink()
                            else
                              ServerButtonRow(
                                hasModsInstalled: serverInfo.mods
                                    .map(
                                      (e) => ModHelper.isInstalled(
                                        e.name,
                                        e.version,
                                      ),
                                    )
                                    .every((e) => e),
                                server: serverInfo,
                                onServerSelected: widget.onServerSelected,
                                onClose: widget.onClose,
                                selectedIndex: selectedIndex,
                                onPageChanged: (index) =>
                                    setState(() => selectedIndex = index),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedIndex == 0 && snapshot.hasData) ...[
                Container(
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      vertical: kDefaultBorder,
                    ),
                  ),
                  child: BackgroundBlur(
                    blurColorOpacity: .8,
                    child: Container(
                      height: 22,
                      padding: const EdgeInsets.all(4),
                      child:
                          BlocBuilder<ServerBrowserCubit, ServerBrowserState>(
                            buildWhen: (previous, current) =>
                                previous.selectedServer !=
                                    current.selectedServer ||
                                previous.joiningServer != current.joiningServer,
                            builder: (context, state) {
                              final hasRequiredMods = serverInfo.mods
                                  .map(
                                    (e) => ModHelper.isInstalled(
                                      e.name,
                                      e.version,
                                    ),
                                  )
                                  .every((element) => element);
                              return Stack(
                                children: [
                                  if (state.joiningServer != serverInfo) ...[
                                    Positioned.fill(
                                      child: ListenableBuilder(
                                        listenable: sl<ModService>(),
                                        builder: (_, _) => Container(
                                          color: hasRequiredMods
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ] else ...[
                                    const Positioned(
                                      child: ServerDownloadProgress(),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                    ),
                  ),
                ),
                Flexible(
                  child: ServerRequiredMods(
                    server: serverInfo,
                  ),
                ),
              ] else if (selectedIndex == 0 && !snapshot.hasData) ...[
                Expanded(
                  child: BackgroundBlur(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(kDefaultOuterBorderRadius),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(kDefaultOuterBorderRadius),
                        ),
                        border: Border(
                          left: kDefaultBorder,
                          right: kDefaultBorder,
                          bottom: kDefaultBorder,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 15,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: ProgressRing(),
                          ),
                          Text(
                            'LOADING LOCAL MODS...',
                            style: TextStyle(
                              fontFamily: FontFamily.battlefrontUI,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (serverInfo.description.isNotEmpty &&
                  selectedIndex ==
                      (selectedServer is GroupedServer ? 2 : 1)) ...[
                Expanded(
                  child: BackgroundBlur(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(kDefaultOuterBorderRadius),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(kDefaultOuterBorderRadius),
                        ),
                        border: Border(
                          left: kDefaultBorder,
                          right: kDefaultBorder,
                          bottom: kDefaultBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ColoredBox(
                            color: Colors.black.withValues(alpha: .5),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                'DESCRIPTION',
                                style: TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 16,
                                  color: kWhiteColor,
                                ),
                              ),
                            ),
                          ),
                          const CardSection(),
                          Expanded(
                            child: SelectionArea(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    serverInfo.description,
                                    style: const TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else if (selectedIndex == 1 &&
                  selectedServer is GroupedServer) ...[
                Builder(
                  builder: (context) {
                    final serverGroup = selectedServer.group;
                    return ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(kDefaultOuterBorderRadius),
                      ),
                      child: BackgroundBlur(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(
                                        kDefaultOuterBorderRadius,
                                      ),
                                    ),
                                    border: Border(
                                      bottom: kDefaultBorder,
                                      left: kDefaultBorder,
                                      right: kDefaultBorder,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ColoredBox(
                              color: Colors.black.withValues(alpha: .5),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(
                                    kDefaultOuterBorderRadius + 4,
                                  ),
                                ),
                                child: RepaintBoundary(
                                  key: Key('server_list'),
                                  child: KyberList(
                                    colorOpacity: 0,
                                    shrinkWrap: true,
                                    blur: false,
                                    activeIndex:
                                        serverGroup.getInstanceId(
                                          serverGroup.getPreferredServer().id,
                                        ) -
                                        1,
                                    roundedEnd: false,
                                    //itemPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 13),
                                    itemPadding: EdgeInsets.zero,
                                    physics: const ScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      final item = serverGroup
                                          .getSorted()[index];
                                      final serverInfo = item;
                                      return Row(
                                        children: [
                                          SizedBox(
                                            width: 75,
                                            height: 50,
                                            child: Builder(
                                              builder: (context) {
                                                if (serverInfo
                                                    .mapImageHash
                                                    .isNotEmpty) {
                                                  return CachedNetworkImage(
                                                    imageUrl:
                                                        'https://${sl.get<KyberGRPCService>().httpHostname}/images/${serverInfo.mapImageHash}.jpeg',
                                                    fit: BoxFit.cover,
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    colorBlendMode:
                                                        BlendMode.darken,
                                                    color: Colors.black
                                                        .withOpacity(
                                                          .12,
                                                        ),
                                                  );
                                                }

                                                return MapHelper.getImageForMap(
                                                  serverInfo.levelSetup.map,
                                                )!.image(
                                                  fit: BoxFit.cover,
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  colorBlendMode:
                                                      BlendMode.darken,
                                                  color: Colors.black
                                                      .withOpacity(
                                                        .12,
                                                      ),
                                                );
                                              },
                                            ),
                                          ),
                                          Container(
                                            width: 2,
                                            height: 50,
                                            color: decoColor,
                                          ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ).copyWith(top: 5),
                                                  child: Text(
                                                    'INSTANCE #${index + 1}',
                                                    style: const TextStyle(
                                                      fontFamily: FontFamily
                                                          .battlefrontUI,
                                                      fontSize: 16,
                                                      height: 1,
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      RichText(
                                                        text: TextSpan(
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            color: kWhiteColor1,
                                                            fontFamily: FontFamily
                                                                .battlefrontUI,
                                                          ),
                                                          children: [
                                                            TextSpan(
                                                              text:
                                                                  serverInfo
                                                                      .levelSetup
                                                                      .modeName
                                                                      .isNotEmpty
                                                                  ? serverInfo
                                                                        .levelSetup
                                                                        .modeName
                                                                  : MapHelper.getMode(
                                                                          serverInfo
                                                                              .levelSetup
                                                                              .mode,
                                                                        )?.name ??
                                                                        'UNKNOWN MODE',
                                                            ),
                                                            const TextSpan(
                                                              text: ' | ',
                                                              style: TextStyle(
                                                                color:
                                                                    decoColor,
                                                              ),
                                                            ),
                                                            TextSpan(
                                                              text:
                                                                  serverInfo
                                                                      .levelSetup
                                                                      .mapName
                                                                      .isNotEmpty
                                                                  ? serverInfo
                                                                        .levelSetup
                                                                        .mapName
                                                                  : MapHelper.getMap(
                                                                          serverInfo
                                                                              .levelSetup
                                                                              .mode,
                                                                          serverInfo
                                                                              .levelSetup
                                                                              .map,
                                                                        )?.name ??
                                                                        'UNKNOWN MAP',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            child: Text(
                                              '${item.playerCount}/${item.maxPlayerCount}',
                                              style: const TextStyle(
                                                fontFamily:
                                                    FontFamily.battlefrontUI,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                    itemCount: serverGroup.servers.length,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    borderRadius: BorderRadius.vertical(
                                      bottom: Radius.circular(
                                        kDefaultOuterBorderRadius,
                                      ),
                                    ),
                                    border: Border(bottom: kDefaultBorder),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class CustomPainterDownload extends CustomPainter {
  CustomPainterDownload();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          kButtonBorder // Set your desired color here
      ..strokeWidth =
          7 // Set the height of the line (7 pixels)
      ..style = PaintingStyle.stroke;

    double startX = 0;
    const dashWidth = 2.5; // Width of each dash (2 pixels)
    const double dashGap = 13; // Gap between each dash (13 pixels)

    while (startX < size.width) {
      // Draw the horizontal dashed line segment (2 px width)
      canvas.drawLine(
        Offset(startX, 0), // Starting point
        Offset(
          startX + dashWidth,
          0,
        ), // Ending point (2 px to the right of the start)
        paint,
      );
      startX += dashWidth + dashGap; // Move the startX by dashWidth + dashGap
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

Path _generateContainerPath(Size size) {
  final path_0 = Path();
  path_0.moveTo(5, 0);
  path_0.lineTo((size.width * 0.50) - 5, 0);
  path_0.quadraticBezierTo(size.width * 0.50, 0, (size.width * 0.50) + 5, 5);
  path_0.quadraticBezierTo(
    (size.width * 0.50) + 10,
    10,
    (size.width * 0.50) + 20,
    10,
  );

  path_0.lineTo(size.width * 0.87 - 5, 10);

  path_0.quadraticBezierTo(
    size.width * 0.87,
    10,
    (size.width * 0.87) + 5,
    5,
  );
  path_0.quadraticBezierTo(
    (size.width * 0.87) + 10,
    0,
    (size.width * 0.87) + 20,
    0,
  );

  path_0.lineTo(size.width - kDefaultOuterBorderRadius, 0);

  path_0.quadraticBezierTo(
    size.width,
    0,
    size.width,
    kDefaultOuterBorderRadius,
  );
  path_0.lineTo(size.width, size.height);
  path_0.lineTo(0, size.height);
  path_0.lineTo(0, kDefaultOuterBorderRadius);
  path_0.quadraticBezierTo(0, 0, kDefaultOuterBorderRadius, 0);
  path_0.close();

  return path_0;
}

class _KyberContainerCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintStroke0 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = decoColor;

    canvas.drawPath(_generateContainerPath(size), paintStroke0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class _KyberContainerClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _generateContainerPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return true;
  }
}

class _DownloadItem extends StatefulWidget {
  const _DownloadItem();

  @override
  State<_DownloadItem> createState() => _DownloadItemState();
}

class _DownloadItemState extends State<_DownloadItem> {
  Server get server {
    return context.read<ServerBrowserCubit>().state.selectedServer!.serverInfo;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerBrowserCubit, ServerBrowserState>(
      buildWhen: (previous, current) =>
          previous.selectedServer != current.selectedServer ||
          previous.joiningServer != current.joiningServer,
      builder: (context, state) {
        final hasRequiredMods = context
            .read<ServerBrowserCubit>()
            .hasAllRequiredMods();
        if (state.selectedServer?.serverInfo != server ||
            server.mods.isEmpty ||
            hasRequiredMods ||
            !hasRequiredMods && state.joiningServer != server) {
          return const SizedBox.shrink();
        }

        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: decoColor.withOpacity(0.5),
              ),
            ),
          ),
          height: 30,
          child: const BackgroundBlur(
            child: RepaintBoundary(
              child: ServerDownloadProgress(),
            ),
          ),
        );
      },
    );
  }
}
