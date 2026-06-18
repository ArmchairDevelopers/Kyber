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

// api should return this at some point
const Map<List<String>, ServerRegion> regionMappings = {
  ['de-nuremberg']: .eu,
  ['us-ashburn']: .na,
};

class ServerGroup {
  ServerGroup({
    required this.servers,
    required this.groupName,
  });

  final List<Server> servers;
  final String groupName;

  Server getPreferredServer() {
    final s = List.of(servers)
      ..removeWhere((e) => e.playerCount >= e.maxPlayerCount)
      ..sort((a, b) => b.playerCount.compareTo(a.playerCount));
    return s.firstOrNull ?? servers.first;
  }

  List<Server> getSorted() {
    final s = List.of(servers)
      ..sort(
        (a, b) => (a.meta['instance_id']!).compareTo(b.meta['instance_id']!),
      );
    return s;
  }

  ServerRegion getPreferredRegion() {
    final pinnedProxies = servers.where((e) => e.meta.containsKey('pinned_proxy_id')).map((e) => e.meta['pinned_proxy_id']!).toSet();

    // TODO: use server region instead
    if (pinnedProxies.isEmpty) {
      throw Exception('No pinned proxies found for server group $groupName');
    }

    if (pinnedProxies.length == 1) {
      final proxyId = pinnedProxies.first;
      final region = regionMappings.entries.firstWhereOrNull(
        (entry) => entry.key.contains(proxyId),
      );
      if (region == null) {
        throw Exception('Unknown pinned proxy id: $proxyId');
      }

      return region.value;
    }

    final proxies = navigatorKey.currentContext!.read<KyberProxyCubit>().state.proxies;

    final proxy = proxies.firstWhere((e) => pinnedProxies.contains(e.proxy.id));
    final region = regionMappings.entries.firstWhereOrNull(
      (entry) => entry.key.contains(proxy.proxy.id),
    );

    if (region == null) {
      throw Exception('Unknown pinned proxy id: ${proxy.proxy.id}');
    }

    return region.value;
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
    return servers.first;
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

    return !context.read<MaximaCubit>().state.isEntitledAny([
      .admin,
      .bypassPlayerLimit,
    ]);
  }
}
