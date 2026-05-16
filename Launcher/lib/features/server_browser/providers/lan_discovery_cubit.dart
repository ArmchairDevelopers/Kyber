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

  Future<void> startScan() async {
    emit(state.copyWith(scanning: true));
    try {
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

  void _upsertServer(LanServer server) {
    final servers = [...state.servers];
    final index = servers.indexWhere((entry) => entry.id == server.id);
    if (index == -1) {
      servers.add(server);
    } else {
      servers[index] = server;
    }

    servers.sort((a, b) => a.name.compareTo(b.name));
    emit(state.copyWith(servers: servers, message: null));
  }

  void _removeStaleServers() {
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
