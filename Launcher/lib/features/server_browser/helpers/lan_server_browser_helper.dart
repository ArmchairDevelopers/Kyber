import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/injection_container.dart';

class LanServerBrowserHelper {
  static bool hasInstalledMods(LanServer server) {
    if (server.gameplayMods.isEmpty) {
      return true;
    }

    return server.gameplayMods.every(
      (mod) => ModHelper.isInstalled(mod.name, mod.version, ignoreCorrupted: true),
    );
  }

  static bool canJoinServer(
    BuildContext context, {
    required LanServer server,
  }) {
    if (!hasInstalledMods(server)) {
      return false;
    }

    if (!sl.isRegistered<MaximaGameInstance>()) {
      return true;
    }

    final gameInstance = sl.get<MaximaGameInstance>();
    final instanceGameplayMods = ModHelper.getGameplayMods(gameInstance.mods);

    if (instanceGameplayMods.isEmpty && server.gameplayMods.isNotEmpty ||
        server.gameplayMods.isEmpty && instanceGameplayMods.isNotEmpty) {
      return false;
    }

    final mappedServerMods = server.gameplayMods.map((e) => e.key).toList();
    final mappedInstanceMods = instanceGameplayMods
        .map((e) => '${e.details.name}@${e.details.version}')
        .toList();
    return const ListEquality<String>().equals(
      mappedServerMods,
      mappedInstanceMods,
    );
  }
}
