import 'package:background_downloader/background_downloader.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/background_image.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_page_selector.dart';
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
  ServerRegion? selectedRegion;

  KyberMap? get map => MapHelper.getMap(
    serverInfo.levelSetup.mode,
    serverInfo.levelSetup.map,
  );

  ServerGroup? get _group => switch (widget.server) {
    GroupedServer(:final group) => group,
    _ => null,
  };

  List<Server> get _instances {
    final group = _group;
    if (group == null) {
      return [serverInfo];
    }

    var instances = group.getSorted();
    if (selectedRegion != null) {
      instances = instances
          .where((e) => e.serverRegion == selectedRegion)
          .toList();
    }

    return instances.isEmpty ? group.getSorted() : instances;
  }

  List<ServerRegion> get _regions {
    final group = _group;
    if (group == null) {
      return [];
    }

    return group.regions.toList()..sort((a, b) => a.index.compareTo(b.index));
  }

  @override
  void initState() {
    serverInfo = widget.server.serverInfo;
    setPreferredRegion(widget.server);
    super.initState();
  }

  void setPreferredRegion(ServerEntry serverEntry) {
    if (serverEntry is! GroupedServer) {
      return;
    }

    final server = widget.server as GroupedServer;
    selectedRegion = server.group.getPreferredRegion();
  }

  @override
  void didUpdateWidget(covariant ServerInfoBox oldWidget) {
    if (oldWidget.server != widget.server) {
      selectedRegion = null;
      serverInfo = widget.server.serverInfo;
      setPreferredRegion(widget.server);
    }

    super.didUpdateWidget(oldWidget);
  }

  void _switchInstance(int page) {
    setState(() {
      serverInfo = _instances[page - 1];
    });
  }

  void _switchRegion(ServerRegion? region) {
    setState(() {
      selectedRegion = region;

      if (region == null) {
        serverInfo = _group!.getPreferredServer();
      } else if (!_instances.contains(serverInfo)) {
        serverInfo = _instances.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final modeName = serverInfo.levelSetup.modeName.isNotEmpty
        ? serverInfo.levelSetup.modeName
        : MapHelper.getMode(serverInfo.levelSetup.mode)?.name ??
              serverInfo.levelSetup.mode;

    final mapName = serverInfo.levelSetup.mapName.isNotEmpty
        ? serverInfo.levelSetup.mapName
        : MapHelper.getMap(
                serverInfo.levelSetup.mode,
                serverInfo.levelSetup.map,
              )?.name ??
              serverInfo.levelSetup.map;

    final instances = _instances;
    final regions = _regions;
    final showInstances = _group != null && instances.length > 1;

    return Container(
      decoration: BoxDecoration(
        borderRadius: .circular(kDefaultOuterBorderRadius),
        border: kDefaultAllBorder,
      ),
      child: BackgroundBlur(
        borderRadius: .circular(kDefaultOuterBorderRadius - 2),
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: kControlBackgroundColor),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ServerBackgroundImage(map: map?.map ?? ''),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 25),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    Padding(
                      padding: const .only(left: 25, right: 70),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 24,
                          color: Colors.white,
                          shadows: [
                            .new(
                              color: Colors.black,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: .start,
                          children: [
                            Text(
                              serverInfo.levelSetup.mode,
                              style: const .new(
                                fontSize: 12,
                                color: kInactiveColor,
                                fontFamily: FontFamily.aurebesh,
                              ),
                            ),
                            Text(
                              serverInfo.name.toUpperCase(),
                              style: const .new(
                                fontWeight: .w700,
                              ),
                            ),
                            Text(
                              '$modeName - $mapName',
                              style: const .new(
                                fontSize: 18,
                                color: kInactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const .symmetric(horizontal: 25),
                      child: SizedBox(
                        height: 30,
                        child: Row(
                          spacing: 8,
                          crossAxisAlignment: .stretch,
                          children: [
                            if (serverInfo.official)
                              _Badge(
                                icon: Assets.icons.greyKyberLogo.svg(
                                  height: 14,
                                  width: 14,
                                ),
                              )
                            else if (serverInfo.creator.isNotEmpty)
                              Flexible(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (constraints.maxWidth < 60) {
                                      return const SizedBox.shrink();
                                    }

                                    return Align(
                                      alignment: .centerLeft,
                                      widthFactor: 1,
                                      child: IntrinsicWidth(
                                        child: SizedBox(
                                          height: double.infinity,
                                          child: _Badge(
                                            text: serverInfo.creator,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            SizedBox(
                              width: 55,
                              child: _Badge(
                                text:
                                    '${serverInfo.playerCount}/${serverInfo.maxPlayerCount}',
                              ),
                            ),
                            if (serverInfo.region.isNotEmpty &&
                                (selectedRegion == null ||
                                    selectedRegion == .all))
                              SizedBox(
                                width: 40,
                                child: _Badge(
                                  text: serverInfo.region.toUpperCase(),
                                ),
                              ),
                            if (regions.length > 1) ...[
                              const Spacer(),
                              if (showInstances)
                                _PageSelector(
                                  current: instances.indexOf(serverInfo) + 1,
                                  total: instances.length,
                                  onPageChanged: _switchInstance,
                                ),
                              _RegionSelector(
                                regions: regions,
                                selected: selectedRegion,
                                onChanged: _switchRegion,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (showInstances) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const .symmetric(horizontal: 25),
                        child: Row(
                          spacing: 8,
                          children: [
                            for (final instance in instances)
                              Expanded(
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: instance == serverInfo
                                        ? kActiveColor
                                        : kButtonBorder,
                                    borderRadius: .circular(1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 25),
                    Padding(
                      padding: const .symmetric(horizontal: 25),
                      child: Row(
                        children: [
                          if (widget.onServerSelected != null)
                            KyberButton.withChild(
                              onPressed: widget.onServerSelected,
                              padding: const .symmetric(
                                horizontal: 25,
                                vertical: 8,
                              ),
                              child: Text(
                                widget.moderationMode ? 'MODERATE' : 'PLAY',
                              ),
                            )
                          else
                            _JoinButton(serverInfo: serverInfo),
                          const Spacer(),
                          KOutlinedButton.icon(
                            child: Assets.icons.kblCollection.svg(),
                            onPressed: () => null,
                          ),
                          const SizedBox(width: 10),
                          KOutlinedButton.icon(
                            child: const Icon(mt.Icons.camera_alt),
                            onPressed: () => null,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const .only(left: 25, right: 25, top: 20),
                        children: [
                          if (serverInfo.description.isNotEmpty) ...[
                            Text(
                              serverInfo.description,
                              style: const TextStyle(
                                fontFamily: FontFamily.battlefrontUI,
                                fontSize: 14,
                                color: kWhiteColor1,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _ModsDropdown(serverInfo: serverInfo),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 25,
              right: 25,
              child: KOutlinedButton(
                onPressed:
                    widget.onClose ??
                    () => context.read<ServerBrowserCubit>().clearServer(),
                padding: const .symmetric(horizontal: 8, vertical: 2),
                child: const Icon(mt.Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.serverInfo, super.key});

  final Server serverInfo;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl.get<ModService>(),
      builder: (context, _) {
        return BlocBuilder<ServerBrowserCubit, ServerBrowserState>(
          buildWhen: (previous, current) =>
              previous.joiningServer != current.joiningServer,
          builder: (context, state) {
            final hasAllMods = serverInfo.mods.every(
              (mod) => ModHelper.isInstalled(mod.name, mod.version),
            );
            final downloading = state.joiningServer != null;

            return KyberButton.withChild(
              onPressed: downloading
                  ? null
                  : context.read<ServerBrowserCubit>().joinServer,
              padding: const .symmetric(
                horizontal: 25,
                vertical: 8,
              ),
              child: Text(hasAllMods ? 'PLAY' : 'DOWNLOAD MODS'),
            );
          },
        );
      },
    );
  }
}

class _ModsDropdown extends StatelessWidget {
  const _ModsDropdown({required this.serverInfo, super.key});

  final Server serverInfo;

  bool _isModDownloading(TaskRecord? download, ServerMod mod) {
    if (download == null || download.task.metaData.isEmpty) {
      return false;
    }

    try {
      final metadata = ServerMod.fromJson(download.task.metaData);
      return metadata.name == mod.name && metadata.version == mod.version;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl.get<ModService>(),
      builder: (context, _) {
        final installedMods = serverInfo.mods
            .where((e) => ModHelper.isInstalled(e.name, e.version))
            .length;

        return _Dropdown(
          title: Row(
            spacing: 10,
            children: [
              Text('MODS - $installedMods/${serverInfo.mods.length}'),
              const Expanded(
                child: SizedBox(
                  height: 2,
                  child: ColoredBox(color: decoColor),
                ),
              ),
            ],
          ),
          child: Padding(
            padding: const .only(top: 12, bottom: 25),
            child: BlocBuilder<DownloadCubit, DownloadState>(
              buildWhen: (previous, current) {
                final prev = previous is DownloadLoaded
                    ? previous.currentDownload
                    : null;
                final curr = current is DownloadLoaded
                    ? current.currentDownload
                    : null;
                return prev?.taskId != curr?.taskId;
              },
              builder: (context, state) {
                final currentDownload = state is DownloadLoaded
                    ? state.currentDownload
                    : null;

                return Column(
                  spacing: 6,
                  children: [
                    for (final mod in serverInfo.mods)
                      _ModTile(
                        mod: mod,
                        downloading: _isModDownloading(currentDownload, mod),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _ModTile extends StatelessWidget {
  const _ModTile({required this.mod, this.downloading = false, super.key});

  final ServerMod mod;
  final bool downloading;

  @override
  Widget build(BuildContext context) {
    final installed = ModHelper.isInstalled(mod.name, mod.version);

    final color = downloading
        ? kActiveColor
        : installed
        ? Colors.green
        : Colors.red;

    return KyberTooltip(
      message: '${mod.name} ${mod.version}',
      child: Container(
        clipBehavior: .antiAlias,
        decoration: BoxDecoration(
          color: kControlBackgroundColor,
          border: .all(color: kButtonBorder, width: 1.5),
          borderRadius: .circular(kDefaultInnerBorderRadius),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const .symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                spacing: 10,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          margin: const .only(right: 15),
                          padding: const .all(3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: .circular(4),
                            border: .all(color: color, width: 1.5),
                          ),
                          child: Icon(
                            downloading
                                ? mt.Icons.download
                                : installed
                                ? mt.Icons.check
                                : mt.Icons.close,
                            size: 16,
                            color: color,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            mod.name,
                            style: const TextStyle(
                              fontFamily: FontFamily.battlefrontUI,
                              fontSize: 16,
                              color: kWhiteColor,
                            ),
                            overflow: .ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          ' (${mod.version})',
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 14,
                            color: kWhiteColor1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (mod.fileSize > 0) ...[
                    Text(
                      formatBytes(mod.fileSize.toInt(), 1),
                      style: const TextStyle(
                        fontFamily: FontFamily.battlefrontUI,
                        fontSize: 12,
                        color: kWhiteColor1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (downloading)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ModDownloadProgress(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModDownloadProgress extends StatelessWidget {
  const _ModDownloadProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadCubit, DownloadState>(
      builder: (context, state) {
        final progress = state is DownloadLoaded
            ? (state.progressUpdate?.progress ?? 0).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kActiveColor,
                Colors.transparent,
              ],
              stops: [
                progress,
                progress,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({this.text, this.icon, super.key});

  final String? text;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    assert(text != null || icon != null, 'Badge must have either text or icon');

    return Container(
      padding: const .symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: kControlBackgroundColor,
        border: .all(color: kButtonBorder, width: 1.5),
        borderRadius: .circular(kDefaultInnerBorderRadius),
      ),
      alignment: .center,
      child:
          icon ??
          Text(
            text!,
            overflow: .ellipsis,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: .w700,
              fontFamily: FontFamily.battlefrontUI,
              height: 1.2,
              color: kWhiteColor,
              fontFeatures: [
                .tabularFigures(),
              ],
            ),
          ),
    );
  }
}

class _PageSelector extends StatelessWidget {
  const _PageSelector({
    required this.current,
    required this.total,
    required this.onPageChanged,
    super.key,
  });

  final int current;
  final int total;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: KyberPageSelector(
        tinted: true,
        current: current,
        total: total,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

class _RegionSelector extends StatelessWidget {
  const _RegionSelector({
    required this.regions,
    required this.onChanged,
    this.selected,
    super.key,
  });

  final List<ServerRegion> regions;
  final ServerRegion? selected;
  final ValueChanged<ServerRegion?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(String, ServerRegion?)>[
      ('ALL', null),
      for (final region in regions) (region.name.toUpperCase(), region),
    ];

    return Container(
      clipBehavior: .hardEdge,
      decoration: BoxDecoration(
        color: kControlBackgroundColor,
        border: .all(color: kButtonBorder, width: 1.5),
        borderRadius: .circular(kDefaultInnerBorderRadius),
      ),
      child: ClipRRect(
        borderRadius: .circular(kDefaultInnerBorderRadius - 1.5),
        child: Row(
          crossAxisAlignment: .stretch,
          children: [
            for (final (label, value) in items)
              ButtonBuilder(
                onClick: () => onChanged(value),
                builder: (context, hovered) {
                  final active = value == selected;

                  return AnimatedContainer(
                    duration: kDefaultDuration,
                    padding: const .symmetric(horizontal: 12, vertical: 4),
                    alignment: .center,
                    color: hovered
                        ? kActiveColor
                        : active
                        ? kWhiteColor
                        : Colors.transparent,
                    child: AnimatedDefaultTextStyle(
                      duration: kDefaultDuration,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: .w700,
                        fontFamily: FontFamily.battlefrontUI,
                        height: 1,
                        color: hovered || active ? Colors.black : kWhiteColor,
                      ),
                      child: Text(label),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Dropdown extends StatefulWidget {
  const _Dropdown({
    required this.title,
    required this.child,
    super.key,
  });

  final Widget title;
  final Widget child;

  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown> {
  bool expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        ButtonBuilder(
          onClick: () => setState(() => expanded = !expanded),
          builder: (_, _) => DefaultTextStyle(
            style: const TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 16,
              fontWeight: .w700,
              color: kWhiteColor,
            ),
            child: Row(
              spacing: 10,
              children: [
                Transform.rotate(
                  angle: expanded ? 0.5 * 3.14 : 0,
                  child: Assets.icons.kblPlay.svg(
                    height: 12,
                    width: 12,
                    colorFilter: const .mode(
                      kWhiteColor,
                      .srcIn,
                    ),
                  ),
                ),
                Expanded(child: widget.title),
              ],
            ),
          ),
        ),
        if (expanded) widget.child,
      ],
    );
  }
}
