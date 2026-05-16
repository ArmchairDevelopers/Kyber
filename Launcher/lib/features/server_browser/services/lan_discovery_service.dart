import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';

class LanDiscoveryService {
  static const int gamePort = 25200;
  static const int discoveryPort = 25201;
  static const Duration beaconInterval = Duration(seconds: 3);
  static const Duration staleAfter = Duration(seconds: 30);

  final _controller = StreamController<LanServer>.broadcast();
  RawDatagramSocket? _listener;
  RawDatagramSocket? _beaconSocket;
  Timer? _beaconTimer;

  Stream<LanServer> get servers => _controller.stream;

  Future<void> startListening() async {
    if (_listener != null) {
      return;
    }

    _listener = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    _listener!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }

      final datagram = _listener!.receive();
      if (datagram == null) {
        return;
      }

      try {
        final payload = utf8.decode(datagram.data);
        final json = jsonDecode(payload) as Map<String, dynamic>;
        if (json['type'] != 'kyber_lan_server') {
          return;
        }

        _controller.add(
          LanServer.fromJson(json, sourceAddress: datagram.address.address),
        );
      } catch (_) {
        // Ignore unrelated UDP traffic on the discovery port.
      }
    });
  }

  Future<void> startBeacon({
    required String name,
    required int port,
    required int maxPlayers,
    required bool requiresPassword,
    required List<LevelSetup> mapRotation,
    ModCollectionMetaData? collection,
  }) async {
    await stopBeacon();

    final address = await getLanAddress();
    final mods = collection
            ?.getLocalMods(onlyGameplay: true, expandCollections: true)
            .whereType<FrostyMod>()
            .map((mod) => '${mod.details.name} (${mod.details.version})')
            .toList() ??
        const <String>[];

    final payload = utf8.encode(
      jsonEncode({
        'type': 'kyber_lan_server',
        'name': name,
        'ip': address,
        'port': port,
        'maxPlayers': maxPlayers,
        'requiresPassword': requiresPassword,
        'mods': mods,
        if (mapRotation.isNotEmpty)
          'levelSetup': {
            'map': mapRotation.first.map,
            'mode': mapRotation.first.mode,
            'mapName': mapRotation.first.mapName,
            'modeName': mapRotation.first.modeName,
          },
      }),
    );

    _beaconSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _beaconSocket!.broadcastEnabled = true;

    void sendBeacon() {
      _beaconSocket?.send(
        payload,
        InternetAddress('255.255.255.255'),
        discoveryPort,
      );
    }

    sendBeacon();
    _beaconTimer = Timer.periodic(beaconInterval, (_) => sendBeacon());
  }

  Future<void> stopBeacon() async {
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _beaconSocket?.close();
    _beaconSocket = null;
  }

  Future<void> dispose() async {
    await stopBeacon();
    await _controller.close();
    _listener?.close();
    _listener = null;
  }

  static Future<String> getLanAddress() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !address.address.startsWith('169.254.')) {
          return address.address;
        }
      }
    }

    return InternetAddress.loopbackIPv4.address;
  }
}
