part of 'session_cubit.dart';

@immutable
sealed class SessionState extends Equatable {}

final class PartyInitial extends SessionState {
  @override
  List<Object?> get props => [];
}

final class InParty extends SessionState {
  InParty(this.party);

  final PartyState party;

  @override
  List<Object?> get props => [party];
}
