import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/windows_env.dart';
import 'package:kyber_launcher/features/ea/services/search_service.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_status_helper.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_api_status_cubit.dart';
import 'package:kyber_launcher/features/lightswitch/models/status.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_game_not_found_dialog.dart';
import 'package:kyber_launcher/gen/rust/api/archive.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_to_front/window_to_front.dart';

part '../models/maxima_state.dart';

class MaximaCubit extends Cubit<MaximaState> {
  MaximaCubit() : super(MaximaState.initial()) {
    init();
  }

  final logger = Logger('maxima_cubit');

  Timer? _updateTimer;

  bool _loggingIn = false;

  @override
  Future<void> close() async {
    _updateTimer?.cancel();
    await super.close();
  }

  String? getUsername() => state.servicePlayer?.displayName;

  Future<void> verifyToken([int tries = 0]) async {
    if (tries >= 3) {
      _updateTimer?.cancel();
      _updateTimer = null;
      return requestLogin(skipMaximaCheck: true);
    }

    try {
      final response = await sl.get<KyberGRPCService>().authClient.verify(
        Empty(),
      );
      if (response.hasDiscord()) {
        emit(
          state.copyWith(
            discordData: response.discord,
          ),
        );
      }
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unauthenticated) {
        _updateTimer?.cancel();
        _updateTimer = null;
        logger.warning('Token invalid, reauthenticating...');
        return requestLogin(skipMaximaCheck: true);
      } else {
        logger.severe('Error verifying token: ', e.message);
        await Future<void>.delayed(const Duration(seconds: 2));
        return verifyToken(tries + 1);
      }
    } catch (e, s) {
      logger.severe('Unknown error verifying token:', e, s);
      await Future<void>.delayed(const Duration(seconds: 2));
      return verifyToken(tries + 1);
    }
  }

  void removeDiscordData() {
    emit(
      MaximaState(
        status: state.status,
        error: state.error,
        entitlements: state.entitlements,
        loggedIn: state.loggedIn,
        gameRunning: state.gameRunning,
        isPatron: state.isPatron,
        servicePlayer: state.servicePlayer,
      ),
    );
  }

  Future<void> init({bool skipSetupCheck = false}) async {
    if (state.status == MaximaStatus.loaded ||
        !skipSetupCheck && !Preferences.general.setup) {
      return;
    }

    ProcessEnv.set('MAXIMA_LOG_LEVEL', kMaximaDebugLevel);
    emit(state.copyWith(status: MaximaStatus.starting));
    await _checkDebugMaximaFiles();

    final currentDir = dirname(Platform.resolvedExecutable);
    final serviceFile = File(join(currentDir, 'maxima-service.exe'));
    final bootstrapFile = File(join(currentDir, 'maxima-bootstrap.exe'));

    if ((!serviceFile.existsSync() || !bootstrapFile.existsSync()) &&
        !kDebugMode &&
        Platform.isWindows) {
      return emit(
        const MaximaState(
          status: MaximaStatus.error,
          error: 'MissingMaximaFiles',
        ),
      );
    }

    logger.info('Initializing maxima');
    final now = DateTime.now();
    try {
      await startMaxima();
    } catch (e, s) {
      logger.severe('Error starting maxima:', e, s);
      if (e is AnyhowException &&
          (e.message.contains('(os error 5)') ||
              s.toString().contains('(os error 5)'))) {
        emit(
          const MaximaState(
            status: MaximaStatus.error,
            error: 'MaximaFailedBackgroundService',
          ),
        );
        rethrow;
      }

      emit(MaximaState(status: MaximaStatus.error, error: e.toString()));
      rethrow;
    } finally {
      logger.info(
        'Maxima initialized. (Took ${DateTime.now().difference(now).inMilliseconds}ms)',
      );
    }

    final loggedIn = await isLoggedIn();
    if (loggedIn) {
      logger.info('Already logged in');
      await requestLogin(skipMaximaCheck: true);

      if (state.status == .error) {
        return;
      }

      return emit(
        state.copyWith(
          loggedIn: true,
          servicePlayer: state.servicePlayer,
          status: .loaded,
        ),
      );
    }

    emit(state.copyWith(status: .loaded));
  }

  Future<void> logout() async {
    final maximaAuthFile = File(
      "${Platform.environment['APPDATA']}\\ArmchairDevelopers\\Maxima\\data\\auth.toml",
    );
    if (maximaAuthFile.existsSync()) {
      maximaAuthFile.deleteSync();
    }

    await launchUrlString(
      'https://accounts.ea.com/connect/logout?client_id=EADOTCOM-WEB-SERVER&redirect_uri=https://ea.com',
    );

    exit(0);
  }

  Future<void> downloadFiles() async {
    if (kDebugMode) {
      return;
    }

    try {
      logger.info('Downloading required files');
      emit(const MaximaState(status: .starting));
      await Dio().download(
        'https://s3.kyber.gg/artifacts/maxima-win64.zip',
        '${Directory.current.path}\\maxima.zip',
      );
      await extract(
        filePath: '${Directory.current.path}\\maxima.zip',
        targetDir: Directory.current.path,
      );

      File('${Directory.current.path}\\maxima.zip').deleteSync();
      await init();
    } catch (e) {
      logger.severe('Error downloading maxima:', e);
      emit(
        MaximaState(
          status: .error,
          error: e.toString(),
          servicePlayer: state.servicePlayer,
        ),
      );
    }
  }

  void emitError(String error) {
    emit(
      MaximaState(
        status: .error,
        error: error,
        servicePlayer: state.servicePlayer,
      ),
    );
  }

  Future<void> requestLogin({bool skipMaximaCheck = false}) async {
    if (_loggingIn) {
      return Future.error('Already logging in');
    }

    final cubit = navigatorKey.currentContext!.read<LightswitchCubit>();
    late LightswitchStatus status;
    if (!cubit.firstRequestCompleter.isCompleted) {
      status = await cubit.firstRequestCompleter.future;
    } else {
      status = cubit.state;
    }

    if (status.status == KyberStatusEnum.down) {
      _updateTimer?.cancel();

      logger.severe('Kyber is down... Skipping login');

      return emit(
        MaximaState(
          status: .error,
          error: 'KyberDown',
          servicePlayer: state.servicePlayer,
        ),
      );
    }

    if (state.status != .loaded && !skipMaximaCheck) {
      await init(skipSetupCheck: true);
    }

    _loggingIn = true;
    ServicePlayer? servicePlayer;
    try {
      logger.info('Requesting login');

      emit(state.copyWith(status: MaximaStatus.loading));

      servicePlayer = await loginFlow();
      await WindowToFront.activate();
      await Sentry.configureScope((scope) async {
        await scope.setUser(
          SentryUser(
            id: servicePlayer!.id,
            username: servicePlayer.displayName,
          ),
        );
        await scope.setTag(
          'kyber-module-version',
          (await VersionModule.module.getCurrentVersion()) ?? 'unknown',
        );
      });

      final ownsGame = await checkGameOwnership();
      if (!ownsGame) {
        _updateTimer?.cancel();

        logger.info('User does not own the game');

        await showKyberDialog(
          context: navigatorKey.currentContext!,
          builder: (_) => const MaximaGameNotFoundDialog(),
        );

        _loggingIn = false;
        emit(
          MaximaState(
            status: .error,
            error: 'GameNotOwned',
            servicePlayer: servicePlayer,
          ),
        );

        return;
      }

      // configCat.setDefaultUser(ConfigCatUser(
      //   identifier: servicePlayer.id,
      // ));

      logger
        ..info(
          'Logged in as ${servicePlayer.displayName} (${servicePlayer.pd})',
        )
        ..info('Requesting Kyber auth token');

      final authToken = await getAuthToken();
      final resp = await sl.get<KyberGRPCService>().login(authToken);

      final entitlements = resp.entitlements
          .map(parseUserEntitlement)
          .whereType<UserEntitlement>();
      ProcessEnv.set('KYBER_API_TOKEN', resp.token);

      logger.info(
        'Logged in to Kyber. User has ${resp.entitlements.length} entitlements',
      );

      emit(
        state.copyWith(
          loggedIn: true,
          entitlements: entitlements.toList(growable: false),
          servicePlayer: servicePlayer,
          status: MaximaStatus.loaded,
          isPatron: resp.isPatreon,
          discordData: resp.hasDiscord() ? resp.discord : null,
        ),
      );

      if (Preferences.customization.customBackground && !state.canUsePerks()) {
        Preferences.customization.customBackground = false;
      }

      if (state.canUsePerks() &&
          Preferences.customization.activeColor != kDefaultActiveColor) {
        kActiveColor = Preferences.customization.activeColor;
        Preferences.customization.activeColor = kActiveColor;
      }

      _loggingIn = false;

      await startRtmConnection();

      logger.info('Initialized');

      if (!sl.isRegistered<SearchService>()) {
        sl.registerSingleton<SearchService>(SearchService(eaToken: authToken));
      }

      _updateTimer ??= Timer.periodic(
          const Duration(minutes: 5),
          (_) async {
            logger.info('Validating session...');
            await verifyToken();
          },
        );

      return;
    } catch (e, s) {
      _updateTimer?.cancel();
      Logger('maxima').severe('Error logging in:', e, s);
      if (e is AnyhowException) {
        if (e.message.contains('"error":"invalid_grant"')) {
          logger.severe('Invalid grant... Logging out');
          _loggingIn = false;

          final authFile = File(
            "${Platform.environment['UserProfile']}\\AppData\\Roaming\\ArmchairDevelopers\\Maxima\\data\\auth.toml",
          );
          if (authFile.existsSync()) {
            authFile.deleteSync();
            return requestLogin();
          }
        } else if (e.message.contains('Game not owned')) {
          logger.severe('Unknown error... Logging out');
          _loggingIn = false;
          return emit(
            MaximaState(
              status: MaximaStatus.error,
              error: 'Game not owned',
              servicePlayer: servicePlayer,
            ),
          );
        } else {
          logger.severe('Unknown error... Logging out');
          _loggingIn = false;
          return emit(
            MaximaState(
              status: MaximaStatus.error,
              error: e.message,
              servicePlayer: servicePlayer,
            ),
          );
        }
      } else if (e is GrpcError) {
        logger.severe('Unauthenticated... Logging out');
        _loggingIn = false;
        return emit(
          MaximaState(
            status: MaximaStatus.error,
            error: e.message,
            servicePlayer: servicePlayer,
          ),
        );
      } else {
        logger.severe('Unknown error... Logging out');
        _loggingIn = false;
        return emit(
          MaximaState(
            status: MaximaStatus.error,
            error: e.toString(),
            servicePlayer: servicePlayer,
          ),
        );
      }
    } finally {
      _loggingIn = false;
    }

    return Future.error('Login failed');
  }

  Future<void> _checkDebugMaximaFiles() async {
    if (!kDebugMode || !Platform.isWindows) {
      return;
    }

    if (!Directory('.cache').existsSync()) {
      logger.info('Downloading maxima');
      Directory(
        '.cache/maxima/maxima-x86_64-win64/',
      ).createSync(recursive: true);
      await Dio().download(
        'https://s3.kyber.gg/artifacts/maxima-win64.zip',
        '.cache/maxima.zip',
      );
      logger.info('Extracting maxima');
      await extract(
        filePath: '.cache/maxima.zip',
        targetDir: '.cache/maxima/maxima-x86_64-win64/',
      );
      File('.cache/maxima.zip').deleteSync();
    }

    if (!File(
      'build/windows/x64/runner/Debug/maxima-bootstrap.exe',
    ).existsSync()) {
      await File(
        '.cache/maxima/maxima-x86_64-win64/maxima-bootstrap.exe',
      ).copy('build/windows/x64/runner/Debug/maxima-bootstrap.exe');
    }

    if (Platform.isWindows) {
      if (!File(
        'build/windows/x64/runner/Debug/maxima-service.exe',
      ).existsSync()) {
        await File(
          '.cache/maxima/maxima-x86_64-win64/maxima-service.exe',
        ).copy('build/windows/x64/runner/Debug/maxima-service.exe');
      }
    }
  }
}
