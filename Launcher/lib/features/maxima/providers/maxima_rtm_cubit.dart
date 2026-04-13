import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:logging/logging.dart';

class MaximaRtmCubit extends Cubit<MaximaRtmState> {
  MaximaRtmCubit() : super(MaximaRtmState(presences: {}, friends: [])) {
    fetchFriends();
  }

  final _logger = Logger('maxima_rtm');
  StreamSubscription<RtmPresence>? _rtmPresenceSubscription;

  Future<void> fetchFriends() async {
    final friends = await getFriendList();
    _logger.info('Fetched ${friends.length} friends');
    emit(state.copyWith(friends: friends));
  }

  bool isRtmConnected() => _rtmPresenceSubscription != null;

  void startPresenceStream() {
    if (_rtmPresenceSubscription != null) {
      _logger.info('Cancelling existing presence stream');
      _rtmPresenceSubscription!.cancel();
    }

    _logger.info('Starting presence stream');
    _rtmPresenceSubscription = getRtmPresences().listen((event) {
      final newPresences = Map<String, RtmPresence>.from(state.presences);
      newPresences[event.playerId] = event;
      emit(state.copyWith(presences: newPresences));
    });
  }

  void stopPresenceStream() {
    _rtmPresenceSubscription?.cancel();
  }
}

class MaximaRtmState {
  MaximaRtmState({
    required this.presences,
    required this.friends,
  });

  Map<String, RtmPresence> presences;
  List<ServicePlayer> friends;

  MaximaRtmState copyWith({
    Map<String, RtmPresence>? presences,
    List<ServicePlayer>? friends,
  }) {
    return MaximaRtmState(
      presences: presences ?? this.presences,
      friends: friends ?? this.friends,
    );
  }

  List<ServicePlayer> getOnlinePlayers() {
    final players = List<ServicePlayer>.from(friends)
      ..removeWhere((element) {
        final presence = presences[element.id];
        return presence == null || presence.basic == .offline;
      });

    return players;
  }

  List<ServicePlayer> getSortedPlayers({PartyState? partyState}) {
    final players = List<ServicePlayer>.from(friends)
      ..sort((a, b) {
        final presenceA = presences[a.id];
        final presenceB = presences[b.id];
        if ((presenceA != null && presenceA.basic != .offline) &&
            (presenceB == null || presenceB.basic == .offline)) {
          return -1;
        } else if ((presenceA == null || presenceA.basic == .offline) &&
            (presenceB != null && presenceB.basic != .offline)) {
          return 1;
        } else if (presenceA != null && presenceB != null) {
          if (presenceA.status.isEmpty && presenceB.status.isNotEmpty) {
            return 1;
          } else if (presenceA.status.isNotEmpty && presenceB.status.isEmpty) {
            return -1;
          } else if (presenceA.status.isEmpty && presenceB.status.isEmpty) {
            return 0;
          } else {
            return a.displayName.compareTo(b.displayName);
          }
        } else {
          return a.displayName.compareTo(b.displayName);
        }
      });

    if (partyState != null) {
      players.removeWhere(
        (element) => partyState.members.any((p) => p.player.id == element.id),
      );
    }

    return players;
  }
}
