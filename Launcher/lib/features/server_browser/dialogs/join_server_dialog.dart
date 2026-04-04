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
import 'package:kyber_launcher/shared/ui/buttons/interactive_button.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:local_hero/local_hero.dart';
import 'package:logging/logging.dart';

const _kCardWidth = 450.0;

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

  late Server serverInfo;

  List<ModCollectionMetaData> collections = [];
  ModCollectionMetaData? selectedCollection;

  @override
  void initState() {
    if (widget.server case GroupedServer(:final group)) {
      isMultiRegion = group.isMultiRegion();
      isCrossRegion = group.groupType == .crossRegion;
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
    final mods = serverInfo.mods
        .map(
          (e) => CollectionMod(name: e.name, version: e.version, link: e.link),
        )
        .toList();

    collections.add(.noMods().copyWith(title: 'No Cosmetics'));

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

      NotificationService.error(message: 'Invalid password');
    } catch (e, s) {
      if (e is GrpcError && e.code == StatusCode.notFound) {
        Navigator.pop(context);
        NotificationService.error(message: 'Server not found');
      } else {
        Logger.root.severe('An error occurred', e, s);
        NotificationService.error(message: 'An error occurred');
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
              setRoute(null);
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
                  child: Row(
                    spacing: 15,
                    children: [
                      SizedBox(
                        width: 40,
                        child: ButtonBuilder(
                          onClick: () => Navigator.of(context).pop(),
                          builder: (context, hovered) => Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Container(
                                width: 1.5,
                                color: hovered ? kActiveColor : decoColor,
                              ),
                              const Icon(
                                mt.Icons.close,
                                size: 22,
                              ),
                              Container(
                                width: 1.5,
                                color: hovered ? kActiveColor : decoColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _NavigationBar(
                        server: widget.server,
                        route: route,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const .only(bottom: 50),
                    child: Builder(
                      key: ValueKey(route ?? 'main'),
                      builder: (context) {
                        if (route == 'password') {
                          return _PasswordPage(
                            server: serverInfo,
                            onPasswordChanged: (value) =>
                                setState(() => password = value),
                            onSubmit: checkPassword,
                          );
                        }

                        if (route == 'mods') {
                          return _ModsPage(
                            onBack: () => setRoute(null),
                            onChanged: (item) =>
                                setState(() => selectedCollection = item),
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
                                  padding: const .only(bottom: 15),
                                  child: SizedBox(
                                    width: _kCardWidth,
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
                                          (_kCardWidth * 0.5),
                                    ),
                                    scrollDirection: .horizontal,
                                    children: [
                                      for (final server in displayedServers)
                                        Padding(
                                          padding: const .only(
                                            right: 25,
                                          ),
                                          child: LocalHero(
                                            tag:
                                                'main_server_card_${server.id}',
                                            child: _ServerCard(
                                              server: server,
                                              onMods: () => setRoute('mods'),
                                              onBack: () => setRoute(null),
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

                        final singleServer = widget.server as SingleServer;

                        return Column(
                          spacing: 20,
                          mainAxisAlignment: .center,
                          children: [
                            Row(
                              mainAxisAlignment: .center,
                              children: [
                                LocalHero(
                                  tag: 'main_server_card',
                                  child: _ServerCard(
                                    server: singleServer.server,
                                    onMods: () => setRoute('mods'),
                                    onBack: () => setRoute(null),
                                    onPlay: (value) {
                                      final collection =
                                          selectedCollection ?? .noMods();
                                      Navigator.of(context).pop(
                                        JoinDialogResult(
                                          collection: collection,
                                          spectator: value,
                                        ),
                                      );
                                    },
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

  void setRoute(String? route) {
    if (!mounted) {
      return;
    }

    setState(() => this.route = route);
  }
}

class _PasswordPage extends StatelessWidget {
  const _PasswordPage({
    required this.server,
    required this.onPasswordChanged,
    required this.onSubmit,
  });

  final Server server;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kCardWidth,
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
                    onFieldSubmitted: (_) => onSubmit(),
                    onChanged: onPasswordChanged,
                  ),
                  Row(
                    mainAxisAlignment: .center,
                    spacing: 10,
                    children: [
                      KyberButton(
                        text: 'JOIN SERVER',
                        onPressed: onSubmit,
                      ),
                      KyberButton(
                        text: 'BACK',
                        onPressed: () => Navigator.of(context).pop(),
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

class _ModsPage extends StatelessWidget {
  const _ModsPage({
    required this.server,
    required this.collections,
    required this.selectedCollection,
    required this.onBack,
    required this.onChanged,
  });

  final Server server;
  final List<ModCollectionMetaData> collections;
  final ModCollectionMetaData? selectedCollection;
  final ValueChanged<ModCollectionMetaData> onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kCardWidth,
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
                  onBack: onBack,
                  server: server,
                  type: .minimal,
                ),
              ),
            ],
          ),
          KyberDropdown<ModCollectionMetaData>(
            onChanged: (value) {
              onChanged(value);
              Preferences.general.selectedCosmeticCollection = value.localId;
            },
            itemBuilder: (DropdownItem<dynamic> item) {
              item as DropdownItem<ModCollectionMetaData>;
              return SizedBox(
                height: 40,
                child: Row(
                  children: [
                    if (collections.indexOf(item.value) != 0) ...[
                      SizedBox(
                        height: 40,
                        width: 40,
                        child: CollectionIcon(collection: item.value),
                      ),
                      Container(width: 2, height: 40, color: decoColor),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const .symmetric(horizontal: 10),
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
                ),
              );
            },
            items: collections
                .map((e) => DropdownItem(value: e, label: e.title))
                .toList(),
            selectedItem: selectedCollection,
            placeholder: 'NO COSMETICS',
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: _kCardWidth,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.4),
                    borderRadius: const .vertical(
                      top: .circular(kDefaultInnerBorderRadius),
                    ),
                    border: const Border(
                      top: kDefaultBorder,
                      left: kDefaultBorder,
                      right: kDefaultBorder,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  alignment: .center,
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
                  fit: .passthrough,
                  children: [
                    IntrinsicHeight(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.4),
                            borderRadius: const .vertical(
                              bottom: .circular(
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
                        borderRadius: const .vertical(
                          bottom: .circular(kDefaultInnerBorderRadius),
                        ),
                        child: RepaintBoundary(
                          key: const Key('server_list'),
                          child: KyberList(
                            colorOpacity: .4,
                            shrinkWrap: true,
                            blur: false,
                            activeIndex: -1,
                            itemPadding: .zero,
                            physics: const ScrollPhysics(),
                            itemBuilder: (context, index) {
                              final mod = server.mods[index];
                              return ServerModTile(mod: mod);
                            },
                            itemCount: server.mods.length,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: .bottomCenter,
                          child: Container(
                            width: _kCardWidth,
                            height: 20,
                            alignment: .bottomCenter,
                            decoration: const BoxDecoration(
                              borderRadius: .vertical(
                                bottom: .circular(
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
  const _NavigationBar({required this.server, this.route});

  final ServerEntry server;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final name = switch (server) {
      GroupedServer(:final group) => group.groupName,
      SingleServer(:final server) => server.name,
    };
    final routes = ['PLAY', name, ?route];

    return BackgroundBlur(
      key: const ValueKey('subNavBarList'),
      child: Row(
        mainAxisSize: .min,
        children: [
          Container(
            height: 41,
            width: 1.5,
            color: decoColor,
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: .horizontal,
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
            color: decoColor,
          ),
        ],
      ),
    );
  }
}

enum _ServerCardType { full, minimal }

class _ServerCard extends StatefulWidget {
  const _ServerCard({
    required this.server,
    this.onPlay,
    this.type = .full,
    this.onMods,
    this.onBack,
  });

  final Server server;
  final _ServerCardType type;
  final VoidCallback? onBack;
  final VoidCallback? onMods;
  final ValueChanged<bool>? onPlay;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  bool hovered = false;

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      children: [
        _KyberTag(
          prefix: Assets.icons.iconLib.kblHostIcon.svg(),
          text: widget.server.official ? 'KYBER' : widget.server.creator,
        ),
        _KyberTag(text: widget.server.region),
        _KyberTag(
          text: '${widget.server.playerCount}/${widget.server.maxPlayerCount}',
        ),
        const _KyberTag(text: 'VOIP'),
        _KyberTag(
          text:
              '${widget.server.mods.length} MOD ${widget.server.mods.length > 1 ? 'S' : ''}',
        ),
      ],
    );
  }

  Widget _buildHoverToolbar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: FadeIn(
        duration: const .new(milliseconds: 150),
        child: Container(
          height: 36,
          width: _kCardWidth,
          margin: const .all(15),
          child: BackgroundBlur(
            blurColorOpacity: 1,
            borderRadius: .circular(kDefaultInnerBorderRadius),
            child: KyberTabBar(
              selectedIndex: -1,
              onChanged: (value) {
                switch (value) {
                  case 0:
                    widget.onPlay?.call(true);
                  case 1:
                    widget.onMods?.call();
                  case 2:
                  // TODO: implement this
                }
              },
              tabs: const [
                Text('SPECTATE'),
                Text('MODS'),
                Text('REPORT'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levelSetup = widget.server.levelSetup;
    final map = MapHelper.getMap(levelSetup.mode, levelSetup.map);
    final modeName = levelSetup.modeName.isNotEmpty
        ? levelSetup.modeName
        : MapHelper.getMode(levelSetup.mode)?.name ?? levelSetup.mode;
    final levelName = levelSetup.mapName.isNotEmpty
        ? levelSetup.mapName
        : map?.name ?? levelSetup.map;

    final maxHeight = switch (widget.type) {
      _ServerCardType.full => 432.0,
      _ServerCardType.minimal => widget.onBack != null ? 172.0 : 146.0,
    };

    final borderRadius = switch (widget.type) {
      .full => BorderRadius.circular(kDefaultInnerBorderRadius),
      .minimal =>
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
            final isFullSize =
                widget.type == _ServerCardType.full &&
                constraints.maxHeight >= 240;

            return Stack(
              children: [
                Container(
                  width: _kCardWidth,
                  height: isFullSize ? 432 : 146,
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
                              height: isFullSize ? 240 : 142,
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
                                    child: Padding(
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
                                                  fontFamily:
                                                      FontFamily.battlefrontUI,
                                                  fontSize: 24,
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                levelName.toUpperCase(),
                                                style: const TextStyle(
                                                  fontFamily:
                                                      FontFamily.battlefrontUI,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (isFullSize)
                                            Padding(
                                              padding: const .only(bottom: 28),
                                              child: _buildTags(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isFullSize) ...[
                              const CardSection(),
                              Expanded(
                                child: Container(
                                  color: Colors.black.withOpacity(.5),
                                  padding: const .all(15),
                                  child: const SingleChildScrollView(
                                    padding: .only(top: 20),
                                    child: Text(
                                      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. ',
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
                        if (isFullSize)
                          Positioned(
                            left: _kCardWidth / 2 - 104,
                            top: 240 - 45 / 2,
                            child: InteractiveButton(
                              child: const Text('PLAY'),
                              onPressed: () => widget.onPlay?.call(false),
                            ),
                          ),
                        if (hovered && widget.type == _ServerCardType.full)
                          _buildHoverToolbar(),
                      ],
                    ),
                  ),
                ),
                if (!isFullSize &&
                    (widget.type != .minimal || widget.onBack != null))
                  Positioned(
                    left: _kCardWidth / 2 - 104,
                    top: 146 - 45 / 2,
                    child: FadeIn(
                      child: InteractiveButton(
                        onPressed: widget.onBack ?? () {},
                        child: const Text('BACK'),
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
    this.prefix,
  });

  final Widget? prefix;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const .all(5),
      constraints: const BoxConstraints(minWidth: 40),
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
