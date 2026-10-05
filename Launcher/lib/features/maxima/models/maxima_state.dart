part of '../providers/maxima_cubit.dart';

enum MaximaStatus {
  initial,
  loading,
  loaded,
  error,
  starting,
}

class MaximaState {
  const MaximaState({
    required this.status,
    this.servicePlayer,
    this.kyberToken,
    this.error,
    this.entitlements,
    this.loggedIn = false,
    this.gameRunning = false,
    this.isPatron = false,
    this.discordData,
  });

  factory MaximaState.initial() => const MaximaState(
    status: .initial,
  );

  final String? error;
  final List<UserEntitlement>? entitlements;
  final String? kyberToken;
  final MaximaStatus status;
  final bool loggedIn;
  final bool gameRunning;
  final bool isPatron;
  final DiscordUserData? discordData;
  final ServicePlayer? servicePlayer;

  bool isEntitled(UserEntitlement entitlement) =>
      entitlements?.contains(entitlement) ?? false;

  bool isEntitledMultiple(List<UserEntitlement> entitlements) =>
      entitlements.every(isEntitled);

  bool isEntitledAny(List<UserEntitlement> entitlements) =>
      entitlements.any(isEntitled);

  bool canUsePerks() =>
      isEntitledAny([.globalServerModerator, .staff, .patreonPerks]) ||
      isPatron;

  MaximaState copyWith({
    MaximaStatus? status,
    ServicePlayer? servicePlayer,
    String? kyberToken,
    List<UserEntitlement>? entitlements,
    bool? loggedIn,
    bool? gameRunning = false,
    bool? isPatron,
    DiscordUserData? discordData,
  }) => MaximaState(
    entitlements: entitlements ?? this.entitlements,
    kyberToken: kyberToken ?? this.kyberToken,
    status: status ?? this.status,
    servicePlayer: servicePlayer ?? this.servicePlayer,
    loggedIn: loggedIn ?? this.loggedIn,
    gameRunning: gameRunning ?? this.gameRunning,
    isPatron: isPatron ?? this.isPatron,
    discordData: discordData ?? this.discordData,
  );
}

enum UserEntitlement {
  admin,
  globalServerModerator,
  officialServerModerator,
  staff,
  dockerPush,
  officialServers,
  verifiedServers,
  officialStats,
  patreonPerks,
  bypassPlayerLimit,
}

UserEntitlement? parseUserEntitlement(String value) {
  switch (value) {
    case 'ADMIN':
      return .admin;
    case 'GLOBAL_SERVER_MODERATOR':
      return .globalServerModerator;
    case 'OFFICIAL_SERVER_MODERATOR':
      return .officialServerModerator;
    case 'DOCKER_PUSH':
      return .dockerPush;
    case 'OFFICIAL_SERVERS':
      return .officialServers;
    case 'VERIFIED_SERVERS':
      return .verifiedServers;
    case 'OFFICIAL_STATS':
      return .officialStats;
    case 'PATREON_PERKS':
      return .patreonPerks;
    case 'STAFF':
      return .staff;
    case 'BYPASS_PLAYER_LIMIT':
      return .bypassPlayerLimit;
    default:
      return null;
  }
}
