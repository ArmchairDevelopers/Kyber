import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:kyber/gen/Proto/kyber_common.pb.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/injection_container.dart';

class LanDiscoveryService {
  static const int gamePort = 25200;
  static const int discoveryPort = 25201;
  static const Duration staleAfter = Duration(seconds: 30);

  /// Four-byte prefix before the UTF-8 JSON body on discovery port UDP packets.
  static const List<int> lanBeaconMagic = [0x4B, 0x59, 0x42, 0x52]; // "KYBR"

  final _controller = StreamController<LanServer>.broadcast();
  RawDatagramSocket? _listener;

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
        if (!_hasLanBeaconMagic(datagram.data)) {
          return;
        }

        final payload = utf8.decode(
          datagram.data.sublist(lanBeaconMagic.length),
        );
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

  Future<void> dispose() async {
    await _controller.close();
    _listener?.close();
    _listener = null;
  }

  static bool sharesClassCSubnet(String left, String right) {
    final leftParts = left.split('.');
    final rightParts = right.split('.');
    if (leftParts.length != 4 || rightParts.length != 4) {
      return false;
    }

    return leftParts[0] == rightParts[0] &&
        leftParts[1] == rightParts[1] &&
        leftParts[2] == rightParts[2];
  }

  static Future<String?> getPreferredLanAddressFromModule() async {
    if (!sl.isRegistered<MaximaGameInstance>()) {
      return null;
    }

    try {
      final state = await sl
          .get<MaximaGameInstance>()
          .clientService
          .commonClient
          .getInfo(Empty());
      if (state.preferredLanAddress.isEmpty) {
        return null;
      }

      return state.preferredLanAddress;
    } on GrpcError {
      return null;
    }
  }

  static Future<String> getLanAddress() async {
    final address = await getPreferredLanAddressFromModule();
    return address ?? InternetAddress.loopbackIPv4.address;
  }

  static bool _hasLanBeaconMagic(List<int> data) {
    if (data.length < lanBeaconMagic.length) {
      return false;
    }

    for (var index = 0; index < lanBeaconMagic.length; index++) {
      if (data[index] != lanBeaconMagic[index]) {
        return false;
      }
    }

    return true;
  }
}
