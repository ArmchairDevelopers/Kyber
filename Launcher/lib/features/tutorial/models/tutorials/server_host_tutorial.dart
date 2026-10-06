import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/tutorial/models/tutorials/tutorial_class.dart';

class ServerHostTutorial implements Tutorial {
  @override
  List<TutorialStep> steps = [
    TutorialStep(
      id: 'serverSettings',
      title: 'Server Settings',
      before: () async {
        //BlocProvider.of<ServerBrowserCubit>(navigatorKey.currentContext!).clearServer();
      },
      description: const Text(
        'This is the server browser. Here you can find all server you can join.',
      ),
    ),
    TutorialStep(
      id: 'mapRotation',
      title: 'Map Rotation',
      description: const Text(
        'This is your current map rotation. You can drag and drop maps to change the order. You can also add and remove maps on the right side.',
      ),
    ),
    TutorialStep(
      id: 'modCollections',
      title: 'Mod Collections',
      description: const Text(
        'To select your mods, you have to select a mod collection here.',
      ),
      before: () async {
        final server = SingleServer(server: KyberExampleServer());
        BlocProvider.of<ServerBrowserCubit>(
          navigatorKey.currentContext!,
        ).selectServer(server);
        await Future.delayed(const Duration(milliseconds: 50));
      },
    ),
    TutorialStep(
      id: 'modCollectionList',
      title: 'Your Mod Collections',
      description: const Text(
        'Here you can see all your mod collections. To select a mod collection, click on it.',
      ),
    ),
  ];

  static GlobalKey serverSettingsKey = const GlobalObjectKey('serverSettings');
  static GlobalKey mapRotationKey = const GlobalObjectKey('mapRotation');
  static GlobalKey modCollectionsKey = const GlobalObjectKey('modCollections');
  static GlobalKey modCollectionListKey = const GlobalObjectKey(
    'modCollectionList',
  );
}
