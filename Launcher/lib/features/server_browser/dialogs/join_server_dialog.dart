import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_icon.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/background_image.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_mod_tile.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:local_hero/local_hero.dart';
import 'package:logging/logging.dart';
import 'package:vector_graphics/vector_graphics.dart';

class CosmeticModsDialog extends StatefulWidget {
  const CosmeticModsDialog({
    required this.server,
    this.skipPasswordCheck = false,
    super.key,
  });

  final ServerEntry server;
  final bool skipPasswordCheck;

  @override
  State<CosmeticModsDialog> createState() => _CosmeticModsDialogState();
}

class _CosmeticModsDialogState extends State<CosmeticModsDialog> {
  late bool correctPassword;

  final _logger = Logger('join_server_dialog');

  String? route;

  String password = '';

  bool isMultiRegion = false;
  bool isCrossRegion = false;
  late ServerRegion selectedRegion;
  int _regionTabIndex = 0;

  bool withoutMods = true;
  bool spectator = false;
  bool showInstanceSelector = false;

  late Server serverInfo;

  List<ModCollectionMetaData> collections = [];
  ModCollectionMetaData? selectedCollection;

  @override
  void initState() {
    if (widget.server case GroupedServer(:final group)) {
      isMultiRegion = group.isMultiRegion();
      isCrossRegion = group.groupType == ServerGroupType.crossRegion;
      if (!isCrossRegion) {
        selectedRegion = group.getPreferredRegion();
      } else {
        final regionByProxy = findRegion(group);

        if (regionByProxy != null) {
          selectedRegion = regionByProxy;
          _regionTabIndex = group.regions.toList().indexOf(regionByProxy);
        } else {
          selectedRegion = group.regions.first;
          _logger.warning(
            'Could not find a matching proxy for any of the server regions, defaulting to $selectedRegion',
          );
        }
      }
    }

    serverInfo = widget.server.serverInfo;
    correctPassword = widget.skipPasswordCheck || !serverInfo.requiresPassword;
    withoutMods = !Preferences.general.useCosmetics;
    final mods = serverInfo.mods
        .map(
          (e) => CollectionMod(name: e.name, version: e.version, link: e.link),
        )
        .toList();
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

    if (Preferences.general.selectedCosmeticCollection != null) {
      final selectedCollectionId =
          Preferences.general.selectedCosmeticCollection;
      if (collectionBox.containsKey(selectedCollectionId) &&
          collections.any((x) => x.localId == selectedCollectionId)) {
        selectedCollection = collectionBox.get(selectedCollectionId);
      }
    }

    selectedCollection ??= collections.firstOrNull;

    if (!correctPassword) {
      route = 'password';
    }

    super.initState();
  }

  ServerRegion? findRegion(ServerGroup group) {
    final proxies = navigatorKey.currentContext!
        .read<KyberProxyCubit>()
        .state
        .proxies;

    // TODO: maybe respect the user selected proxy here?

    for (final proxy in proxies) {
      final region = group.regionProxyMappings[proxy.proxy.id];

      if (region != null) {
        return region;
      }
    }

    return null;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> checkPassword() async {
    try {
      final service = sl.get<KyberGRPCService>();
      final result = await service.serverBrowserClient.canJoinServer(
        CanJoinServerRequest(
          id: serverInfo.id,
          password: password,
        ),
      );

      if (result.canJoin) {
        return setState(() {
          route = null;
          correctPassword = true;
        });
      }

      NotificationService.showNotification(
        message: 'Invalid password',
        severity: InfoBarSeverity.error,
      );
    } catch (e, s) {
      if (e is GrpcError && e.code == StatusCode.notFound) {
        Navigator.pop(context);
        NotificationService.showNotification(
          message: 'Server not found',
          severity: InfoBarSeverity.error,
        );
      } else {
        Logger.root.severe('An error occurred', e, s);
        NotificationService.showNotification(
          message: 'An error occurred',
          severity: InfoBarSeverity.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (intent) {
            if (route != null && route != 'password') {
              setState(() => route = null);
              return null;
            }

            Navigator.pop(context);

            return null;
          },
        ),
      },
      child: FocusScope(
        autofocus: true,
        child: LocalHeroScope(
          curve: Curves.easeOutCubic,
          createRectTween: (begin, end) {
            return mt.MaterialRectCenterArcTween(begin: begin, end: end);
          },
          child: Padding(
            padding: kDefaultPadding.copyWith(top: 60),
            child: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: _NavigationBar(
                    server: widget.server,
                    route: route,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 50),
                    child: Builder(
                      key: ValueKey(route ?? 'main'),
                      builder: (context) {
                        if (route == 'password') {
                          return _PasswordPage(server: serverInfo);
                        }

                        if (route == 'mods') {
                          return _ModsPage(
                            onBack: () => setState(() => route = null),
                            server: serverInfo,
                            collections: collections,
                            selectedCollection: selectedCollection,
                          );
                        }

                        if (widget.server case GroupedServer(:final group)) {
                          final displayedServers = selectedRegion == .all
                              ? group.servers
                              : group.getForRegion(selectedRegion);

                          return Column(
                            children: [
                              if (isCrossRegion && isMultiRegion)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 15),
                                  child: SizedBox(
                                    width: 450,
                                    height: 35,
                                    child: KyberTabBar(
                                      tabs: [
                                        for (final region in group.regions)
                                          Text(
                                            region.displayName.toUpperCase(),
                                          ),
                                      ],
                                      selectedIndex: _regionTabIndex,
                                      onChanged: (index) {
                                        setState(() {
                                          selectedRegion = group.regions
                                              .elementAt(index);
                                          _regionTabIndex = index;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              SizedBox(
                                height: 480,
                                child: LayoutBuilder(
                                  builder: (context, constraints) => ListView(
                                    padding: .only(
                                      left:
                                          constraints.maxWidth / 2 -
                                          (450 * 0.5),
                                    ),
                                    scrollDirection: .horizontal,
                                    children: [
                                      for (final server in displayedServers)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 25,
                                          ),
                                          child: LocalHero(
                                            tag:
                                                'main_server_card_${server.id}',
                                            child: _ServerCard(
                                              server: server,
                                              onMods: () => setState(
                                                () => route = 'mods',
                                              ),
                                              onBack: () =>
                                                  setState(() => route = null),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          spacing: 20,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                LocalHero(
                                  tag: 'main_server_card',
                                  child: _ServerCard(
                                    server:
                                        (widget.server as SingleServer).server,
                                    onMods: () =>
                                        setState(() => route = 'mods'),
                                    onBack: () => setState(() => route = null),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// this entire file is a huge mess right now, it'll be split up and cleaned later, just want to get the functionality in place for now

class _PasswordPage extends StatelessWidget {
  const _PasswordPage({required this.server, super.key});

  final Server server;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      alignment: .center,
      child: Column(
        children: [
          LocalHero(
            tag: 'main_server_card',
            child: _ServerCard(
              server: server,
              type: .minimal,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.4),
              borderRadius: const .vertical(
                bottom: .circular(kDefaultInnerBorderRadius),
              ),
              border: const Border(
                bottom: kDefaultBorder,
                left: kDefaultBorder,
                right: kDefaultBorder,
              ),
            ),
            child: Padding(
              padding: const .all(15),
              child: Column(
                spacing: 50,
                children: [
                  KyberInput(
                    placeholder: 'SERVER PASSWORD',
                    onFieldSubmitted: (_) => context
                        .findAncestorStateOfType<_CosmeticModsDialogState>()
                        ?.checkPassword(),
                    onChanged: (value) => context
                        .findAncestorStateOfType<_CosmeticModsDialogState>()
                    // this is so cooked but it works for now
                    // TODO: clean this up when refactoring the entire dialog
                        ?.setState(
                          () =>
                              context
                                      .findAncestorStateOfType<
                                        _CosmeticModsDialogState
                                      >()
                                      ?.password =
                                  value,
                        ),
                  ),
                  Row(
                    mainAxisAlignment: .center,
                    spacing: 10,
                    children: [
                      KyberButton(
                        text: 'JOIN SERVER',
                        onPressed: () => context
                            .findAncestorStateOfType<_CosmeticModsDialogState>()
                            ?.checkPassword(),
                      ),
                      KyberButton(
                        text: 'BACK',
                        onPressed: () => Navigator.of(context).pop()
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModsPage extends StatefulWidget {
  const _ModsPage({
    required this.server,
    required this.collections,
    required this.selectedCollection,
    required this.onBack,
    super.key,
  });

  final Server server;
  final List<ModCollectionMetaData> collections;
  final ModCollectionMetaData? selectedCollection;
  final VoidCallback onBack;

  @override
  State<_ModsPage> createState() => _ModsPageState();
}

class _ModsPageState extends State<_ModsPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450,
      alignment: .center,
      child: Column(
        spacing: 20,
        children: [
          Row(
            mainAxisAlignment: .center,
            children: [
              LocalHero(
                tag: 'main_server_card',
                child: _ServerCard(
                  onBack: widget.onBack,
                  server: widget.server,
                  type: .minimal,
                ),
              ),
            ],
          ),
          KyberDropdown<ModCollectionMetaData>(
            onChanged: (value) {
              //setState(() => selectedCollection = value);
              Preferences.general.selectedCosmeticCollection = value.localId;
            },
            itemBuilder: (DropdownItem<dynamic> item) {
              item as DropdownItem<ModCollectionMetaData>;
              return Row(
                children: [
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: CollectionIcon(collection: item.value),
                  ),
                  Container(width: 2, height: 40, color: decoColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        item.value.title,
                        style: const TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            items: widget.collections
                .map((e) => DropdownItem(value: e, label: e.title))
                .toList(),
            selectedItem: widget.selectedCollection,
            placeholder: 'NO COSMETICS',
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 450,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.4),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(kDefaultInnerBorderRadius),
                    ),
                    border: const Border(
                      top: kDefaultBorder,
                      left: kDefaultBorder,
                      right: kDefaultBorder,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.center,
                  child: const Text(
                    'MODS',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1,
                      fontFamily: FontFamily.battlefrontUI,
                    ),
                  ),
                ),
                Stack(
                  fit: StackFit.passthrough,
                  children: [
                    IntrinsicHeight(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.4),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(
                                kDefaultInnerBorderRadius,
                              ),
                            ),
                            border: const Border(
                              bottom: kDefaultBorder,
                              left: kDefaultBorder,
                              right: kDefaultBorder,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      constraints: const BoxConstraints(
                        maxHeight: 300,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(kDefaultInnerBorderRadius),
                        ),
                        child: RepaintBoundary(
                          key: const Key('server_list'),
                          child: KyberList(
                            colorOpacity: .4,
                            shrinkWrap: true,
                            blur: false,
                            activeIndex: -1,
                            itemPadding: EdgeInsets.zero,
                            physics: const ScrollPhysics(),
                            itemBuilder: (context, index) {
                              final mod = widget.server.mods[index];
                              return ServerModTile(mod: mod);
                            },
                            itemCount: widget.server.mods.length,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 450,
                            height: 20,
                            alignment: Alignment.bottomCenter,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(
                                  kDefaultInnerBorderRadius,
                                ),
                              ),
                              border: Border(bottom: kDefaultBorder),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({required this.server, this.route, super.key});

  final ServerEntry server;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final name = switch (server) {
      GroupedServer(:final group) => group.groupName,
      SingleServer(:final server) => server.name,
    };
    final routes = ['PLAY', name, ?route];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        BackgroundBlur(
          key: const ValueKey('subNavBarList'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 41,
                width: 1.5,
                color: kWhiteColor,
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                separatorBuilder: (context, index) => Transform.rotate(
                  angle: 18 * 3.14 / 180,
                  child: UnconstrainedBox(
                    child: Container(
                      height: 20,
                      width: 2,
                      color: kGrayColor,
                    ),
                  ),
                ),
                itemBuilder: (context, index) => NavigationBarSubItem(
                  isLast: index == routes.length - 1,
                  route: routes.elementAt(index),
                  index: index,
                  fullRoute: "/${routes.take(index + 1).join("/")}",
                ),
                itemCount: routes.length,
              ),
              Container(
                height: 41,
                width: 1.5,
                color: kWhiteColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ServerCardType { full, minimal }

class _ServerCard extends StatefulWidget {
  const _ServerCard({
    required this.server,
    this.type = _ServerCardType.full,
    this.onMods,
    this.onBack,
    super.key,
  });

  final Server server;
  final _ServerCardType type;
  final VoidCallback? onBack;
  final VoidCallback? onMods;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  String selectedProxy = 'grm';

  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final map = MapHelper.getMap(
      widget.server.levelSetup.mode,
      widget.server.levelSetup.map,
    );
    final modeName = widget.server.levelSetup.modeName.isNotEmpty
        ? widget.server.levelSetup.modeName
        : MapHelper.getMode(widget.server.levelSetup.mode)?.name ??
              widget.server.levelSetup.mode;
    final levelName = widget.server.levelSetup.mapName.isNotEmpty
        ? widget.server.levelSetup.mapName
        : map?.name ?? widget.server.levelSetup.map;

    final maxHeight = switch (widget.type) {
      _ServerCardType.full => 432.0,
      _ServerCardType.minimal => widget.onBack != null ? 172.0 : 146.0,
    };

    final borderRadius = switch (widget.type) {
      _ServerCardType.full => BorderRadius.circular(kDefaultInnerBorderRadius),
      _ServerCardType.minimal =>
        widget.onBack != null
            ? BorderRadius.circular(kDefaultInnerBorderRadius)
            : const BorderRadius.vertical(
                top: .circular(kDefaultInnerBorderRadius),
              ),
    };

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: SizedBox(
        height: maxHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  width: 450,
                  height: constraints.maxHeight < 240 ? 146 : 432,
                  decoration: BoxDecoration(
                    border: kDefaultAllBorder,
                    borderRadius: borderRadius,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      kDefaultInnerBorderRadius - 2,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Column(
                          children: [
                            SizedBox(
                              height: constraints.maxHeight < 240 ? 142 : 240,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ServerBackgroundImage(
                                      map: map?.map ?? '',
                                      fade: false,
                                      blur: false,
                                      imageId:
                                          widget.server.mapImageHash.isNotEmpty
                                          ? widget.server.mapImageHash
                                          : null,
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Padding(
                                          padding: const .all(25),
                                          child: Column(
                                            spacing: 15,
                                            mainAxisAlignment: .spaceBetween,
                                            children: [
                                              Column(
                                                children: [
                                                  Text(
                                                    modeName.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontFamily: FontFamily
                                                          .battlefrontUI,
                                                      fontSize: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    levelName.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontFamily: FontFamily
                                                          .battlefrontUI,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (widget.type ==
                                                      _ServerCardType.full &&
                                                  constraints.maxHeight >= 240)
                                                Padding(
                                                  padding: const .only(
                                                    bottom: 28,
                                                  ),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    children: [
                                                      _KyberTag(
                                                        prefix: Assets
                                                            .icons
                                                            .iconLib
                                                            .kblHostIcon
                                                            .svg(),
                                                        text: 'KYBER',
                                                      ),
                                                      _KyberTag(
                                                        text: widget
                                                            .server
                                                            .region,
                                                      ),
                                                      _KyberTag(
                                                        text:
                                                            '${widget.server.playerCount}/${widget.server.maxPlayerCount}',
                                                      ),
                                                      _KyberTag(text: 'VOIP'),
                                                      _KyberTag(
                                                        text:
                                                            '${widget.server.mods.length} MOD',
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.type == _ServerCardType.full &&
                                constraints.maxHeight >= 240) ...[
                              const CardSection(),
                              Expanded(
                                child: Container(
                                  color: Colors.black.withOpacity(.5),
                                  padding: const .all(15),
                                  child: const SingleChildScrollView(
                                    padding: .only(top: 20),
                                    child: Text(
                                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ',
                                      style: .new(
                                        fontFamily: FontFamily.battlefrontUI,
                                        color: kWhiteColor,
                                        fontSize: 16,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (widget.type == _ServerCardType.full &&
                            constraints.maxHeight >= 240)
                          Positioned(
                            left: 450 / 2 - 104,
                            top: 240 - 45 / 2,
                            child: _PlayButton(
                              onPressed: () {},
                            ),
                          ),
                        if (hovered && widget.type == _ServerCardType.full)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: FadeIn(
                              duration: const .new(milliseconds: 150),
                              child: Container(
                                height: 36,
                                width: 450,
                                margin: const .all(15),
                                child: BackgroundBlur(
                                  blurColorOpacity: 1,
                                  borderRadius: .circular(
                                    kDefaultInnerBorderRadius,
                                  ),
                                  child: KyberTabBar(
                                    selectedIndex: -1,
                                    onChanged: (value) {
                                      switch (value) {
                                        case 0:
                                        // spectate
                                        case 1:
                                          widget.onMods?.call();
                                        case 2:
                                        // report
                                      }
                                    },
                                    tabs: [
                                      Text('SPECTATE'),
                                      Text('MODS'),
                                      Text('REPORT'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // TODO: cleanup
                if (constraints.maxHeight < 240 &&
                    (widget.type != .minimal ||
                        (widget.type == .minimal && widget.onBack != null)))
                  Positioned(
                    left: 450 / 2 - 104,
                    top: 146 - 45 / 2,
                    child: FadeIn(
                      child: _PlayButton(
                        onPressed: widget.onBack ?? () {},
                        text: 'BACK',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KyberTag extends StatelessWidget {
  const _KyberTag({
    required this.text,
    super.key,
    this.prefix,
    this.minWidth = 40,
  });

  final double? minWidth;
  final Widget? prefix;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const .all(5),
      constraints: BoxConstraints(
        minWidth: minWidth ?? 0,
      ),
      decoration: BoxDecoration(
        border: .all(
          color: decoColor,
          width: 1.5,
        ),
        borderRadius: const .all(.circular(4)),
        color: Colors.black,
      ),
      child: Row(
        mainAxisSize: .min,
        mainAxisAlignment: .center,
        children: [
          if (prefix != null) ...[
            prefix!,
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: const TextStyle(
              fontFamily: FontFamily.battlefrontUI,
              fontSize: 12,
              height: 1,
            ),
            textAlign: .center,
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onPressed, super.key, this.text});

  final VoidCallback onPressed;
  final String? text;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final target = hovered ? kActiveColor : kWhiteColor;

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Stack(
          children: [
            VectorGraphic(
              loader: AssetBytesLoader(Assets.icons.kblPlayIcon.path),
              height: 47,
              width: 208,
            ),
            VectorGraphic(
              loader: AssetBytesLoader(Assets.icons.kblPlayIconBorder.path),
              height: 47,
              width: 208,
              colorFilter: ColorFilter.mode(
                target,
                BlendMode.srcIn,
              ),
            ),
            // TODO: re-enable animations?
            //TweenAnimationBuilder<Color?>(
            //  tween: ColorTween(end: target),
            //  duration: const Duration(milliseconds: 300),
            //  builder: (_, c, __) => Assets.icons.kblPlayIcon.svg(
            //    height: 47,
            //    width: 208,
            //    fit: BoxFit.contain,
            //    theme: SvgTheme(currentColor: c!),
            //  ),
            //),
            Positioned(
              top: 12,
              left: 72,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: target,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1,
                  shadows: hovered
                      ? [
                          Shadow(
                            color: kActiveColor.withOpacity(.7),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Text(widget.text ?? 'PLAY'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinDialogResult {
  JoinDialogResult({
    required this.collection,
    required this.spectator,
    this.password = '',
    this.instanceId,
  });

  final ModCollectionMetaData collection;
  final bool spectator;
  final String password;

  /// Only useful for server groups
  final String? instanceId;
}
