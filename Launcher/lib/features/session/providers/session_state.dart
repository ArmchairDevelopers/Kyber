part of 'session_cubit.dart';

@immutable
sealed class SessionState extends Equatable {}

final class PartyInitial extends SessionState {
  PartyInitial({this.pendingInvite});

  final PendingInvite? pendingInvite;

  @override
  List<Object?> get props => [pendingInvite];
}

final class InParty extends SessionState {
  InParty(this.party, {this.pendingInvite, this.joinGameInfo});

  final PartyState party;
  final PendingInvite? pendingInvite;
  final JoinGameInfo? joinGameInfo;

  List<KyberPlayer> get members => party.members
      .where(
        (m) =>
            m.player.id !=
            navigatorKey.currentContext
                ?.read<MaximaCubit>()
                .state
                .servicePlayer
                ?.id,
      )
      .map((m) => m.player)
      .toList();

  bool isLeader() {
    final userId = navigatorKey.currentContext
        ?.read<MaximaCubit>()
        .state
        .servicePlayer
        ?.id;

    return party.leaderId == userId;
  }

  InParty copyWith({
    PartyState? party,
    PendingInvite? pendingInvite,
    JoinGameInfo? joinGameInfo,
  }) {
    return InParty(
      party ?? this.party,
      pendingInvite: pendingInvite ?? this.pendingInvite,
      joinGameInfo: joinGameInfo ?? this.joinGameInfo,
    );
  }

  @override
  List<Object?> get props => [party, pendingInvite, joinGameInfo];
}

class JoinGameMemberStatusInfo extends Equatable {
  const JoinGameMemberStatusInfo({
    required this.hasMods,
    this.modDownloadPercentage,
    this.joined = false,
  });

  final bool hasMods;
  final int? modDownloadPercentage;
  final bool joined;

  @override
  List<Object?> get props => [hasMods, modDownloadPercentage];
}

class JoinGameInfo extends Equatable {
  const JoinGameInfo({
    required this.serverId,
    required this.serverName,
    required this.mods,
    required this.leaderId,
    this.password = '',
    this.memberStatuses = const {},
  });

  final String serverId;
  final String serverName;
  final List<ServerMod> mods;
  final String leaderId;
  final String password;
  final Map<String, JoinGameMemberStatusInfo> memberStatuses;

  JoinGameInfo copyWith({
    String? serverId,
    String? serverName,
    List<ServerMod>? mods,
    String? leaderId,
    String? password,
    Map<String, JoinGameMemberStatusInfo>? memberStatuses,
  }) {
    return JoinGameInfo(
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      mods: mods ?? this.mods,
      leaderId: leaderId ?? this.leaderId,
      password: password ?? this.password,
      memberStatuses: memberStatuses ?? this.memberStatuses,
    );
  }

  @override
  List<Object?> get props => [
        serverId,
        serverName,
        mods,
        leaderId,
        password,
        memberStatuses,
      ];
}

class PendingInvite extends Equatable {
  const PendingInvite({
    required this.partyId,
    required this.inviter,
    required this.inviteToken,
    required this.expiresAt,
    required this.size,
  });

  final Int64 partyId;
  final KyberPlayer inviter;
  final String inviteToken;
  final Int64 expiresAt;
  final int size;

  @override
  List<Object?> get props => [partyId, inviter, inviteToken, expiresAt, size];
}
