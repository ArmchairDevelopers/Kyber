import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/features/kyber/models/maps.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/models/modes.dart';
import 'package:kyber_launcher/features/server_browser/models/server_list_state.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_list_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/entry.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list_header.dart';
import 'package:kyber_launcher/features/tutorial/models/tutorials/server_browser_tutorial.dart';
import 'package:kyber_launcher/features/tutorial/providers/tutorial_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class TableServerList extends StatefulWidget {
  const TableServerList({super.key});

  @override
  State<TableServerList> createState() => _TableServerListState();
}

class _TableServerListState extends State<TableServerList> {
  int? hoverIndex;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ServerListHeader(),
        Expanded(
          child: FadeIn(
            curve: Curves.easeOut,
            duration: const Duration(milliseconds: 100),
            child: BlocBuilder<ServerListCubit, ServerListState>(
              builder: (_, state) => BlocBuilder<TutorialCubit, TutorialState>(
                builder: (_, tState) {
                  state as ServerListLoaded;
                  final servers = state.servers;

                  final tutorialActive =
                      tState is TutorialActive &&
                      tState.tutorial is ServerBrowserTutorial;

                  if (servers.isEmpty && !tutorialActive) {
                    return Center(
                      child: Text(
                        'No servers found',
                        style: FluentTheme.of(context).typography.subtitle
                            ?.copyWith(
                              fontFamily: FontFamily.battlefrontUI,
                            ),
                      ),
                    );
                  }

                  return FadeIn(
                    duration: const Duration(milliseconds: 150),
                    child: SuperListView.builder(
                      itemBuilder: (context, index) {
                        if (index == 0 ||
                            index ==
                                (tutorialActive ? 2 : servers.length + 1)) {
                          return const SizedBox.shrink();
                        }

                        if (tutorialActive) {
                          return SizedBox(
                            key: ServerBrowserTutorial.serverListKey,
                            child: ServerListEntry.fromServer(
                              key: ServerBrowserTutorial.serverInfoKey,
                              hoveredIndex: hoverIndex ?? -1,
                              onHover: (value) {
                                setState(
                                  () => hoverIndex = value ? index : null,
                                );
                              },
                              server: KyberExampleServer(),
                            ),
                          );
                        }

                        final server = servers[index - 1];
                        final serverInfo = server.serverInfo;
                        final mode =
                            modes
                                .where(
                                  (element) =>
                                      element.mode ==
                                      serverInfo.levelSetup.mode,
                                )
                                .firstOrNull ??
                            Mode.customMode();
                        final map = mode.maps.isEmpty
                            ? maps.first
                            : maps.firstWhereOrNull(
                                    (element) =>
                                        element['map'] ==
                                        serverInfo.levelSetup.map,
                                  ) ??
                                  maps.first;

                        return ServerListEntry(
                          server: server,
                          index: index - 1,
                          isLast: index == servers.length,
                          hoveredIndex: hoverIndex ?? -1,
                          onHover: (value) {
                            setState(() => hoverIndex = value ? index : null);
                          },
                          mode: mode,
                          map: map,
                        );
                      },
                      itemCount: tutorialActive
                          ? 3
                          : servers.isEmpty
                          ? 0
                          : servers.length + 1,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
