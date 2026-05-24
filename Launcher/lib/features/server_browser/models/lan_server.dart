import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server_mod.dart';

class LanServer {
  const LanServer({
    required this.name,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.maxPlayers,
    this.requiresPassword = false,
    this.gameplayMods = const [],
    this.levelSetup,
  });

  factory LanServer.fromJson(
    Map<String, dynamic> json, {
    required String sourceAddress,
  }) {
    return LanServer(
      name: json['name'] as String? ?? 'LAN Server',
      address: sourceAddress,
      port: json['port'] as int? ?? 25200,
      maxPlayers: json['maxPlayers'] as int?,
      requiresPassword: json['requiresPassword'] as bool? ?? false,
      gameplayMods: _parseGameplayMods(json['mods']),
      levelSetup: json['levelSetup'] is Map<String, dynamic>
          ? LevelSetup(
              map: (json['levelSetup'] as Map<String, dynamic>)['map']
                      as String? ??
                  '',
              mode: (json['levelSetup'] as Map<String, dynamic>)['mode']
                      as String? ??
                  '',
              mapName: (json['levelSetup'] as Map<String, dynamic>)['mapName']
                      as String? ??
                  '',
              modeName: (json['levelSetup'] as Map<String, dynamic>)['modeName']
                      as String? ??
                  '',
            )
          : null,
      lastSeen: DateTime.now(),
    );
  }

  final String name;
  final String address;
  final int port;
  final int? maxPlayers;
  final bool requiresPassword;
  final List<LanServerMod> gameplayMods;
  final LevelSetup? levelSetup;
  final DateTime lastSeen;

  String get id => '$address:$port';

  List<ServerMod> get serverMods => gameplayMods
      .map((mod) => ServerMod(name: mod.name, version: mod.version))
      .toList();

  LanServer copyWith({
    String? name,
    String? address,
    int? port,
    int? maxPlayers,
    bool? requiresPassword,
    List<LanServerMod>? gameplayMods,
    LevelSetup? levelSetup,
    DateTime? lastSeen,
  }) {
    return LanServer(
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      requiresPassword: requiresPassword ?? this.requiresPassword,
      gameplayMods: gameplayMods ?? this.gameplayMods,
      levelSetup: levelSetup ?? this.levelSetup,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  static List<LanServerMod> _parseGameplayMods(dynamic raw) {
    if (raw is! List<dynamic>) {
      return const [];
    }

    return raw
        .map(LanServerMod.parseEntry)
        .where((mod) => mod.name.isNotEmpty && mod.version.isNotEmpty)
        .toList();
  }
}
