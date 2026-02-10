part of 'party_cubit.dart';

@immutable
sealed class UserPartyState extends Equatable {}

final class PartyInitial extends UserPartyState {
  @override
  List<Object?> get props => [];
}

final class InParty extends UserPartyState {
  InParty(this.party);

  final PartyState party;

  @override
  List<Object?> get props => [party];
}
