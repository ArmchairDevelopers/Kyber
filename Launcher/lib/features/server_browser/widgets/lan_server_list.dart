import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/kyber/models/maps.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/models/modes.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/server_browser/helpers/lan_server_browser_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/features/server_browser/providers/lan_discovery_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list_header.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class LanServerListWidget extends StatefulWidget {
  const LanServerListWidget({super.key});

  @override
  State<LanServerListWidget> createState() => _LanServerListWidgetState();
}

class _LanServerListWidgetState extends State<LanServerListWidget> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LanDiscoveryCubit, LanDiscoveryState>(
      builder: (context, state) {
        if (state.scanning && state.servers.isEmpty) {
          return const Column(
            children: [
              ServerListHeader(withoutQuickJoin: true),
              Expanded(child: Center(child: ProgressBar())),
            ],
          );
        }

        if (state.servers.isEmpty) {
          return Column(
            children: [
              const ServerListHeader(withoutQuickJoin: true),
              Expanded(
                child: Center(
                  child: Text(
                    state.message ??
                        'No LAN servers found. You can still use Direct Connect.',
                    textAlign: TextAlign.center,
                    style: FluentTheme.of(context).typography.subtitle
                        ?.copyWith(fontFamily: FontFamily.battlefrontUI),
                  ),
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            const ServerListHeader(withoutQuickJoin: true),
            Expanded(
              child: SuperListView.builder(
                itemCount: state.servers.length,
                itemBuilder: (context, index) {
                  final server = state.servers[index];
                  final selected = state.selectedServer?.id == server.id;
                  return _LanServerEntry(
                    index: index,
                    hoveredIndex: _hoveredIndex,
                    selected: selected,
                    server: server,
                    onHover: (hovered) {
                      setState(() {
                        _hoveredIndex = hovered ? index + 1 : -1;
                      });
                    },
                    onSelect: () {
                      context.read<LanDiscoveryCubit>().selectServer(server);
                    },
                    onJoin: () {
                      context.read<LanDiscoveryCubit>().joinServer(server);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LanServerEntry extends StatelessWidget {
  const _LanServerEntry({
    required this.index,
    required this.hoveredIndex,
    required this.selected,
    required this.server,
    required this.onHover,
    required this.onSelect,
    required this.onJoin,
  });

  final int index;
  final int hoveredIndex;
  final bool selected;
  final LanServer server;
  final ValueChanged<bool> onHover;
  final VoidCallback onSelect;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final hovered = hoveredIndex == index + 1;
    final levelSetup = server.levelSetup;
    final mode =
        modes
            .where((element) => element.mode == levelSetup?.mode)
            .firstOrNull ??
        Mode.customMode();
    final map = levelSetup == null || mode.maps.isEmpty
        ? maps.first
        : maps.singleWhere(
            (element) => element['map'] == levelSetup.map,
            orElse: () => maps.first,
          );
    final canJoin = LanServerBrowserHelper.canJoinServer(context, server: server);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: Border(
          top: index == 0
              ? BorderSide(
                  color: hovered || selected ? kActiveColor : decoColor,
                  width: 2,
                )
              : BorderSide.none,
          left: BorderSide(
            color: hovered || selected ? kActiveColor : decoColor,
            width: 2,
          ),
          right: BorderSide(
            color: hovered || selected ? kActiveColor : decoColor,
            width: 2,
          ),
          bottom: BorderSide(
            color: hovered || selected || hoveredIndex == index + 2
                ? kActiveColor
                : decoColor,
            width: 2,
          ),
        ),
      ),
      child: SizedBox(
        height: 65,
        child: GestureDetector(
          onTap: onSelect,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => onHover(true),
            onExit: (_) => onHover(false),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 65,
                  child: MapHelper.getImageForMap(map['map'] as String)?.image(
                    fit: BoxFit.cover,
                    alignment: Alignment.centerLeft,
                    colorBlendMode: BlendMode.darken,
                    color: Colors.black.withOpacity(.12),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                server.name.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (server.requiresPassword) ...[
                              const SizedBox(width: 6),
                              const Icon(FluentIcons.lock, size: 14),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (levelSetup?.modeName.isNotEmpty ?? false)
                              levelSetup!.modeName
                            else if (levelSetup?.mode.isNotEmpty ?? false)
                              MapHelper.getMode(levelSetup!.mode)?.name ??
                                  levelSetup.mode,
                            if (levelSetup?.mapName.isNotEmpty ?? false)
                              levelSetup!.mapName
                            else if (levelSetup?.map.isNotEmpty ?? false)
                              MapHelper.getMap(
                                    levelSetup!.mode,
                                    levelSetup.map,
                                  )?.name ??
                                  levelSetup.map,
                            if (server.gameplayMods.isNotEmpty)
                              '${server.gameplayMods.length} required mod${server.gameplayMods.length == 1 ? '' : 's'}',
                          ].join(' | ').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            color: kWhiteColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    server.maxPlayers == null
                        ? '-'
                        : '${server.playerCount ?? 0}/${server.maxPlayers}',
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  width: 120,
                  child: const Text(
                    'LAN',
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: CustomIconButton(
                    iconData: FluentIcons.play_solid,
                    onPressed: canJoin ? onJoin : null,
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
