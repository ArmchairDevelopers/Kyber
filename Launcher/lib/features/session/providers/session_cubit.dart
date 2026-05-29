import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/gen/Proto/mod_bridge.pb.dart' as mb;
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/download_manager/models/download_link_type.dart'
    as dl;
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/repositories/download_repository.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/features/download_manager/services/mod_bridge_service.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_server_helper.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/nexusmods/exceptions/missing_nexus_auth_exception.dart';
import 'package:kyber_launcher/features/nexusmods/services/mod_finder_service.dart';
import 'package:kyber_launcher/features/session/dialogs/join_game_dialog.dart';
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
  IOWebSocketChannel? _channel;
  Timer? _keepAliveTimer;
  Timer? _partyDownloadChecker;
  bool gameJoined = false;
  int _reconnectAttempts = 0;

  InParty? get _inParty => state is InParty ? state as InParty : null;

  String? get _userId =>
      navigatorKey.currentContext?.read<MaximaCubit>().state.servicePlayer?.id;

  @override
  Future<void> close() async {
    _keepAliveTimer?.cancel();
    _partyDownloadChecker?.cancel();
    await _channel?.sink.close();
    return super.close();
  }

  Future<void> inviteToParty(String userId) {
    return _service.partyServiceClient.invitePlayer(.new(userId: userId));
  }

  Future<void> kickFromParty(String userId) {
    return _service.partyServiceClient.kickMember(.new(userId: userId));
  }

  Future<void> transferLeader(String userId) {
    return _service.partyServiceClient.transferLeader(.new(userId: userId));
  }

  void leaveGame() {
    _channel?.sink.add(
      SessionClientEvent(
        gameLeft: .new(),
      ).writeToBuffer(),
    );
  }

  Future<void> acceptInvite(Int64 partyId) async {
    await _service.partyServiceClient.acceptInvite(.new(partyId: partyId));

    final response = await _service.partyServiceClient.getParty(.new());
    if (isClosed) return;

    if (!response.hasParty()) {
      emit(PartyInitial());
      return;
    }

    JoinGameInfo? joinGameInfo;
    if (response.party.hasJoinGameState()) {
      joinGameInfo = _buildJoinGameInfoFromState(
        response.party.joinGameState,
        response.party.leaderId,
      );
    }

    emit(InParty(response.party, joinGameInfo: joinGameInfo));

    if (joinGameInfo != null) {
      _checkAndReportModStatus(joinGameInfo.mods);
      showJoinGameDialog();
    }
  }

  Future<void> clearInvite() async {
    final inParty = _inParty;
    if (inParty != null) {
      emit(InParty(inParty.party, joinGameInfo: inParty.joinGameInfo));
    } else {
      emit(PartyInitial());
    }
  }

  Future<void> declineInvite(Int64 partyId) async {
    try {
      await _service.partyServiceClient.declineInvite(
        .new(partyId: partyId),
      );
    } finally {
      await clearInvite();
    }
  }

  Future<void> leaveParty() async {
    try {
      gameJoined = false;
      _partyDownloadChecker?.cancel();
      _partyDownloadChecker = null;
      await _service.partyServiceClient.leaveParty(.new());
    } finally {
      emit(PartyInitial());
    }
  }

  Future<void> startJoinGame({
    required String serverId,
    String password = '',
  }) async {
    await _service.partyServiceClient.startJoinGame(
      .new(serverId: serverId, password: password),
    );
  }

  Future<void> onJoined({required String serverId}) async {
    gameJoined = true;
    _channel?.sink.add(
      SessionClientEvent(
        gameJoined: .new(serverId: serverId),
      ).writeToBuffer(),
    );
  }

  Future<void> cancelJoinGame() async {
    await _service.partyServiceClient.cancelJoinGame(.new());
  }

  void readyUp() {
    final info = _inParty?.joinGameInfo;
    if (info == null) return;

    final myStatus = info.memberStatuses[_userId];
    if (myStatus == null || !myStatus.hasMods) return;

    _sendModStatus(hasMods: true);
  }

  Future<void> joinAllReadyPlayers() async {
    _channel?.sink.add(
      SessionClientEvent(joinGameReady: .new()).writeToBuffer(),
    );
  }

  Future<void> joinGameLate() async {
    final info = _inParty?.joinGameInfo;
    if (info == null) return;

    final myStatus = info.memberStatuses[_userId];
    if (!(myStatus?.hasMods ?? false)) {
      NotificationService.warning(message: 'You are missing required mods.');
      return;
    }

    NotificationService.info(message: 'Joining game...');
    await joinServerForParty();
  }

  Future<void> joinServerForParty() async {
    final info = _inParty?.joinGameInfo;
    if (info == null) return;

    final instance = sl.maybeGet<MaximaGameInstance>();
    if (instance != null) {
      final clientMods = instance.gameplayMods
          .map((e) => e.toCollectionMod())
          .toList();

      final mods = info.mods
          .map<CollectionMod>(
            (e) => .new(name: e.name, version: e.version, link: e.link),
          )
          .toList();

      if (!const ListEquality<CollectionMod>().equals(clientMods, mods)) {
        NotificationService.warning(
          message:
              'Game is running with the wrong set of mods. Restarting the game to join the party...',
        );
        Process.killPid(instance.pid);

        const maxTries = 10;
        var stopped = false;
        for (var i = 0; i < maxTries; i++) {
          await Future<void>.delayed(const .new(seconds: 1));
          final instance = sl.maybeGet<MaximaGameInstance>();
          if (instance == null) {
            _logger.fine('Game process has exited, proceeding to join party');
            stopped = true;
            break;
          }
        }

        if (!stopped) {
          _logger.severe('Failed to stop game process after $maxTries seconds');
          NotificationService.error(
            message:
                'Failed to stop the game process. Please close the game and try joining the party again.',
          );
          return;
        }
      }
    }

    final kyberStatus = navigatorKey.currentContext
        ?.read<KyberStatusCubit>()
        .state;
    if (kyberStatus is KyberStatusHosting &&
        kyberStatus.server?.id == info.serverId) {
      gameJoined = true;
      return;
    }

    gameJoined = true;

    if (_partyDownloadChecker != null) {
      NotificationService.info(
        message: 'Waiting for mods to finish downloading...',
      );
      return;
    }

    try {
      final server = await _service.serverBrowserClient.getServer(
        .new(id: info.serverId),
      );
      await KyberServerHelper.joinServer(server, password: info.password);
    } on GrpcError catch (e) {
      _logger.severe('Failed to join server: ${e.message}', e);
      NotificationService.error(
        message: 'Failed to join server: ${e.message}',
      );
    } catch (e) {
      _logger.severe('Failed to join server: $e', e);
      NotificationService.error(message: 'Failed to join server: $e');
    }
  }

  void showJoinGameDialog() {
    final context = navigatorKey.currentContext;
    if (context == null || _inParty?.joinGameInfo == null) return;

    showKyberDialog(
      context: context,
      builder: (_) => const JoinGameDialog(),
    );
  }

  Future<void> startModDownloads() async {
    final info = _inParty?.joinGameInfo;
    if (info == null) return;

    final mods = info.mods;

    const repository = DownloadRepository();
    final currentDownload = await repository.getRunningTask();
    if (currentDownload != null) {
      await sl.get<DownloadOrchestrator>().pauseDownload(
        currentDownload.taskId,
      );
      NotificationService.info(
        message: 'Paused download for ${currentDownload.task.displayName}',
      );
    }

    final missingMods = mods
        .where((mod) => !ModHelper.isInstalled(mod.name, mod.version))
        .toList();

    final searchResult = await _searchForMods(missingMods);

    for (final mod in searchResult.mods) {
      final serverMod = missingMods[int.parse(mod.id)];
      try {
        await _enqueueModDownload(mod, serverMod: serverMod);
      } on MissingNexusAuthException {
        continue;
      } catch (e) {
        _logger.severe('Error downloading ${mod.name}', e);
      }
    }

    if (searchResult.failedCount > 0) {
      final count = searchResult.failedCount;
      NotificationService.showNotification(
        message:
            'For $count ${count > 1 ? "mods" : "mod"} no download could be found.',
      );
    }

    _startDownloadProgressTracker(mods);
  }

  Future<void> _connectToStream() async {
    final userId = _userId;
    if (userId == null) {
      _logger.warning('User ID is null, cannot connect to session');
      return;
    }

    _keepAliveTimer?.cancel();
    await _channel?.sink.close();

    if (!sl.isReadySync<ModService>()) {
      _logger.warning(
        'ModService not ready, waiting before connecting to session stream',
      );
      await sl.isReady<ModService>();
    }

    _service.partyServiceClient
        .getParty(.new())
        .then((response) {
          if (isClosed || !response.hasParty()) return;

          _logger.info(
            'Currently in party with ${response.party.members.length} members',
          );

          JoinGameInfo? joinGameInfo;
          if (response.party.hasJoinGameState()) {
            joinGameInfo = _buildJoinGameInfoFromState(
              response.party.joinGameState,
              response.party.leaderId,
            );
          }

          _emitInParty(response.party, joinGameInfo: joinGameInfo);

          if (joinGameInfo != null) {
            _checkAndReportModStatus(joinGameInfo.mods);
            showJoinGameDialog();
          }
        })
        .catchError((error) {
          _logger.warning('Failed to get current party', error);
        });

    _channel = IOWebSocketChannel.connect(
      'wss://api.${Preferences.admin.apiEnv}.kyber.gg/ws/session',
      headers: {'Authorization': sl.get<KyberGRPCService>().token},
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
            .proxiesUpdated => null,
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

    final delay = Duration(
      seconds: math.min(2 << _reconnectAttempts, 30),
    );
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
    if (context == null || !context.mounted || !update) return;

    await showKyberDialog(
      context: context,
      builder: (_) => const UpdateDialog(),
    );
  }

  void _handlePartyEvent(PartyEvent event) async {
    final userId = _userId;

    if (event.hasInviteReceived()) {
      final invite = event.inviteReceived;
      final isFriend =
          navigatorKey.currentContext?.read<MaximaRtmCubit>().state.friends.any(
            (f) => f.id == invite.inviter.id,
          ) ??
          false;

      if (!isFriend && !Preferences.general.allowPartyInvitesFromAnyone) {
        _logger.warning(
          'Ignoring invite from non-friend ${invite.inviter.name}',
        );
        return;
      }

      final pending = PendingInvite(
        partyId: Int64(invite.partyId.toInt()),
        inviter: invite.inviter,
        inviteToken: invite.inviteToken,
        expiresAt: invite.expiresAt,
        size: invite.partySize,
      );

      if (state is InParty) {
        emit((_inParty!).copyWith(pendingInvite: pending));
      } else {
        emit(PartyInitial(pendingInvite: pending));
      }
      return;
    }

    if (event.hasKicked()) {
      gameJoined = false;
      _partyDownloadChecker?.cancel();
      _partyDownloadChecker = null;
      NotificationService.warning(message: 'You were kicked from the party');
      emit(PartyInitial());
      return;
    }

    if (_inParty == null) {
      final resp = await _service.partyServiceClient.getParty(.new());
      if (isClosed || !resp.hasParty()) return;

      emit(InParty(resp.party));
    }

    final party = _inParty?.party;
    if (party == null) return;

    if (event.hasNewLeader()) {
      final id = event.newLeader.newLeaderId;
      final name =
          party.members
              .firstWhereOrNull((m) => m.player.id == id)
              ?.player
              .name ??
          id;

      if (id == userId) {
        NotificationService.success(message: 'You are now the party leader');
      } else {
        NotificationService.info(message: '$name is now the party leader');
      }

      final updated = PartyState(
        id: party.id,
        leaderId: id,
        createdAt: party.createdAt,
        members: party.members,
      );
      final info = _inParty?.joinGameInfo;
      _emitInParty(updated, joinGameInfo: info?.copyWith(leaderId: id));
    } else if (event.hasInviteAccepted()) {
      NotificationService.success(
        message: '${event.inviteAccepted.user.name} accepted the party invite',
      );
    } else if (event.hasInviteDeclined()) {
      NotificationService.warning(
        message: '${event.inviteDeclined.user.name} declined the party invite',
      );
    } else if (event.hasMemberJoined()) {
      if (event.memberJoined.user.id == userId) return;

      NotificationService.info(
        message: '${event.memberJoined.user.name} joined the party',
      );
      _updateMembers([
        ...party.members,
        PartyMember(
          player: event.memberJoined.user,
          joinedAt: Int64(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        ),
      ]);
    } else if (event.hasMemberLeft()) {
      if (event.memberLeft.userId == userId) {
        emit(PartyInitial());
        return;
      }

      final leftName =
          party.members
              .firstWhereOrNull(
                (m) => m.player.id == event.memberLeft.userId,
              )
              ?.player
              .name ??
          event.memberLeft.userId;
      NotificationService.warning(message: '$leftName left the party');

      final remaining = party.members.whereNot(
        (e) => e.player.id == event.memberLeft.userId,
      );

      if (remaining.length <= 1) {
        emit(PartyInitial());
        return;
      }

      _updateMembers([...remaining]);

      final info = _inParty?.joinGameInfo;
      if (info != null) {
        final statuses = Map<String, JoinGameMemberStatusInfo>.from(
          info.memberStatuses,
        )..remove(event.memberLeft.userId);
        _emitInParty(
          _inParty!.party,
          joinGameInfo: info.copyWith(memberStatuses: statuses),
        );
      }
    } else if (event.hasJoinGame()) {
      final jg = event.joinGame;
      final existing = _inParty?.joinGameInfo;
      final isSameServer = existing?.serverId == jg.serverId;

      final memberStatuses = <String, JoinGameMemberStatusInfo>{
        for (final m in party.members)
          m.player.id:
              (isSameServer ? existing!.memberStatuses[m.player.id] : null) ??
              const JoinGameMemberStatusInfo(hasMods: false),
      };

      final joinGameInfo = JoinGameInfo(
        serverId: jg.serverId,
        serverName: jg.serverName,
        mods: jg.mods.toList(),
        leaderId: jg.leaderId,
        memberStatuses: memberStatuses,
      );

      _emitInParty(party, joinGameInfo: joinGameInfo);
      _checkAndReportModStatus(jg.mods.toList());
      if (!isSameServer) {
        showJoinGameDialog();
      }
    } else if (event.hasJoinGameStatus()) {
      final status = event.joinGameStatus;
      final info = _inParty?.joinGameInfo;
      if (info == null) return;

      final statuses = Map<String, JoinGameMemberStatusInfo>.from(
        info.memberStatuses,
      );
      statuses[status.userId] = JoinGameMemberStatusInfo(
        hasMods: status.hasMods,
        modDownloadPercentage: status.hasModDownloadPercentage()
            ? status.modDownloadPercentage
            : null,
        joined: status.joined,
      );

      _emitInParty(
        party,
        joinGameInfo: info.copyWith(memberStatuses: statuses),
      );

      if (gameJoined) return;

      final myStatus = statuses[userId];
      final leaderStatus = statuses[info.leaderId];
      final isLeader = userId == info.leaderId;
      if (!isLeader &&
          (leaderStatus?.joined ?? false) &&
          (myStatus?.hasMods ?? false)) {
        NotificationService.info(message: 'Host is in game! Joining...');
        await joinServerForParty();
        return;
      }

      final everyoneHasMods = statuses.values.every((s) => s.hasMods);
      final everyoneReady = !statuses.values.every((s) => s.joined);
      if (everyoneHasMods && everyoneReady) {
        NotificationService.info(
          message: 'All players are ready! Joining game...',
        );
        await joinServerForParty();
      }
    } else if (event.hasJoinGameReady()) {
      final info = _inParty?.joinGameInfo;
      if (info == null) return;

      final myStatus = info.memberStatuses[userId];
      if (myStatus?.hasMods ?? false) {
        if (gameJoined) {
          return;
        }

        NotificationService.info(message: 'Joining game...');
        await joinServerForParty();
      } else {
        NotificationService.warning(
          message: 'The party is joining but you are missing mods.',
        );
      }
    } else if (event.hasJoinGameCancelled()) {
      _partyDownloadChecker?.cancel();
      _partyDownloadChecker = null;
      gameJoined = false;
      emit(InParty(party, pendingInvite: _inParty?.pendingInvite));
      NotificationService.info(message: 'Join game was cancelled');
    }
  }

  Future<bool> isAlreadyIngame() async {
    if (state is! InParty) return false;
    final serverId = _inParty?.joinGameInfo?.serverId;

    final instance = sl.maybeGet<MaximaGameInstance>();
    if (instance == null) return false;

    final server = await instance.clientService.commonClient.getInfo(.new());
    if (server.server.id != serverId) return false;

    return true;
  }

  void _emitInParty(PartyState party, {JoinGameInfo? joinGameInfo}) {
    emit(
      InParty(
        _sortMembers(party),
        pendingInvite: _inParty?.pendingInvite,
        joinGameInfo: joinGameInfo ?? _inParty?.joinGameInfo,
      ),
    );
  }

  PartyState _sortMembers(PartyState party) {
    final sorted = party.members.toList()
      ..sort((a, b) {
        if (a.player.id == party.leaderId) return -1;
        if (b.player.id == party.leaderId) return 1;
        return a.joinedAt.compareTo(b.joinedAt);
      });

    return PartyState(
      id: party.id,
      leaderId: party.leaderId,
      createdAt: party.createdAt,
      members: sorted,
    );
  }

  void _updateMembers(List<PartyMember> members) {
    final party = _inParty?.party;
    if (party == null) return;

    final unique = <String, PartyMember>{
      for (final m in members) m.player.id: m,
    }.values.toList();

    _emitInParty(
      PartyState(
        id: party.id,
        leaderId: party.leaderId,
        createdAt: party.createdAt,
        members: unique,
      ),
    );
  }

  JoinGameInfo _buildJoinGameInfoFromState(
    JoinGameState jgs,
    String leaderId,
  ) {
    return JoinGameInfo(
      serverId: jgs.serverId,
      serverName: jgs.serverName,
      mods: jgs.mods.toList(),
      leaderId: leaderId,
      memberStatuses: {
        for (final s in jgs.memberStatuses)
          s.userId: JoinGameMemberStatusInfo(
            hasMods: s.hasMods,
            modDownloadPercentage: s.hasModDownloadPercentage()
                ? s.modDownloadPercentage
                : null,
            joined: s.joined,
          ),
      },
    );
  }

  void _sendModStatus({required bool hasMods, int? modDownloadPercentage}) {
    _channel?.sink.add(
      SessionClientEvent(
        updateJoinGameStatus: UpdateJoinGameStatusEvent(
          hasMods: hasMods,
          modDownloadPercentage: modDownloadPercentage,
        ),
      ).writeToBuffer(),
    );
  }

  void _checkAndReportModStatus(List<ServerMod> mods) {
    _sendModStatus(
      hasMods: mods.every(
        (mod) => ModHelper.isInstalled(mod.name, mod.version),
      ),
    );
  }

  Future<int> _calcModProgress(List<ServerMod> mods) async {
    var total = 0;
    var current = 0;
    final downloads = await const DownloadRepository().getActiveTasks();

    for (final mod in mods) {
      total += mod.fileSize.toInt();
      if (ModHelper.isInstalled(mod.name, mod.version)) {
        current += mod.fileSize.toInt();
        continue;
      }
      for (final task in downloads) {
        final meta = ServerMod.fromJson(task.task.metaData);
        if (meta.hasName() &&
            meta.name == mod.name &&
            meta.version == mod.version) {
          current += (meta.fileSize.toInt() * task.progress).toInt();
        }
      }
    }

    return total == 0 ? 0 : ((current / total) * 100).toInt();
  }

  Future<({List<mb.Mod> mods, int failedCount})> _searchForMods(
    List<ServerMod> missingMods,
  ) async {
    var failedCount = 0;
    final bridgeMods = missingMods
        .mapIndexed(
          (i, m) => mb.BridgeMod(
            name: m.name,
            version: m.version,
            id: i.toString(),
          ),
        )
        .toList();

    final found = <mb.Mod>[];
    final notFound = <mb.BridgeMod>[];

    for (final chunk in bridgeMods.slices(50)) {
      final resp = await sl
          .get<ModBridgeGRPCService>()
          .searchClient
          .searchMods(mb.SearchModsRequest(mods: chunk))
          .catchError((e) {
            _logger.severe('Error searching mods', e);
            NotificationService.showNotification(
              message: 'Error searching mods: $e',
            );
            return mb.SearchModsResponse();
          });

      if (resp.mods.isEmpty && resp.notFound.isEmpty) continue;
      found.addAll(resp.mods);
      notFound.addAll(resp.notFound);
    }

    final finderService = ModFinderService();
    for (final mod in notFound) {
      final serverMod = missingMods.firstWhere(
        (e) => e.name == mod.name && e.version == mod.version,
      );

      if (serverMod.link.isEmpty) {
        failedCount++;
        continue;
      }

      final resp = await finderService.searchMod(
        serverMod.link,
        mod.version,
      );
      if (resp.$2.isEmpty) {
        failedCount++;
        continue;
      }

      final modId = resp.$1;
      final file = resp.$2.first;
      found.add(
        mb.Mod(
          name: file.name,
          link:
              'https://www.nexusmods.com/starwarsbattlefront22017/mods/$modId?tab=files&file_id=${file.fileId}',
          modId: int.parse(modId),
          fileId: int.parse(file.fileId),
          id: missingMods.indexOf(serverMod).toString(),
        ),
      );
    }

    return (mods: found, failedCount: failedCount);
  }

  Future<void> _enqueueModDownload(
    mb.Mod mod, {
    required ServerMod serverMod,
  }) async {
    final url = mod.link.contains('https://www.nexusmods')
        ? '${mod.link}&file_id=${mod.fileId}'
        : mod.link;

    await sl.get<DownloadOrchestrator>().enqueueDownload(
      DownloadRequest(
        link: url,
        displayName: mod.name,
        linkType: url.startsWith('https://www.nexusmods')
            ? dl.DownloadLinkType.nexus
            : dl.DownloadLinkType.direct,
        size: mod.fileSize.toInt(),
        filename: mod.link.split('/').last.split('?').first,
        priority: 1,
        metadata: {
          'name': serverMod.name,
          'version': serverMod.version,
          'link': serverMod.link,
          'fileSize': serverMod.fileSize.toInt(),
        },
      ),
    );
  }

  void _startDownloadProgressTracker(List<ServerMod> mods) {
    _partyDownloadChecker?.cancel();
    _partyDownloadChecker = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        if (_inParty?.joinGameInfo == null) {
          timer.cancel();
          _partyDownloadChecker = null;
          return;
        }

        await sl<ModService>().refreshCompleter.future;

        final allInstalled = mods.every(
          (mod) => ModHelper.isInstalled(mod.name, mod.version),
        );

        if (allInstalled) {
          timer.cancel();
          _partyDownloadChecker = null;
          _sendModStatus(hasMods: true);
          NotificationService.success(message: 'All mods downloaded!');
          return;
        }

        final progress = await _calcModProgress(mods);
        _sendModStatus(hasMods: false, modDownloadPercentage: progress);
      },
    );
  }
}
