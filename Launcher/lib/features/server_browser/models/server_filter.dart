import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';

enum ServerType {
  all,
  official,
  custom,
  private,
  event,
}

enum ServerRegion {
  all,
  na,
  sa,
  eu,
  as,
  oc,
  af,
}

extension ServerTypeExtension on ServerRegion {
  String get displayName {
    switch (this) {
      case .all:
        return 'All Regions';
      case .na:
        return 'North America';
      case .sa:
        return 'South America';
      case .eu:
        return 'Europe';
      case .as:
        return 'Asia';
      case .oc:
        return 'Oceania';
      case .af:
        return 'Africa';
    }
  }
}

enum GameType {
  all,
  modded,
  vanilla,
}

enum ServerGroupType {
  crossRegion,
  persisted,
}

class ServerGroup {
  ServerGroup({
    required this.servers,
    required this.groupName,
    required this.groupType,
    required this.groupKey,
  });

  final List<Server> servers;
  final String groupName;
  final ServerGroupType groupType;
  final String groupKey;

  Server getPreferredServer() {
    final s = List.of(servers)
      ..sort((a, b) {
        final aIsFull = a.playerCount >= a.maxPlayerCount;
        final bIsFull = b.playerCount >= b.maxPlayerCount;

        if (aIsFull && !bIsFull) {
          return 1;
        } else if (!aIsFull && bIsFull) {
          return -1;
        }

        return b.playerCount.compareTo(a.playerCount);
      });

    return s.first;
  }

  List<Server> getSorted() {
    final s = List.of(servers)
      ..sort(
        (a, b) => (a.meta['instance_id'] ?? a.id)
            .compareTo(b.meta['instance_id'] ?? b.id),
      );
    return s;
  }

  Map<String, ServerRegion> get regionProxyMappings {
    final mappings = <String, ServerRegion>{};

    for (final server in servers) {
      if (server.region.isEmpty) continue;

      final region = ServerRegion.values.firstWhereOrNull(
        (r) => r.name == server.region.toLowerCase(),
      );
      if (region == null || region == ServerRegion.all) continue;

      final proxyId = server.meta['pinned_proxy_id'];
      if (proxyId == null) continue;

      mappings[proxyId] = region;
    }

    return mappings;
  }

  Set<ServerRegion> get regions {
    return servers
        .where((e) => e.region.isNotEmpty)
        .map(
          (e) => ServerRegion.values.firstWhereOrNull(
            (r) => r.name == e.region.toLowerCase(),
          ),
        )
        .whereType<ServerRegion>()
        .where((r) => r != ServerRegion.all)
        .toSet();
  }

  ServerRegion getPreferredRegion() {
    final pinnedProxies = servers
        .where((e) => e.meta.containsKey('pinned_proxy_id'))
        .map((e) => e.meta['pinned_proxy_id']!)
        .toSet();

    final proxies = navigatorKey.currentContext!
        .read<KyberProxyCubit>()
        .state
        .proxies;

    // TODO: use server region instead
    if (pinnedProxies.isEmpty) {
      throw Exception('No pinned proxies found for server group $groupName');
    }

    if (pinnedProxies.length == 1) {
      final proxyId = pinnedProxies.first;
      final proxy = proxies.firstWhereOrNull((e) => e.proxy.id == proxyId);
      if (proxy == null) {
        throw Exception('Unknown pinned proxy id: $proxyId');
      }

      return ServerRegion.values.byName(proxy.proxy.region);
    }

    final proxy = proxies.firstWhere((e) => pinnedProxies.contains(e.proxy.id));
    return ServerRegion.values.byName(proxy.proxy.region);
  }

  List<Server> getForRegion(ServerRegion region) {
    final s = List.of(servers);
    if (region == ServerRegion.all) {
      return s;
    }

    s.removeWhere((e) => e.region.toLowerCase() != region.name);

    return s;
  }

  bool isMultiRegion() {
    final regions = servers.map((e) => e.region).toSet();
    return regions.length > 1;
  }

  int getInstanceId(String serverId) {
    return getSorted().indexWhere((e) => e.id == serverId) + 1;
  }

  int get totalPlayerCount {
    return servers.fold<int>(0, (previousValue, element) => previousValue + element.playerCount);
  }

  Server get serverInfo {
    return getPreferredServer();
  }
}

class ServerFilter {
  ServerFilter({
    this.modes = const [],
    this.region = .all,
    this.type = .all,
    this.gameType = .all,
    this.query,
  });

  String? query;
  ServerRegion region = .all;
  ServerType type = .all;
  GameType gameType = .all;
  List<String> modes;

  ServerFilter copyWith({
    String? query,
    ServerRegion? region,
    ServerType? type,
    GameType? gameType,
    List<String>? modes,
  }) {
    return ServerFilter(
      query: query ?? this.query,
      region: region ?? this.region,
      type: type ?? this.type,
      gameType: gameType ?? this.gameType,
      modes: modes ?? this.modes,
    );
  }
}

extension ServerBrowserExtension on Server {
  bool isFull([BuildContext? context]) {
    if (playerCount < maxPlayerCount) return false;

    if (context == null) return true;

    return !context.read<MaximaCubit>().state.isEntitled(.admin);
  }
}
