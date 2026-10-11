import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/stats/models/stats_object.dart';
import 'package:kyber_launcher/injection_container.dart';

part 'stats_state.dart';

typedef GStatsResponse = Map<String, dynamic>;

class StatsCubit extends Cubit<StatsState> {
  bool hasKBStats = true;

  StatsCubit({String? username}) : super(StatsInitial()) {
    final player = navigatorKey.currentContext
        ?.read<MaximaCubit>()
        .state
        .servicePlayer;
    this.username = username ?? player?.uniqueName ?? '';
    if (username == null || username == player?.uniqueName) {
      personaId = player?.pd;
    }

    _statsSource = .KYBER;

    fetchStats(statsSource: _statsSource);
  }

  String? personaId;
  StatsObject<Object>? _selectedCharacterStats;

  late String username;
  late StatsSource _statsSource;

  StatsSource get statsSource => _statsSource;

  Future<void> loadUser({
    required String username,
    required String personaId,
  }) async {
    this.username = username;
    this.personaId = personaId;
    await fetchStats();
  }

  Future<void> loadPersonaId() async {
    return;
    final personaId = await sl.get<KyberGRPCService>().statsClient.searchUser(
      StatsSearchRequest(query: username),
    );
    if (personaId.users.isEmpty) {
      throw Exception('User not found');
    }

    this.personaId = personaId.users.first.personaId;
  }

  Future<void> fetchStats({StatsSource? statsSource}) async {
    try {
      if (!hasKBStats && statsSource != StatsSource.EA_PC) {
        return;
      }

      emit(StatsLoading());

      if (personaId == null) {
        await loadPersonaId();
      }

      statsSource ??= StatsSource.EA_PC;
      _statsSource = statsSource;

      final kService = sl.get<KyberGRPCService>();

      final player = navigatorKey.currentContext
          ?.read<MaximaCubit>()
          .state
          .servicePlayer;
      if (player == null) {
        emit(StatsError('You are not logged in'));
        return;
      }
      final statsResponse = await kService.statsClient.getStats(
        StatsRequest(
          source: statsSource,
          user: player.id,
          personaId: player.psd,
        ),
      );
      final statistics = PlayerStats.fromMap(statsResponse.stats);
      _selectedCharacterStats = statistics.heroes.first;

      emit(
        StatsLoaded(
          stats: statsResponse.stats,
          statsSource: statsSource,
          playerStats: statistics,
          selectedObject: _selectedCharacterStats!,
        ),
      );
    } on GrpcError catch (e) {
      print('e: ${e.message}, code: ${e.code}');
      if (e.code == StatusCode.notFound && statsSource != StatsSource.EA_PC) {
        hasKBStats = false;
        NotificationService.info(message: 'No KYBER stats found for $username');
        return fetchStats(statsSource: StatsSource.EA_PC);
      } else if (e.message == 'EA Stats client is not available') {
        NotificationService.warning(message: 'EA stats are currently unavailable');
        return fetchStats(statsSource: StatsSource.KYBER);
      }

      emit(StatsError(e.message ?? 'Unknown GRPC Error'));
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }

  void selectHero(StatsObject<Object> object) {
    if (state is! StatsLoaded) {
      throw Exception('Stats are not loaded');
    }

    _selectedCharacterStats = object;
    emit((state as StatsLoaded).copyWith(selectedObject: object));
  }

  StatsObject<Object> getCurrentCharacterStats() {
    if (state is! StatsLoaded) {
      throw Exception('Stats are not loaded');
    }

    return _selectedCharacterStats!;
  }

  int getTotalScore() {
    if (state is! StatsLoaded) {
      throw Exception('Stats are not loaded');
    }

    final stats = (state as StatsLoaded).stats;

    final keys = [
      'c_ca__csax_gatt',
      'c_chspall__csax_gatt',
      'c_chall__csax_gatt',
      'c_allveh__csax_gatt',
    ];
    return keys
        .map((x) => (stats[x] as double? ?? 0).toInt())
        .reduce((a, b) => a + b);
  }
}
