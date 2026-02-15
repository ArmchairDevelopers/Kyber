import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/io.dart';

part 'session_state.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(PartyInitial()) {
    _connectToStream();
  }

  final _logger = Logger('session_cubit');
  late final KyberGRPCService _service = sl<KyberGRPCService>();

  StreamSubscription<SessionEvent>? _subscription;
  Timer? _keepAliveTimer;
  IOWebSocketChannel? _channel;
  int _reconnectAttempts = 0;

  InParty? get _inParty => state is InParty ? state as InParty : null;

  String? get _userId =>
      navigatorKey.currentContext?.read<MaximaCubit>().state.servicePlayer?.id;

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _keepAliveTimer?.cancel();
    return super.close();
  }

  Future<void> inviteToParty(String userId) {
    return _service.partyServiceClient.invitePlayer(
      InvitePlayerRequest(userId: userId),
    );
  }

  Future<void> leaveParty() {
    return _service.partyServiceClient.leaveParty(Empty());
  }

  void _handlePartyUpdate(List<PartyMember> members) {
    final party = _inParty?.party;
    if (party == null) return;

    final unique = members
        .toSet()
        .where((m) => m.player.id.isNotEmpty && m.joinedAt > Int64())
        .toList();

    if (unique.length != members.length) {
      _logger.warning(
        'Filtered ${members.length - unique.length} invalid or duplicate members from party update',
      );
    }

    emit(
      InParty(
        party.rebuild((b) {
          b.members
            ..clear()
            ..addAll(unique);
        }),
      ),
    );
    _sortPlayers();
  }

  void _sortPlayers() {
    return;
    final party = _inParty?.party;
    final userId = _userId;
    if (party == null || userId == null) return;

    final sorted = List<PartyMember>.from(party.members)
      ..sort((a, b) {
        if (a.player.id == userId) return -1;
        if (b.player.id == userId) return 1;
        return 0;
      });

    emit(
      InParty(
        party.rebuild((b) {
          b.members
            ..clear()
            ..addAll(sorted);
        }),
      ),
    );
  }

  Future<void> _connectToStream() async {
    final userId = _userId;
    if (userId == null) {
      _logger.warning('User ID is null, cannot subscribe to party stream');
      return;
    }

    await _subscription?.cancel();

    _service.partyServiceClient
        .getParty(.new())
        .then((response) {
          if (isClosed) return;

          if (!response.hasParty()) {
            return;
          }

          _logger.info(
            'Currently in party with ${response.party.members.length} members',
          );
          emit(InParty(response.party));
          _sortPlayers();
        })
        .catchError((error) {
          _logger.warning('Failed to get current party', error);
        });

    _channel = IOWebSocketChannel.connect(
      'wss://api.${Preferences.admin.apiEnv}.kyber.gg/ws/session',
      headers: {
        'Authorization': sl.get<KyberGRPCService>().token,
      },
      connectTimeout: const Duration(seconds: 10),
    );

    await _channel?.ready;

    _channel?.stream.listen(
      (event) {
        try {
          final data = SessionEvent.fromBuffer(event as Uint8List);
        } catch (e, s) {
          _logger.severe('Error parsing event', e, s);
        }
      },
      onDone: () {
        _logger.info('Stream done');
      },
      onError: (dynamic e, StackTrace s) {
        _logger.severe('Stream error', e, s);
      },
    );

    _keepAliveTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) async => _channel?.sink.add(''),
    );

    _reconnectAttempts = 0;
  }

  void _reconnect() {
    if (isClosed) return;

    final delay = Duration(seconds: math.min(2 << _reconnectAttempts, 30));
    _reconnectAttempts++;
    _logger.info(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );
    Future.delayed(delay, _connectToStream);
  }

  Future<void> _handlePartyEvent(PartyEvent event) async {
    final userId = _userId;

    if (event.hasInviteReceived()) {
      _logger.info(
        'Received party invite from ${event.inviteReceived.inviter.name} (${event.inviteReceived.inviter.id})',
      );
      return;
    }

    if (_inParty == null) {
      final party = await _service.partyServiceClient.getParty(Empty());
      if (isClosed) return;

      if (!party.hasParty()) {
        _logger.info('Not currently in a party');
        return;
      }

      _logger.info(
        'Currently in party ${party.party.id} with ${party.party.members.length} members',
      );

      emit(InParty(party.party));
      _sortPlayers();
    }

    final party = _inParty?.party;
    if (party == null) return;

    if (event.hasInviteAccepted()) {
      NotificationService.success(
        message: '${event.inviteAccepted.user.name} accepted the party invite',
      );
    } else if (event.hasInviteDeclined()) {
      NotificationService.warning(
        message: '${event.inviteDeclined.user.name} declined the party invite',
      );
    } else if (event.hasMemberJoined()) {
      if (event.memberJoined.user.id == userId) {
        _logger.info('You have joined the party');
        return;
      }

      _logger.fine('Member joined: ${event.memberJoined}');

      final existingMember = party.members.firstWhereOrNull(
        (m) => m.player.id == event.memberJoined.user.id,
      );
      NotificationService.info(
        message: '${existingMember?.player.name} left the party',
      );

      _handlePartyUpdate([
        ...party.members,
        PartyMember(
          player: event.memberJoined.user,
          joinedAt: Int64(DateTime.now().millisecondsSinceEpoch),
        ),
      ]);
    } else if (event.hasMemberLeft()) {
      if (event.memberLeft.userId == userId) {
        _logger.info('You have left the party');
        emit(PartyInitial());
        return;
      }

      NotificationService.warning(
        message: '${event.memberLeft.userId} left the party',
      );

      _handlePartyUpdate([
        ...party.members.whereNot(
          (e) => e.player.id == event.memberLeft.userId,
        ),
      ]);
    }
  }
}
