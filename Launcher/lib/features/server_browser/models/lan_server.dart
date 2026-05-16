import 'package:kyber/kyber.dart';

class LanServer {
  const LanServer({
    required this.name,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.maxPlayers,
    this.requiresPassword = false,
    this.mods = const [],
    this.levelSetup,
  });

  factory LanServer.fromJson(
    Map<String, dynamic> json, {
    required String sourceAddress,
  }) {
    return LanServer(
      name: json['name'] as String? ?? 'LAN Server',
      address: json['ip'] as String? ?? sourceAddress,
      port: json['port'] as int? ?? 25200,
      maxPlayers: json['maxPlayers'] as int?,
      requiresPassword: json['requiresPassword'] as bool? ?? false,
      mods: (json['mods'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
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
  final List<String> mods;
  final LevelSetup? levelSetup;
  final DateTime lastSeen;

  String get id => '$address:$port';

  LanServer copyWith({
    String? name,
    String? address,
    int? port,
    int? maxPlayers,
    bool? requiresPassword,
    List<String>? mods,
    LevelSetup? levelSetup,
    DateTime? lastSeen,
  }) {
    return LanServer(
      name: name ?? this.name,
      address: address ?? this.address,
      port: port ?? this.port,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      requiresPassword: requiresPassword ?? this.requiresPassword,
      mods: mods ?? this.mods,
      levelSetup: levelSetup ?? this.levelSetup,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
