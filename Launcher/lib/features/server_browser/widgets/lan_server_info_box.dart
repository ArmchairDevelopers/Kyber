import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/features/server_browser/helpers/lan_server_browser_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/features/server_browser/providers/lan_discovery_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_mod_tile.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class LanServerInfoBox extends StatelessWidget {
  const LanServerInfoBox({required this.server, super.key});

  final LanServer server;

  @override
  Widget build(BuildContext context) {
    final levelSetup = server.levelSetup;
    final mapImage = levelSetup == null
        ? null
        : MapHelper.getImageForMap(levelSetup.map);
    final canJoin = LanServerBrowserHelper.canJoinServer(context, server: server);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(kDefaultOuterBorderRadius),
          ),
          child: SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (mapImage != null)
                  mapImage.image(
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    colorBlendMode: BlendMode.darken,
                    color: Colors.black.withOpacity(.35),
                  )
                else
                  Container(color: decoColor.withOpacity(.35)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${server.address}:${server.port}',
                        style: const TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 14,
                          color: kWhiteColor,
                        ),
                      ),
                      const Spacer(),
                      if (levelSetup != null)
                        Text(
                          [
                            if (levelSetup.modeName.isNotEmpty)
                              levelSetup.modeName
                            else
                              MapHelper.getMode(levelSetup.mode)?.name ??
                                  levelSetup.mode,
                            if (levelSetup.mapName.isNotEmpty)
                              levelSetup.mapName
                            else
                              MapHelper.getMap(
                                    levelSetup.mode,
                                    levelSetup.map,
                                  )?.name ??
                                  levelSetup.map,
                          ].join(' | ').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: server.gameplayMods.isEmpty
              ? const Center(
                  child: Text(
                    'NO GAMEPLAY MODS REQUIRED',
                    style: TextStyle(fontFamily: FontFamily.battlefrontUI),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: server.gameplayMods.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final mod = server.gameplayMods[index];
                    return ServerModTile(
                      mod: ServerMod(name: mod.name, version: mod.version),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: KyberButton(
            text: 'JOIN SERVER',
            onPressed: canJoin
                ? () => context.read<LanDiscoveryCubit>().joinServer(server)
                : null,
          ),
        ),
      ],
    );
  }
}
