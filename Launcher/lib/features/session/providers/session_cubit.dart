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
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/settings/dialogs/update_dialog.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
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

  Timer? _keepAliveTimer;
  IOWebSocketChannel? _channel;
  int _reconnectAttempts = 0;

  InParty? get _inParty => state is InParty ? state as InParty : null;

  String? get _userId =>
      navigatorKey.currentContext?.read<MaximaCubit>().state.servicePlayer?.id;

  @override
  Future<void> close() async {
    _keepAliveTimer?.cancel();
    await _channel?.sink.close();
    return super.close();
  }

  Future<void> inviteToParty(String userId) {
    return _service.partyServiceClient.invitePlayer(.new(userId: userId));
  }

  Future<void> acceptInvite(Int64 partyId) async {
    await _service.partyServiceClient.acceptInvite(.new(partyId: partyId));

    final response = await _service.partyServiceClient.getParty(.new());
    if (isClosed) return;

    if (response.hasParty()) {
      emit(InParty(response.party));
      _sortPlayers();
    } else {
      emit(PartyInitial());
    }
  }

  Future<void> clearInvite() async {
    if (state is PartyInitial) {
      emit(PartyInitial());
    } else if (state is InParty) {
      final current = state as InParty;
      emit(InParty(current.party));
    }
  }

  Future<void> declineInvite(Int64 partyId) async {
    try {
      await _service.partyServiceClient.declineInvite(.new(partyId: partyId));
    } finally {
      if (state is PartyInitial) {
        emit(PartyInitial());
      } else if (state is InParty) {
        final current = state as InParty;
        emit(InParty(current.party));
      }
    }
  }

  Future<void> leaveParty() async {
    try {
      await _service.partyServiceClient.leaveParty(.new());
    } finally {
      emit(PartyInitial());
    }
  }

  void _handlePartyUpdate(List<PartyMember> members) {
    final party = _inParty?.party;
    if (party == null) return;

    final unique = <String, PartyMember>{
      for (final m in members) m.player.id: m,
    }.values.toList();

    emit(
      InParty(
        PartyState(
          id: party.id,
          leaderId: party.leaderId,
          createdAt: party.createdAt,
          members: unique,
        ),
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
        PartyState(
          id: party.id,
          leaderId: party.leaderId,
          createdAt: party.createdAt,
          members: sorted,
        ),
      ),
    );
  }

  Future<void> _connectToStream() async {
    final userId = _userId;
    if (userId == null) {
      _logger.warning('User ID is null, cannot subscribe to session stream');
      return;
    }

    _keepAliveTimer?.cancel();
    await _channel?.sink.close();

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
          final _ = switch (data.whichBody()) {
            .partyEvent => _handlePartyEvent(data.partyEvent),
            .checkForUpdates => _handleUpdateCheck(),
            .notSet => null,
          };
        } catch (e, s) {
          _logger.severe('Error parsing session event', e, s);
        }
      },
      onDone: () {
        _logger.info('Session stream done');
        _reconnect();
      },
      onError: (dynamic e, StackTrace s) {
        _logger.severe('Session stream error', e, s);
        _reconnect();
      },
    );

    _keepAliveTimer = Timer.periodic(
      const .new(seconds: 10),
      (_) async => _channel?.sink.add(''),
    );

    _reconnectAttempts = 0;
  }

  void _reconnect() {
    if (isClosed) return;

    _keepAliveTimer?.cancel();

    final delay = Duration(seconds: math.min(2 << _reconnectAttempts, 30));
    _reconnectAttempts++;
    _logger.info(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );
    Future.delayed(delay, _connectToStream);
  }

  void _handleUpdateCheck() async {
    final update = await ModuleVersionService().updateAvailable(
      module: .installer,
    );
    final context = navigatorKey.currentContext;

    if (context == null) {
      _logger.warning('Context is null, cannot show update dialog');
      return;
    }

    if (update && context.mounted) {
      await showKyberDialog(
        context: context,
        builder: (_) => const UpdateDialog(),
      );
    }
  }

  void _handlePartyEvent(PartyEvent event) async {
    final userId = _userId;

    if (event.hasInviteReceived()) {
      final invite = event.inviteReceived;
      _logger.info(
        'Received party invite from ${invite.inviter.name} (${invite.inviter.id})',
      );

      final maximaState = navigatorKey.currentContext
          ?.read<MaximaRtmCubit>()
          .state;
      final isFriend =
          maximaState?.friends.any((f) => f.id == invite.inviter.id) ?? false;
      if (!isFriend) {
        _logger.warning(
          'Inviter ${invite.inviter.name} (${invite.inviter.id}) is not in friends list, ignoring invite',
        );
        return;
      }

      final pending = PendingInvite(
        partyId: Int64(invite.partyId.toInt()),
        inviter: invite.inviter,
        inviteToken: invite.inviteToken,
        expiresAt: invite.expiresAt,
      );

      if (state is InParty) {
        final current = state as InParty;
        emit(InParty(current.party, pendingInvite: pending));
      } else {
        emit(PartyInitial(pendingInvite: pending));
      }
      return;
    }

    if (_inParty == null) {
      final party = await _service.partyServiceClient.getParty(.new());
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

      NotificationService.info(
        message: '${event.memberJoined.user.name} joined the party',
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

      final leftMember = party.members.firstWhereOrNull(
        (m) => m.player.id == event.memberLeft.userId,
      );

      NotificationService.warning(
        message:
            '${leftMember?.player.name ?? event.memberLeft.userId} left the party',
      );

      final updatedMembers = party.members.whereNot(
        (e) => e.player.id == event.memberLeft.userId,
      );

      if (updatedMembers.length <= 1) {
        _logger.info('Party has 1 or fewer members, leaving party');
        emit(PartyInitial());
        return;
      }

      _handlePartyUpdate([
        ...party.members.whereNot(
          (e) => e.player.id == event.memberLeft.userId,
        ),
      ]);
    } else if (event.hasJoinGame()) {
      _logger.info(
        'Join game event: server=${event.joinGame.serverId} name=${event.joinGame.serverName}',
      );
    }
  }
}
