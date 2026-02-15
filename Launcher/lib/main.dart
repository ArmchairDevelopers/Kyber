import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:grpc/grpc.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/i18n/app_locale.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/native_dialog.dart';
import 'package:kyber_launcher/core/services/storage_helper.dart';
import 'package:kyber_launcher/core/services/window_helper.dart';
import 'package:kyber_launcher/core/utils/custom_logger.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/events/providers/event_cubic.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_api_status_cubit.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/map_rotation/providers/map_rotation_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_browser_cubit.dart';
import 'package:kyber_launcher/features/mods/providers/mod_list_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/helper/protocol_helper.dart';
import 'package:kyber_launcher/features/navigation_bar/providers/status_cubit.dart';
import 'package:kyber_launcher/features/nexusmods/widgets/graphql_provider.dart';
import 'package:kyber_launcher/features/server_browser/providers/ingame_view_cubit.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_list_cubit.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_servers_cubit.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/features/stats/providers/stats_cubit.dart';
import 'package:kyber_launcher/features/tutorial/providers/tutorial_cubit.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/rust/frb_generated.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/layout/kyber_background.dart';
import 'package:kyber_launcher/shared/ui/utils/hive_listener.dart';
import 'package:kyber_launcher/shared/window_controller_screen.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart';
import 'package:rhttp/rhttp.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_logging/sentry_logging.dart';
import 'package:toastification/toastification.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:window_manager/window_manager.dart';

const kMaximaDebugLevel = 'debug';

JavascriptRuntime? flutterJs;
WebViewEnvironment? webViewEnvironment;
String? bbCodeJs;

Box<dynamic> box = Hive.box('data');
Box<List> mapRotationBox = Hive.box('mapRotation');
Box<ModCollectionMetaData> collectionBox = Hive.box<ModCollectionMetaData>(
  'modCollections',
);
String applicationDocumentsDirectory = '';

Future<void> initSentry(String currentVersion) async => SentryFlutter.init(
  (options) {
    options
      ..autoSessionTrackingInterval = const Duration(minutes: 1)
      ..dsn = 'https://669b349a1c13f9deacc00126db6cecb8@sentry.kyber.gg/3'
      ..tracesSampleRate = 1.0
      ..attachThreads = true
      ..enableAppHangTracking = true
      ..enableTimeToFullDisplayTracing = true
      ..release = 'kyber-launcher@$currentVersion'
      ..debug = false
      ..beforeSend = (SentryEvent event, Hint? hint) {
        final exception = event.exceptions?.firstOrNull?.throwable;

        if (exception is SocketException ||
            exception is WebSocketException ||
            exception is WebSocketChannelException ||
            exception is HttpException ||
            exception is DioException ||
            exception is TimeoutException) {
          return null;
        }

        if (exception is GrpcError && exception.code == StatusCode.unknown) {
          return null;
        }

        if (exception is FlutterError && exception.message.contains('RenderFlex')) {
          return null;
        }

        if (kDebugMode) {
          return null;
        }

        if (exception.toString().contains('Invalid image data')) {
          return null;
        }

        return event;
      }
      ..addIntegration(
        LoggingIntegration(),
      );
  },
);

Future<void> loadCerts() async {
  for (final ca in Assets.ca.values) {
    final data = await PlatformAssetBundle().load(ca);
    SecurityContext.defaultContext.setTrustedCertificatesBytes(
      data.buffer.asUint8List(),
    );
  }
}

String? launcherVersion;

void main() async {
  if (Platform.isWindows &&! kDebugMode) {
    final exeDir = dirname(Platform.resolvedExecutable);
    final rustLib = File(join(exeDir, 'rust_lib.dll'));
    if (!rustLib.existsSync()) {
      showRustLibMissingDialog();
      exit(0);
    }
  }

  await Rhttp.init();
  await MaximaLib.init();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      MediaKit.ensureInitialized();

      final started = DateTime.now();

      await windowManager.ensureInitialized();
      applicationDocumentsDirectory = FileHelper.getLauncherDirectory().path;
      if (!Directory(applicationDocumentsDirectory).existsSync()) {
        Directory(applicationDocumentsDirectory).createSync(recursive: true);
      }

      CustomLogger.initialize();

      final info = await PackageInfo.fromPlatform();
      launcherVersion = '${info.version}-#${info.buildNumber}';
      Logger('bootstrap').info('Starting Launcher v$launcherVersion');

      Logger('bootstrap').info('Loading Certificates');
      await loadCerts();
      await initSentry(info.version);
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final availableVersion = await WebViewEnvironment.getAvailableVersion();
        if (availableVersion == null) {
          showWebViewDialog();
          exit(0);
        }

        webViewEnvironment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: '$applicationDocumentsDirectory\\webview',
          ),
        );
      }

      await StorageHelper.initializeHive();
      await WindowHelper.initializeWindow();
      await ProtocolHelper.register();
      CustomLogger.setupRustLogs();

      final unrarPath = join(dirname(Platform.resolvedExecutable), 'UnRAR.dll');
      if (kDebugMode && Platform.isWindows && !File(unrarPath).existsSync()) {
        File(r'third_party\libs\UnRAR.dll').copySync(unrarPath);
      }

      runApp(const App());
      Logger('bootstrap').info(
        'Started in ${DateTime.now().difference(started).inMilliseconds}ms',
      );
    },
    (exception, stackTrace) async {
      Logger.root.severe('Uncaught exception:', exception, stackTrace);
      await Sentry.captureException(exception, stackTrace: stackTrace);
    },
  );
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    initializeDependencies();

    Timer.run(() async {
      Logger('flutter_js').info('Loading runtime');
      flutterJs = getJavascriptRuntime();
      bbCodeJs = await rootBundle.loadString('assets/js/bundle.js');
      flutterJs!.evaluate(bbCodeJs!);

      await Sentry.configureScope((scope) async {
        await scope.setTag(
          'release-channel',
          VersionModule.installer.releaseChannel,
        );
      });

      router.routeInformationProvider.addListener(
        () => onUriChanged(router.routeInformationProvider.value.uri),
      );
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      config: ToastificationConfig(
        animationDuration: const Duration(seconds: 1),
        marginBuilder: (context, child) => const .only(bottom: 20, left: 20, right: 20),
      ),
      child: HiveListener(
        box: box,
        keys: const ['locale', 'activeColor'],
        builder: (_) => FluentApp.router(
          title: 'KYBER Launcher',
          color: kActiveColor,
          darkTheme: FluentThemeData(
            accentColor: kActiveColor.toAccentColor(
              darkFactor: 0,
              darkerFactor: 0,
              darkestFactor: 0,
              lighterFactor: 0,
              lightestFactor: 0,
              lightFactor: 0,
            ),
            activeColor: kActiveColor,
            brightness: Brightness.dark,
            fontFamily: FontFamily.battlefrontUI,
            radioButtonTheme: RadioButtonThemeData(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return kInactiveColor;
                }
                return kActiveColor;
              }),
            ),
            scrollbarTheme: ScrollbarThemeData(
              thickness: 3,
              hoveringThickness: 3,
              scrollbarPressingColor: kActiveColor,
              trackBorderColor: Colors.transparent,
              hoveringTrackBorderColor: kWhiteBackgroundColor,
              hoveringMainAxisMargin: 0,
              crossAxisMargin: 0,
              padding: EdgeInsets.zero,
              hoveringPadding: EdgeInsets.zero,
              hoveringCrossAxisMargin: 0,
              mainAxisMargin: 0,
              backgroundColor: Colors.transparent,
            ),
            typography: Typography.fromBrightness(brightness: .dark).apply(
              fontFamily: FontFamily.battlefrontUI,
            ),
          ),
          backButtonDispatcher: RootBackButtonDispatcher(),
          themeMode: ThemeMode.dark,
          locale: AppLocale.getLocale(),
          localizationsDelegates: const [
            ...GlobalMaterialLocalizations.delegates,
            FormBuilderLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            child = WindowController(
              child: GraphqlProvider(
                child: child!,
              ),
            );

            return Builder(
              builder: (context) {
                return DisableAcrylic(
                  child: MultiBlocProvider(
                    providers: [
                      BlocProvider(create: (_) => StatusCubit()),
                      BlocProvider(create: (_) => MaximaCubit()),
                      BlocProvider(create: (_) => MaximaRtmCubit()),
                      BlocProvider(create: (_) => MapRotationCubit()),
                      BlocProvider(create: (_) => TutorialCubit()),
                      BlocProvider(create: (_) => KyberStatusCubit()),
                      BlocProvider(create: (_) => ModBrowserCubit()),
                      BlocProvider(create: (_) => ServerListCubit()),
                      BlocProvider(create: (_) => ModerationServersCubit()),
                      BlocProvider(create: (_) => ModerationCubit()),
                      BlocProvider(create: (_) => ServerBrowserCubit()),
                      BlocProvider(create: (_) => EventCubit()),
                      BlocProvider(create: (_) => KyberProxyCubit()),
                      BlocProvider(create: (_) => ModsListCubit()),
                      BlocProvider(create: (_) => StatsCubit()),
                      BlocProvider(create: (_) => SessionCubit()),
                      BlocProvider(create: (_) => IngameViewCubit()),
                      BlocProvider(create: (_) => DownloadCubit(), lazy: false),
                      BlocProvider(
                        create: (_) => LightswitchCubit(),
                        lazy: false,
                      ),
                    ],
                    child: KyberBackground(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            );
          },
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          routeInformationProvider: router.routeInformationProvider,
        ),
      ),
    );
  }
}
