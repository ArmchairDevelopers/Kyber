import 'package:background_downloader/background_downloader.dart';
import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_icon.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/server_password_dialog.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/background_image.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/entry.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
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
  bool _regionResolved = false;
  bool _modsLoaded = false;

  List<ModCollectionMetaData> collections = [];
  ModCollectionMetaData? selectedCollection;

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
    sl.isReady<ModService>().then(
      (_) {
        if (!mounted) return;

        setState(() {
          _modsLoaded = true;
          _setCollectionData();
        });
      },
    );

    super.initState();
  }

  void setPreferredRegion(ServerEntry serverEntry) {
    if (serverEntry is! GroupedServer) {
      return;
    }

    final server = widget.server as GroupedServer;
    selectedRegion = server.group.getPreferredRegion();

    if (!_instances.contains(serverInfo)) {
      serverInfo = _instances.first;
      _setCollectionData();
    }
  }

  void _setCollectionData() {
    if (!_modsLoaded) return;

    final mods = serverInfo.mods
        .map(
          (e) => CollectionMod(name: e.name, version: e.version, link: e.link),
        )
        .toList();
    collections = [];
    for (final collection in collectionBox.values) {
      final gameplayMods = collection
          .getLocalMods(
            onlyGameplay: true,
            expandCollections: true,
            expandGameplayCollections: false,
          )
          .whereType<FrostyMod>()
          .map((e) => e.toCollectionMod())
          .toList();

      if (const ListEquality<CollectionMod>().equals(gameplayMods, mods) ||
          collection.isCosmetic ||
          gameplayMods.isEmpty) {
        collections.add(collection);
      }
    }

    final selectedCollectionId = Preferences.general.selectedCosmeticCollection;
    selectedCollection = Preferences.general.useCosmetics
        ? collections.firstWhereOrNull((x) => x.localId == selectedCollectionId)
        : null;
  }

  @override
  void didUpdateWidget(covariant ServerInfoBox oldWidget) {
    if (oldWidget.server != widget.server) {
      selectedRegion = null;
      serverInfo = widget.server.serverInfo;
      _regionResolved = false;
      _setCollectionData();
    }

    super.didUpdateWidget(oldWidget);
  }

  void _switchInstance(int page) {
    setState(() {
      serverInfo = _instances[page - 1];
      _setCollectionData();
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
      _setCollectionData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final proxiesLoading = context.watch<KyberProxyCubit>().state.loading;
    if (!proxiesLoading && !_regionResolved) {
      _regionResolved = true;
      setPreferredRegion(widget.server);
    }

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
            if (!_regionResolved || !_modsLoaded)
              Positioned.fill(
                child: Row(
                  spacing: 10,
                  mainAxisAlignment: .center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: ProgressRing(),
                    ),
                    if (!_regionResolved) ...[
                      const Text(
                        'Connecting to proxies...',
                        style: TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ] else
                      const Text(
                        'Loading mods...',
                        style: TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              )
            else
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
                          height: 40,
                          child: Row(
                            spacing: 8,
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
                                          child: _Badge(
                                            text: serverInfo.creator,
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
                              _JoinButton(
                                serverInfo: serverInfo,
                                onPressed: _joinServer,
                              ),
                            if (!widget.moderationMode) ...[
                              const Spacer(),
                              SizedBox(
                                width: 200,
                                height: 37,
                                child: _buildActionRow(),
                              ),
                            ],
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

  Future<void> _joinServer({bool spectator = false}) async {
    final cubit = context.read<ServerBrowserCubit>();
    if (cubit.state.joiningServer != null) {
      return;
    }

    String? password;
    if (serverInfo.requiresPassword) {
      password = await ServerPasswordDialog.show(
        context,
        serverInfo: serverInfo,
      );

      if (password == null || !mounted) {
        return;
      }
    }

    await cubit.joinServer(
      server: serverInfo,
      serverPassword: password,
      spectator: spectator,
      cosmeticCollection: selectedCollection,
    );
  }

  void _shareServer() {
    final uri = Uri(
      scheme: 'https',
      host: 'api.prod.kyber.gg',
      path: 'redirect',
      queryParameters: {
        'target': 'join_server?server_id=${serverInfo.id}',
      },
    );
    Clipboard.setData(.new(text: uri.toString()));
    NotificationService.info(message: 'Copied to clipboard!');
  }

  Widget _buildActionRow() => _ActionDropdown<ModCollectionMetaData?>(
    items: [
      DropdownItem(value: null, label: 'No Cosmetics'),
      ...collections.map((e) => DropdownItem(value: e, label: e.title)),
    ],
    selectedItem: selectedCollection,
    onChanged: (value) {
      setState(() => selectedCollection = value);
      Preferences.general.useCosmetics = value != null;
      if (value != null) {
        Preferences.general.selectedCosmeticCollection = value.localId;
      }
    },
    itemBuilder: (item) => Row(
      children: [
        SizedBox(
          height: 40,
          width: 40,
          child: item.value != null
              ? CollectionIcon(collection: item.value!)
              : const Icon(mt.Icons.block, size: 20),
        ),
        Container(
          width: 2,
          height: 40,
          color: decoColor,
        ),
        Expanded(
          child: Padding(
            padding: const .symmetric(
              horizontal: 10,
            ),
            child: Text(
              item.label,
              style: const TextStyle(
                fontFamily: FontFamily.battlefrontUI,
                fontSize: 17,
              ),
            ),
          ),
        ),
      ],
    ),
    actions: [
      KyberTooltip(
        message: 'Share this server',
        child: CustomIconButton(
          size: 21,
          iconData: mt.Icons.share,
          onPressed: _shareServer,
        ),
      ),
      if (widget.onServerSelected == null)
        KyberTooltip(
          message: 'Join as a spectator',
          child: CustomIconButton(
            size: 21,
            iconData: mt.Icons.camera_alt_sharp,
            onPressed: () => _joinServer(spectator: true),
          ),
        ),
      Row(
        spacing: 10,
        children: [
          KyberTooltip(
            message: 'Select a cosmetic collection to use on this server',
            child: CustomSvgButton(
              size: 19,
              path: Assets.icons.kblCollection.path,
              color: kWhiteColor1,
              onPressed: null,
            ),
          ),
          Text(
            selectedCollection?.mods.length.toString() ?? '0',
            style: const .new(
              fontFamily: FontFamily.battlefrontUI,
              color: kWhiteColor1,
              fontSize: 19,
            ),
          ),
        ],
      ),
    ],
  );
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({
    required this.serverInfo,
    required this.onPressed,
    super.key,
  });

  final Server serverInfo;
  final VoidCallback onPressed;

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
              onPressed: downloading ? null : onPressed,
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
        child: ClipRRect(
          borderRadius: .circular(kDefaultInnerBorderRadius - 1.5),
          child: Stack(
            clipBehavior: .antiAliasWithSaveLayer,
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
      padding: const .symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kControlBackgroundColor,
        border: .all(color: kButtonBorder, width: 1.5),
        borderRadius: .circular(kDefaultInnerBorderRadius),
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
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
                height: 1,
                color: kWhiteColor,
                fontFeatures: [
                  .tabularFigures(),
                ],
              ),
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
      for (final region in regions) (region.name.toUpperCase(), region),
    ];

    const border = BorderSide(color: kButtonBorder, width: 1.5);

    return Stack(
      children: [
        Container(
          height: 30,
          padding: const .only(left: 15),
          margin: const .only(left: 17, top: 2.5),
          clipBehavior: .hardEdge,
          decoration: BoxDecoration(
            color: kControlBackgroundColor,
            border: .fromLTRB(top: border, bottom: border, right: border),
            borderRadius: .horizontal(
              right: const .circular(kDefaultInnerBorderRadius),
            ),
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
                        color: Colors.transparent,
                        duration: kDefaultDuration,
                        padding: const .symmetric(horizontal: 12, vertical: 4),
                        alignment: .center,
                        child: AnimatedDefaultTextStyle(
                          duration: kDefaultDuration,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: .w700,
                            fontFamily: FontFamily.battlefrontUI,
                            height: 1,
                            color: hovered || active
                                ? kActiveColor
                                : kWhiteColor,
                          ),
                          child: Builder(
                            builder: (context) {
                              return Text(label);
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        SvgPicture.asset(
          regionIcons[selected?.name]!,
          height: 37.5,
        ),
      ],
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
          builder: (_, hovered) => AbsorbPointer(
            child: DefaultTextStyle(
              style: TextStyle(
                fontFamily: FontFamily.battlefrontUI,
                fontSize: 16,
                fontWeight: .w700,
                color: !hovered ? kWhiteColor : kActiveColor,
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
        ),
        if (expanded) widget.child,
      ],
    );
  }
}

class _ActionDropdown<T> extends StatefulWidget {
  const _ActionDropdown({
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.itemBuilder,
    this.actions = const [],
    super.key,
  });

  final List<DropdownItem<T>> items;
  final T? selectedItem;
  final ValueChanged<T> onChanged;
  final Widget Function(DropdownItem<T> item) itemBuilder;
  final List<Widget> actions;

  @override
  State<_ActionDropdown<T>> createState() => _ActionDropdownState<T>();
}

class _ActionDropdownState<T> extends State<_ActionDropdown<T>>
    with SingleTickerProviderStateMixin {
  bool isOpen = false;
  late final AnimationController _animationController = AnimationController(
    duration: const Duration(milliseconds: 100),
    vsync: this,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.easeOut,
  );

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(covariant _ActionDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _overlayEntry?.markNeedsBuild(),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _toggleDropdown() => isOpen ? _closeDropdown() : _openDropdown();

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _animationController.forward();
    setState(() => isOpen = true);
  }

  Future<void> _closeDropdown() async {
    await _animationController.reverse();
    _removeOverlay();
    if (mounted) setState(() => isOpen = false);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildItem(DropdownItem<T> item) {
    final selected = item.value == widget.selectedItem;

    return ButtonBuilder(
      onClick: () async {
        widget.onChanged(item.value);
        await _closeDropdown();
      },
      builder: (context, hovered) => AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 150),
        style: TextStyle(
          fontFamily: FontFamily.battlefrontUI,
          color: hovered || selected ? kActiveColor : kWhiteColor,
        ),
        child: ColoredBox(
          color: mt.Colors.black38,
          child: Row(
            children: [
              Expanded(child: widget.itemBuilder(item)),
              if (selected)
                Padding(
                  padding: const .only(right: 12),
                  child: Icon(mt.Icons.check, size: 18, color: kActiveColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _closeDropdown,
        behavior: .translucent,
        child: Stack(
          clipBehavior: .none,
          children: [
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height),
                child: ClipRRect(
                  borderRadius: const .vertical(
                    bottom: .circular(kDefaultInnerBorderRadius),
                  ),
                  child: BackgroundBlur(
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: kDefaultBorder,
                          left: kDefaultBorder,
                          right: kDefaultBorder,
                        ),
                        borderRadius: .vertical(
                          bottom: .circular(kDefaultInnerBorderRadius),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const .vertical(
                          bottom: .circular(
                            kDefaultInnerBorderRadius - 2,
                          ),
                        ),
                        child: SizeTransition(
                          sizeFactor: _animation,
                          alignment: .bottomCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.separated(
                              padding: .zero,
                              shrinkWrap: true,
                              separatorBuilder: (_, _) => const CardSection(),
                              itemCount: widget.items.length,
                              itemBuilder: (_, index) =>
                                  _buildItem(widget.items[index]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: ButtonBuilder(
        onClick: _toggleDropdown,
        builder: (context, hovered) => AnimatedContainer(
          height: 48,
          padding: const .only(left: 10, right: 10),
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: kControlBackgroundColor,
            border: .all(
              color: kDefaultBorder.color,
              width: kDefaultBorder.width,
            ),
            borderRadius: !isOpen
                ? .circular(kDefaultInnerBorderRadius)
                : const .vertical(
                    top: .circular(kDefaultInnerBorderRadius),
                  ),
          ),
          child: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              if (widget.actions.isNotEmpty)
                ...widget.actions.sublist(0, widget.actions.length - 1),
              Row(
                mainAxisSize: .min,
                spacing: 4,
                children: [
                  ?widget.actions.lastOrNull,
                  Icon(
                    isOpen ? mt.Icons.arrow_drop_up : mt.Icons.arrow_drop_down,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
