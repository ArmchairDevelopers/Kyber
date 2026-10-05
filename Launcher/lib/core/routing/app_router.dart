import 'package:fluent_ui/fluent_ui.dart' hide Feedback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/download_manager/screens/download_manager.dart';
import 'package:kyber_launcher/features/frosty/screens/create_frosty_collection.dart';
import 'package:kyber_launcher/features/kyber/widgets/debug_server_launcher.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_search_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/mod_browser/screens/nexus_profile.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_editor_cubit.dart';
import 'package:kyber_launcher/features/mod_collections/screens/collection_import.dart';
import 'package:kyber_launcher/features/mods/providers/collection_editor_cubit.dart';
import 'package:kyber_launcher/features/mods/screens/mods.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/navigation_bar/screens/navigation_bar.dart';
import 'package:kyber_launcher/features/reports/providers/report_list_cubit.dart';
import 'package:kyber_launcher/features/reports/screens/report_view.dart';
import 'package:kyber_launcher/features/reports/screens/reports.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_list_cubit.dart';
import 'package:kyber_launcher/features/server_browser/screens/ingame_view.dart';
import 'package:kyber_launcher/features/server_browser/screens/server_browser.dart';
import 'package:kyber_launcher/features/server_host/providers/host_collection_cubit.dart';
import 'package:kyber_launcher/features/server_host/providers/host_search_cubit.dart';
import 'package:kyber_launcher/features/server_host/screens/server_host.dart';
import 'package:kyber_launcher/features/settings/screens/background_selector.dart';
import 'package:kyber_launcher/features/settings/screens/settings_list.dart';
import 'package:kyber_launcher/features/social/screens/social_home.dart';
import 'package:kyber_launcher/features/stats/providers/stats_cubit.dart';
import 'package:kyber_launcher/features/stats/screens/personal/stats_overview.dart';
import 'package:kyber_launcher/features/stats/screens/stats.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:uuid/uuid.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();
List<Uri> _previousUris = [];

void onUriChanged(Uri uri) {
  if (_previousUris.isEmpty) {
    _previousUris.add(uri);
    return;
  }

  if (_previousUris.last == uri) {
    return;
  }

  _previousUris.add(uri);
  if (_previousUris.length > 2) {
    _previousUris.removeAt(0);
  }
}

int _getRouterIndex(Uri? uri) {
  switch (uri?.toString()) {
    case '/home':
      return 0;
    case '/server_host':
      return 1;
    case '/stats':
      return 2;
    case '/mods':
      return 3;
    case '/settings':
      return 4;
    default:
      return 0;
  }
}

Page<void> buildCustomSubPage({
  required LocalKey pageKey,
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: pageKey,
    child: child,
    name: state.name,
    reverseTransitionDuration: const Duration(milliseconds: 150),
    transitionDuration: const Duration(milliseconds: 150),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(animation),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
        child: Builder(
          builder: (_) {
            var show = true;

            if (state.matchedLocation !=
                router.routerDelegate.currentConfiguration.last.matchedLocation
                    .split('?')
                    .first) {
              show = false;
            }

            return Opacity(
              opacity: show ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                ).copyWith(bottom: 20),
                child: child,
              ),
            );
          },
        ),
      ),
    ),
  );
}

Page<void> buildCustomPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage(
    child: child,
    key: state.pageKey,
    name: state.name,
    reverseTransitionDuration: Duration.zero,
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final previousRouterIndex = _getRouterIndex(_previousUris.firstOrNull);
      final currentRouterIndex = _getRouterIndex(state.uri);

      if (state.path !=
          router.routerDelegate.currentConfiguration.last.matchedLocation
              .split('?')
              .first) {
        if ('/'
                .allMatches(
                  router
                      .routerDelegate
                      .currentConfiguration
                      .last
                      .matchedLocation
                      .split('?')
                      .first,
                )
                .length >
            1) {
          return Opacity(opacity: 0, child: child);
        }

        return const SizedBox();
      }

      const offset = 0.03;
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: SlideTransition(
          position:
              Tween<Offset>(
                begin: Offset(
                  previousRouterIndex > currentRouterIndex
                      ? offset
                      : 0 - offset,
                  0,
                ),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.fastOutSlowIn,
                ),
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
            ).copyWith(bottom: 20),
            child: child,
          ),
        ),
      );
    },
  );
}

final router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/home',
  observers: [SentryNavigatorObserver()],
  errorBuilder: (context, state) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Page Not Found',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(state.error?.toString() ?? 'page not found'),
            const SizedBox(height: 16),
            Button(
              onPressed: () => context.go('/'),
              child: const Text(
                'Go to home page',
              ),
            ),
          ],
        ),
      ),
    );
  },
  routes: [
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) {
        return NavigationBar(
          shellContext: shellNavigatorKey.currentContext,
          state: state,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: '/',
          redirect: (context, state) => '/home',
        ),
        GoRoute(
          path: '/staff',
          name: 'staff',
          redirect: (context, state) {
            final user = context.read<MaximaCubit>().state;
            if (!user.isEntitled(UserEntitlement.staff)) {
              return '/home';
            }

            if (state.fullPath == '/staff') {
              return '/staff/reports';
            }

            return null;
          },
          routes: [
            GoRoute(
              path: '/reports',
              name: 'reports',
              pageBuilder: (context, state) => buildCustomSubPage(
                state: state,
                pageKey: state.pageKey,
                child: BlocProvider(
                  create: (_) => ReportsCubit(),
                  child: const Reports(),
                ),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  name: 'report',
                  pageBuilder: (context, state) => buildCustomSubPage(
                    state: state,
                    pageKey: state.pageKey,
                    child: ReportView(playerId: state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/social',
          pageBuilder: (_, state) =>
              buildCustomPage(child: const SocialHome(), state: state),
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          onExit: (context, state) {
            context.read<ServerListCubit>().clearSearch();
            return true;
          },
          pageBuilder: (context, state) {
            return buildCustomPage(
              state: state,
              child: const ServerBrowser(),
            );
          },
          routes: [
            GoRoute(
              parentNavigatorKey: shellNavigatorKey,
              path: 'debug-launch',
              name: 'debug-launch',
              pageBuilder: (context, state) => buildCustomSubPage(
                state: state,
                pageKey: state.pageKey,
                child: const DebugServerLauncher(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/server_host',
          name: 'server_host',
          redirect: (context, state) async {
            // temp fix
            await sl.isReady<ModService>();
          },
          pageBuilder: (context, state) {
            return buildCustomPage(
              state: state,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => HostCollectionCubit()),
                  BlocProvider(create: (_) => HostSearchCubit()),
                ],
                child: ServerHost(
                  initialPage: state.uri.queryParameters['page'] != null
                      ? int.tryParse(state.uri.queryParameters['page']!)
                      : null,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/stats',
          name: 'stats',
          pageBuilder: (context, state) => buildCustomPage(
            state: state,
            child: const StatsView(),
          ),
          routes: [
            GoRoute(
              parentNavigatorKey: shellNavigatorKey,
              path: ':id',
              name: 'user-stats',
              pageBuilder: (context, state) => buildCustomSubPage(
                pageKey: state.pageKey,
                state: state,
                child: BlocProvider(
                  create: (_) => StatsCubit(
                    username: state.pathParameters['id'],
                  ),
                  child: const UserStats(),
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/downloads',
          name: 'downloads',
          parentNavigatorKey: shellNavigatorKey,
          redirect: (context, state) =>
              state.fullPath == '/downloads' ? '/downloads/overview' : null,
          routes: [
            GoRoute(
              path: 'overview',
              name: 'overview',
              parentNavigatorKey: shellNavigatorKey,
              pageBuilder: (context, state) => buildCustomSubPage(
                state: state,
                pageKey: state.pageKey,
                child: const DownloadManager(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/mods',
          name: 'mods',
          onExit: (context, state) {
            //TODO: check for unsaved changes
            return true;
          },
          pageBuilder: (_, state) {
            return buildCustomPage(
              state: state,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(
                    create: (_) => ModCollectionCreatorCubit(),
                  ),
                  BlocProvider(
                    create: (_) => ModCollectionCubit(),
                  ),
                  BlocProvider(
                    create: (_) => ModSearchCubit(),
                  ),
                  BlocProvider(
                    create: (_) {
                      ModCollectionMetaData? collection;
                      final collectionQuery =
                          state.uri.queryParameters['collection'];
                      if (collectionQuery != null) {
                        if (collectionQuery == 'new') {
                          collection = ModCollectionMetaData(
                            localId: const Uuid().v4(),
                            title: 'New Collection',
                            mods: [],
                          );
                        } else {
                          collection = collectionBox.get(collectionQuery);
                        }
                      }

                      return CollectionEditorCubit(
                        initialCollection: collection,
                        editing: collectionQuery == 'new',
                      );
                    },
                  ),
                ],
                child: const ModsPage(),
              ),
            );
          },
          routes: [
            GoRoute(
              path: 'create_collection',
              name: 'create_collection',
              parentNavigatorKey: shellNavigatorKey,
              pageBuilder: (context, state) => buildCustomSubPage(
                state: state,
                pageKey: state.pageKey,
                child: const CreateFrostyCollection(),
              ),
            ),
            GoRoute(
              redirect: (context, state) =>
                  state.fullPath == '/mods/mod_browser' ? '/mods' : null,
              path: 'mod_browser',
              name: 'mod_browser',
              parentNavigatorKey: shellNavigatorKey,
              routes: [
                GoRoute(
                  path: 'users',
                  name: 'users',
                  parentNavigatorKey: shellNavigatorKey,
                  redirect: (context, state) =>
                      state.fullPath == '/mods/mod_browser/users'
                      ? '/mods/mod_browser'
                      : null,
                  routes: [
                    GoRoute(
                      path: ':id',
                      name: 'nexus_user',
                      pageBuilder: (context, state) => buildCustomSubPage(
                        state: state,
                        pageKey: state.pageKey,
                        child: NexusProfile(
                          userId: int.parse(state.pathParameters['id']!),
                        ),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: ':id',
                  name: 'mod_details',
                  parentNavigatorKey: shellNavigatorKey,
                  redirect: (context, state) {
                    if (int.tryParse(state.pathParameters['id']!) == null) {
                      return '/mods/mod_browser';
                    }

                    return null;
                  },
                  pageBuilder: (context, state) => buildCustomSubPage(
                    state: state,
                    pageKey: state.pageKey,
                    child: BlocProvider(
                      create: (_) => ModCubit(state.pathParameters['id']!),
                      child: ModInfo(id: state.pathParameters['id']!),
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: 'collection_import',
              name: 'collection_import',
              parentNavigatorKey: shellNavigatorKey,
              pageBuilder: (context, state) => buildCustomSubPage(
                state: state,
                pageKey: state.pageKey,
                child: CollectionImport(
                  collectionPath: state.uri.queryParameters['path']!,
                ),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => buildCustomPage(
            state: state,
            child: SettingsList(
              initialIndex: state.uri.queryParameters['index'] != null
                  ? int.tryParse(state.uri.queryParameters['index']!)
                  : null,
            ),
          ),
          routes: [
            GoRoute(
              path: 'backgrounds',
              name: 'backgrounds',
              pageBuilder: (context, state) => buildCustomSubPage(
                state: state,
                pageKey: state.pageKey,
                child: const BackgroundSelector(),
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/ingame',
          name: 'ingame',
          pageBuilder: (context, state) => buildCustomPage(
            state: state,
            child: const IngameView(),
          ),
        ),
      ],
    ),
  ],
);
