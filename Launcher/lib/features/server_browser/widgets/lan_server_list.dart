import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/direct_connect_dialog.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/features/server_browser/providers/lan_discovery_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list_header.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class LanServerListWidget extends StatelessWidget {
  const LanServerListWidget({super.key});

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
                  return _LanServerEntry(server: server);
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
  const _LanServerEntry({required this.server});

  final LanServer server;

  @override
  Widget build(BuildContext context) {
    final levelSetup = server.levelSetup;

    return Container(
      height: 65,
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: decoColor, width: 2),
          right: BorderSide(color: decoColor, width: 2),
          bottom: BorderSide(color: decoColor, width: 2),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
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
                    '${server.address}:${server.port}',
                    if (levelSetup?.modeName.isNotEmpty ?? false)
                      levelSetup!.modeName
                    else if (levelSetup?.mode.isNotEmpty ?? false)
                      levelSetup!.mode,
                    if (levelSetup?.mapName.isNotEmpty ?? false)
                      levelSetup!.mapName
                    else if (levelSetup?.map.isNotEmpty ?? false)
                      levelSetup!.map,
                    if (server.mods.isNotEmpty) '${server.mods.length} mods',
                  ].join(' - ').toUpperCase(),
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
          SizedBox(
            width: 95,
            child: Text(
              server.maxPlayers == null ? '-' : '0/${server.maxPlayers}',
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              'LAN',
              textAlign: TextAlign.center,
              style: FluentTheme.of(context).typography.body,
            ),
          ),
          SizedBox(
            width: 70,
            child: CustomIconButton(
              iconData: FluentIcons.play_solid,
              onPressed: () => showKyberDialog(
                context: context,
                builder: (_) => DirectConnectDialog(
                  initialIp: server.address,
                  initialPort: server.port,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
