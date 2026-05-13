import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/background_image.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_page_selector.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:vector_graphics/vector_graphics.dart';

class ServerInfoBox extends StatefulWidget {
  const ServerInfoBox({
    required this.server,
    this.moderationMode = false,
    this.onServerSelected,
    this.onClose,
    super.key,
  });

  final Object server;
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
    serverInfo = widget.server is ServerGroup
        ? (widget.server as ServerGroup).getPreferredServer()
        : widget.server as Server;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ServerInfoBox oldWidget) {
    if (oldWidget.server != widget.server) {
      selectedIndex = 0;
    }

    serverInfo = widget.server is ServerGroup
        ? (widget.server as ServerGroup).getPreferredServer()
        : widget.server as Server;

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final selectedServer =
        context.read<ServerBrowserCubit>().state.selectedServer ??
        widget.server;

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

    return Container(
      decoration: BoxDecoration(
        borderRadius: .circular(kDefaultOuterBorderRadius),
        border: kDefaultAllBorder,
      ),
      child: BackgroundBlur(
        borderRadius: .circular(kDefaultOuterBorderRadius - 2),
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: Colors.black.withOpacity(0.5)),
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
                  spacing: 15,
                  children: [
                    Padding(
                      padding: const .symmetric(horizontal: 25),
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
                          children: [
                            Text(
                              serverInfo.levelSetup.mode,
                              style: const .new(
                                fontSize: 12,
                                color: Color(0xFFD9D9D9),
                                fontFamily: FontFamily.aurebesh,
                              ),
                            ),
                            Text(
                              serverInfo.name,
                            ),
                            Text(
                              '$modeName - $mapName',
                              style: const .new(
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _PlayButton(
                      // TODO: add disabled state
                      onPressed:
                          widget.onServerSelected ??
                          context.read<ServerBrowserCubit>().joinServer,
                      text: 'PLAY',
                    ),
                    Expanded(
                      child: ListView(
                        padding: const .only(left: 25, right: 25, top: 15),
                        children: [
                          _Dropdown(
                            title: Row(
                              spacing: 8,
                              children: [
                                const Text('INFO'),
                                if (serverInfo.official)
                                  _Badge(
                                    icon: Assets.icons.greyKyberLogo.svg(
                                      height: 12,
                                      width: 12,
                                    ),
                                  ),
                                _Badge(
                                  text:
                                      '${serverInfo.playerCount}/${serverInfo.maxPlayerCount}',
                                ),
                                _Badge(text: serverInfo.region),
                              ],
                            ),
                            emptyContent: serverInfo.description.isEmpty,
                            child: Builder(
                              builder: (context) {
                                final serverDescription =
                                    serverInfo.description;
                                if (serverDescription.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Text(
                                  serverDescription,
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 14,
                                    color: kWhiteColor1,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (widget.server is ServerGroup) ...[
                            const SizedBox(height: 20),
                            _InstanceSelector(
                              selectedServer: serverInfo,
                              serverGroup: widget.server as ServerGroup,
                              onSwitched: (index) {},
                            ),
                          ],
                          const SizedBox(height: 20),
                          _Dropdown(
                            title: const Row(
                              spacing: 8,
                              children: [
                                Text('MODS - 1/1'),
                              ],
                            ),
                            child: Builder(
                              builder: (context) {
                                return Column(
                                  children: [
                                    const Text(
                                      'Required Mods:',
                                      style: TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 14,
                                        color: kWhiteColor1,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    for (final mod in serverInfo.mods)
                                      Text(
                                        mod.name,
                                        style: TextStyle(
                                          fontFamily: FontFamily.battlefrontUI,
                                          fontSize: 12,
                                          color: kWhiteColor1.withOpacity(0.7),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstanceSelector extends StatelessWidget {
  const _InstanceSelector({
    required this.selectedServer,
    required this.serverGroup,
    required this.onSwitched,
    super.key,
  });

  final Server selectedServer;
  final ServerGroup serverGroup;
  final ValueChanged<int> onSwitched;

  Widget _buildServerItem(
    BuildContext context,
    Server server,
    bool isSelected,
  ) {
    return Container(
      padding: const .symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isSelected ? kActiveColor : Colors.transparent,
        borderRadius: .circular(4),
      ),
      child: Row(
        spacing: 10,
        children: [
          Text(server.name),
          const Spacer(),
          Text('${server.playerCount}/${server.maxPlayerCount}'),
        ],
      ),
    );
  }

  Widget _buildServerIndicator({required bool active}) {
    const defaultColor = Color(0xFFD9D9D9);

    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: defaultColor.withOpacity(active ? 1 : 0.5),
        borderRadius: .circular(3),
      ),
    );
  }

  Widget _buildServerRow(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        for (int i = 0; i < serverGroup.servers.length; i++) ...[
          Expanded(
            child: _buildServerIndicator(
              active: serverGroup.servers[i] == selectedServer,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Dropdown(
      initiallyExpanded: false,
      title: Row(
        spacing: 8,
        children: [
          const Text('SERVERS'),
          Expanded(child: _buildServerRow(context)),
          KyberPageSelector(
            current: serverGroup.servers.indexOf(selectedServer) + 1,
            total: serverGroup.servers.length,
            onPrevious: () => null,
            onNext: () => null,
          ),
        ],
      ),
      child: Builder(
        builder: (context) {
          return Column(
            children: List.generate(serverGroup.servers.length, (index) {
              final server = serverGroup.servers[index];
              final isSelected = server == selectedServer;

              return ButtonBuilder(
                onClick: () => onSwitched(index),
                builder: (context, hovered) {
                  return _buildServerItem(
                    context,
                    server,
                    isSelected || hovered,
                  );
                },
              );
            }),
          );
        },
      ),
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
      padding: const .all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9).withOpacity(0.1),
        borderRadius: BorderRadius.circular(kDefaultInnerBorderRadius),
      ),
      alignment: .center,
      child:
          icon ??
          Text(
            text!,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: FontFamily.battlefrontUI,
              height: 0.9,
              color: Color(0xFFD9D9D9),
            ),
          ),
    );
  }
}

class _Dropdown extends StatefulWidget {
  const _Dropdown({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.emptyContent = false,
    super.key,
  });

  final Widget title;
  final Widget child;
  final bool emptyContent;
  final bool initiallyExpanded;

  @override
  State<_Dropdown> createState() => _DropdownState();
}

class _DropdownState extends State<_Dropdown> {
  late bool expanded;

  @override
  void initState() {
    expanded = widget.initiallyExpanded;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ButtonBuilder(
          onClick: () => setState(() => expanded = !expanded),
          builder: (_, _) => Row(
            spacing: 10,
            children: [
              if (!widget.emptyContent)
                Transform.rotate(
                  angle: expanded ? 0.5 * 3.14 : 0,
                  child: Assets.icons.kblPlay.svg(
                    height: 12,
                    width: 12,
                    colorFilter: const .mode(
                      decoColor,
                      .srcIn,
                    ),
                  ),
                ),
              Expanded(child: widget.title),
            ],
          ),
        ),
        if (expanded) widget.child,
      ],
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
    final target = hovered ? kActiveColor : const Color(0xFFD9D9D9);

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
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: target,
                  fontSize: 24,
                  fontWeight: .bold,
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
                textAlign: .center,
                child: Text(widget.text ?? 'START'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
