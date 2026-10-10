import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/tutorial/models/tutorials/tutorial_class.dart';

class ServerBrowserTutorial implements Tutorial {
  @override
  List<TutorialStep> steps = [
    TutorialStep(
      id: 'serverList',
      title: 'Server Browser',
      before: () async {
        //BlocProvider.of<ServerBrowserCubit>(navigatorKey.currentContext!).clearServer();
      },
      description: const Text(
        'This is the server browser. Here you can find all server you can join.',
      ),
    ),
    TutorialStep(
      id: 'serverInfo',
      title: 'Server Info',
      description: const Text(
        'This is the server browser. Here you can find all server you can join. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla ne',
      ),
    ),
    TutorialStep(
      id: 'serverInfoBox',
      title: 'Server Info Box',
      description: const Text(
        'This is the server info box. Info Info Info About The Server And Stuff',
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
      id: 'serverInfoMods',
      title: 'Required Server Mods',
      description: const Text(
        'Mods required to join the server. You can download them by clicking the download button. Sometimes you have install mods manually because they are not available to install automatically.',
      ),
    ),
  ];

  static GlobalKey serverListKey = const GlobalObjectKey('serverList');
  static GlobalKey serverInfoKey = const GlobalObjectKey('serverInfo');
  static GlobalKey serverInfoBoxKey = const GlobalObjectKey('serverInfoBox');
  static GlobalKey serverInfoModsKey = const GlobalObjectKey('serverInfoMods');
}
