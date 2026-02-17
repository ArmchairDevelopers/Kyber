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
  InParty(this.party, {this.pendingInvite});

  final PartyState party;
  final PendingInvite? pendingInvite;

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

  @override
  List<Object?> get props => [party, pendingInvite];
}

class PendingInvite extends Equatable {
  const PendingInvite({
    required this.partyId,
    required this.inviter,
    required this.inviteToken,
    required this.expiresAt,
  });

  final Int64 partyId;
  final KyberPlayer inviter;
  final String inviteToken;
  final Int64 expiresAt;

  @override
  List<Object?> get props => [partyId, inviter, inviteToken, expiresAt];
}
