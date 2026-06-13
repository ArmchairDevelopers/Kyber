part of 'session_cubit.dart';

@immutable
sealed class SessionState extends Equatable {}

final class PartyInitial extends SessionState {
  PartyInitial({this.pendingInvite, this.queueInfo});

  final PendingInvite? pendingInvite;
  final QueueInfo? queueInfo;

  @override
  List<Object?> get props => [pendingInvite, queueInfo];
}

final class InParty extends SessionState {
  InParty(this.party, {this.pendingInvite, this.joinGameInfo, this.queueInfo});

  final PartyState party;
  final PendingInvite? pendingInvite;
  final JoinGameInfo? joinGameInfo;
  final QueueInfo? queueInfo;

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
    QueueInfo? queueInfo,
  }) {
    return InParty(
      party ?? this.party,
      pendingInvite: pendingInvite ?? this.pendingInvite,
      joinGameInfo: joinGameInfo ?? this.joinGameInfo,
      queueInfo: queueInfo ?? this.queueInfo,
    );
  }

  @override
  List<Object?> get props => [party, pendingInvite, joinGameInfo, queueInfo];
}

class QueueInfo extends Equatable {
  const QueueInfo({
    required this.serverId,
    required this.state,
    this.serverName = '',
    this.position = 0,
    this.queueSize = 0,
    this.password = '',
  });

  final String serverId;
  final QueueEntryState state;
  final String serverName;
  final int position;
  final int queueSize;
  final String password;

  bool get isReserved => state == QueueEntryState.QUEUE_STATE_RESERVED;

  QueueInfo copyWith({
    String? serverId,
    QueueEntryState? state,
    String? serverName,
    int? position,
    int? queueSize,
    String? password,
  }) {
    return QueueInfo(
      serverId: serverId ?? this.serverId,
      state: state ?? this.state,
      serverName: serverName ?? this.serverName,
      position: position ?? this.position,
      queueSize: queueSize ?? this.queueSize,
      password: password ?? this.password,
    );
  }

  @override
  List<Object?> get props => [
    serverId,
    state,
    serverName,
    position,
    queueSize,
    password,
  ];
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
  List<Object?> get props => [hasMods, modDownloadPercentage, joined];
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
