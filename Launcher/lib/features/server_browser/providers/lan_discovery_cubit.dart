import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/features/server_browser/services/lan_discovery_service.dart';
import 'package:logging/logging.dart';

class LanDiscoveryState {
  const LanDiscoveryState({
    this.servers = const [],
    this.scanning = false,
    this.message,
  });

  final List<LanServer> servers;
  final bool scanning;
  final String? message;

  LanDiscoveryState copyWith({
    List<LanServer>? servers,
    bool? scanning,
    String? message,
  }) {
    return LanDiscoveryState(
      servers: servers ?? this.servers,
      scanning: scanning ?? this.scanning,
      message: message,
    );
  }
}

class LanDiscoveryCubit extends Cubit<LanDiscoveryState> {
  LanDiscoveryCubit(this._service) : super(const LanDiscoveryState()) {
    _subscription = _service.servers.listen(_upsertServer);
    _cleanupTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _removeStaleServers(),
    );
    startScan();
  }

  final LanDiscoveryService _service;
  final _logger = Logger('lan_discovery_cubit');
  late final StreamSubscription<LanServer> _subscription;
  late final Timer _cleanupTimer;
  String? _localPreferredAddress;

  Future<void> startScan() async {
    emit(state.copyWith(scanning: true));
    try {
      await _refreshLocalPreferredAddress();
      await _service.startListening();
      emit(state.copyWith(scanning: false));
    } catch (e, stack) {
      _logger.severe('Failed to start LAN discovery', e, stack);
      emit(
        state.copyWith(
          scanning: false,
          message: 'Failed to start LAN discovery',
        ),
      );
    }
  }

  void refresh() {
    _removeStaleServers();
  }

  Future<void> _refreshLocalPreferredAddress() async {
    _localPreferredAddress =
        await LanDiscoveryService.getPreferredLanAddressFromModule();
  }

  bool _isOnLocalSubnet(String address) {
    final local = _localPreferredAddress;
    if (local == null || local.isEmpty) {
      return false;
    }

    return LanDiscoveryService.sharesClassCSubnet(local, address);
  }

  int _addressClassPriority(String ip) {
    if (ip.startsWith('192.168.')) {
      return 0;
    }

    if (ip.startsWith('10.')) {
      return 1;
    }

    final parts = ip.split('.');
    if (parts.length == 4) {
      final first = int.tryParse(parts[0]);
      final second = int.tryParse(parts[1]);
      if (first == 172 && second != null && second >= 16 && second <= 31) {
        return 2;
      }
    }

    return 3;
  }

  bool _shouldPreferServer(LanServer candidate, LanServer existing) {
    final candidateOnSubnet = _isOnLocalSubnet(candidate.address);
    final existingOnSubnet = _isOnLocalSubnet(existing.address);
    if (candidateOnSubnet != existingOnSubnet) {
      return candidateOnSubnet;
    }

    final candidatePriority = _addressClassPriority(candidate.address);
    final existingPriority = _addressClassPriority(existing.address);
    if (candidatePriority != existingPriority) {
      return candidatePriority < existingPriority;
    }

    return candidate.lastSeen.isAfter(existing.lastSeen);
  }

  void _upsertServer(LanServer server) {
    final servers = [...state.servers];
    LanServer? existingByName;
    for (final entry in servers) {
      if (entry.port == server.port && entry.name == server.name) {
        existingByName = entry;
        break;
      }
    }

    servers.removeWhere(
      (entry) => entry.port == server.port && entry.name == server.name,
    );

    final resolved = existingByName == null
        ? server
        : (_shouldPreferServer(server, existingByName) ? server : existingByName)
            .copyWith(lastSeen: server.lastSeen);
    servers.add(resolved);

    servers.sort((a, b) => a.name.compareTo(b.name));
    emit(state.copyWith(servers: servers, message: null));
  }

  void _removeStaleServers() {
    unawaited(_refreshLocalPreferredAddress());

    final now = DateTime.now();
    final servers = state.servers
        .where(
          (server) => now.difference(server.lastSeen) < LanDiscoveryService.staleAfter,
        )
        .toList();
    if (servers.length != state.servers.length) {
      emit(state.copyWith(servers: servers));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    _cleanupTimer.cancel();
    return super.close();
  }
}
