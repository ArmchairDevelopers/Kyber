import 'dart:io';

import 'package:dart_discord_rpc/dart_discord_rpc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mods/services/level_declaration_service.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';

const _rpcModeNames = {'Heroes Versus Villains': 'HvV'};

class RichPresence {
  RichPresence() {
    if (Platform.isMacOS) {
      return;
    }

    DiscordRPC.initialize();
    _rpc = DiscordRPC(applicationId: '931094111694520350');
  }

  final _logger = Logger('discord_rpc');
  late DiscordRPC _rpc;
  DateTime? _started;

  DateTime? get started => _started;

  void start() {
    if (Platform.isMacOS) {
      return;
    }

    _logger.info('Initializing DiscordRPC');
    _rpc.start(autoRegister: true);
  }

  void clearPresence() {
    setRtmPresence(status: 'KYBER');
    _logger.info('Clearing presence');
    _rpc.clearPresence();
    _started = null;
  }

  // TODO: implement for normal game
  void updatePresence() {
    throw UnimplementedError();
  }

  void updatePresenceKyber(CommonState state, Server server) {
    _started ??= DateTime.now();

    final isHosting = state.hasServer();
    final instance = sl.get<MaximaGameInstance>();
    final levelDeclarationService = sl.get<LevelDeclarationService>();
    final tmpCollection = ModCollectionMetaData(
      localId: '',
      title: '',
      mods: instance.mods.map((e) => e.toCollectionMod()).toList(),
    );
    var mode = levelDeclarationService.getModeName(
      mode: server.levelSetup.mode,
      collection: tmpCollection,
    );
    var map = levelDeclarationService
        .getMapByMode(
          map: server.levelSetup.map,
          mode: server.levelSetup.mode,
          collection: tmpCollection,
        )
        ?.name;
    final mapAsset = server.levelSetup.map.replaceAll('/', '-').toLowerCase();

    if (!Preferences.general.discordRPC) {
      return;
    }

    mode ??= MapHelper.getMode(server.levelSetup.mode)?.name;
    mode = _rpcModeNames[mode] ?? mode;

    setRtmPresence(
      status: '$mode (${server.playerCount}/${server.maxPlayerCount})',
    );

    if (map == null) {
      final gMode = MapHelper.getMode(server.levelSetup.mode);

      if (gMode != null) {
        map = MapHelper.getMapName(gMode, server.levelSetup.map);
      }
    }

    _rpc.updatePresence(
      DiscordPresence(
        state: server.name,
        details:
            '${isHosting ? "Hosting" : "Playing"} $mode on $map (${server.playerCount}/${server.maxPlayerCount})',
        startTimeStamp: _started!.millisecondsSinceEpoch,
        largeImageText: 'STAR WARS™ Battlefront™ II',
        largeImageKey: mapAsset,
        smallImageText: 'KYBER',
        smallImageKey: 'kyber_logo',
        button1Label: 'View Server',
        button1Url: 'https://kyber.gg',
        button2Label: 'Join Server',
        button2Url: 'kl://join_server?server_id=${server.id}',
      ),
    );
  }
}
