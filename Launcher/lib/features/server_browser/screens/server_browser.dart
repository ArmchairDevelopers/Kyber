import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_status_helper.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_api_status_cubit.dart';
import 'package:kyber_launcher/features/lightswitch/models/status.dart';
import 'package:kyber_launcher/features/server_browser/constants/modes.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';
import 'package:kyber_launcher/features/server_browser/models/server_list_state.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_list_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/event_list.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_info_box/server_info_box.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/elements/filter_dropdown.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_page_selector.dart';
import 'package:kyber_launcher/shared/ui/layout/bordered_content.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class ServerBrowser extends StatefulWidget {
  const ServerBrowser({super.key});

  @override
  State<ServerBrowser> createState() => _ServerBrowserState();
}

class _ServerBrowserState extends State<ServerBrowser> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 15,
      crossAxisAlignment: .start,
      children: [
        Expanded(
          flex: 6,
          child: BorderedContent(
            overlappingBorder: true,
            header: BlocListener<ServerListCubit, ServerListState>(
              listener: (context, state) {
                state as ServerListLoaded;

                final selectedServer = context
                    .read<ServerBrowserCubit>()
                    .state
                    .selectedServer;
                if (selectedServer == null) {
                  return;
                }

                final serverId = selectedServer.serverInfo.id;
                final stillPresent = state.servers.any(
                  (s) => s is ServerGroup
                      ? (s as ServerGroup).servers.any(
                          (i) => i.id == serverId,
                        )
                      : s.serverInfo.id == serverId,
                );

                if (!stillPresent) {
                  context.read<ServerBrowserCubit>().clearServer();
                }
              },
              listenWhen: (previous, current) => current is ServerListLoaded,
              child: const _HeaderBar(),
            ),
            content: const ServerListWidget(
              key: Key('server_list'),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            children: [
              const _StatusWidget(),
              BlocBuilder<ServerBrowserCubit, ServerBrowserState>(
                builder: (context, state) {
                  if (state.selectedServer != null) {
                    return Expanded(
                      child: ServerInfoBox(
                        server: state.selectedServer!,
                      ),
                    );
                  }

                  return const HomeEventList();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      child: SizedBox(
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: KyberTabBar(
                tabs: [
                  SizedBox(
                    height: 17,
                    child: Assets.icons.kblSwap.svg(
                      color: kWhiteColor,
                    ),
                  ),
                ],
                onChanged: (value) =>
                    context.read<ServerListCubit>().loadServers(),
                selectedIndex: -1,
              ),
            ),
            const SizedBox(width: 15),
            const Expanded(
              flex: 2,
              child: _FilterDropdown(),
            ),
            const SizedBox(width: 15),
            BlocBuilder<ServerListCubit, ServerListState>(
              builder: (context, state) => SizedBox(
                height: 35,
                width: 110,
                child: KyberPageSelector(
                  current: state.page ?? 0,
                  total: state.pages ?? 0,
                  onPageChanged: context.read<ServerListCubit>().goToPage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return KyberSearchFilterDropdown(
      onSearchChanged: (value) {
        final filter = context.read<ServerListCubit>().filter;

        context.read<ServerListCubit>().setFilter(
          filter.copyWith(query: value),
        );
      },
      dropdownContent: BlocBuilder<ServerListCubit, ServerListState>(
        builder: (context, state) {
          final cubit = context.read<ServerListCubit>();
          return SuperListView(
            children: [
              KyberFilterSection<ServerRegion>(
                title: 'REGION',
                selectedItems: [cubit.filter.region],
                items: toSelectorItems(
                  ServerRegion.values,
                  title: (e) => e.displayName,
                ),
                onChanged: (selected) {
                  cubit.setFilter(
                    cubit.filter.copyWith(region: selected.firstOrNull),
                  );
                },
              ),
              KyberFilterSection<ServerType>(
                title: 'SERVER TYPE',
                selectedItems: [cubit.filter.type],
                items: toSelectorItems(
                  ServerType.values,
                  title: (e) => e.name,
                ),
                onChanged: (selected) {
                  cubit.setFilter(
                    cubit.filter.copyWith(type: selected.firstOrNull),
                  );
                },
              ),
              KyberFilterSection<GameType>(
                title: 'GAME TYPE',
                selectedItems: [cubit.filter.gameType],
                items: toSelectorItems(
                  GameType.values,
                  title: (e) => e.name,
                ),
                onChanged: (selected) {
                  cubit.setFilter(
                    cubit.filter.copyWith(gameType: selected.firstOrNull),
                  );
                },
              ),
              KyberFilterSection<String>(
                title: 'GAME MODE',
                selectedItems: cubit.filter.modes,
                includeAll: true,
                items: toSelectorItems(
                  filterModes.map((e) => e.$1),
                  title: (e) => e,
                ),
                onChanged: (selected) {
                  cubit.setFilter(
                    cubit.filter.copyWith(modes: selected),
                  );
                },
                spacing: 120,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusWidget extends StatelessWidget {
  const _StatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LightswitchCubit, LightswitchStatus>(
      builder: (context, apiState) {
        if (apiState.status != KyberStatusEnum.warning) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const .only(bottom: 20),
          child: KyberCard(
            padding: .zero,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                SizedBox(
                  height: 45,
                  child: Padding(
                    padding: const .symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisAlignment: .center,
                      children: [
                        Text(
                          'WARNING',
                          style: .new(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 21,
                            color: kDefaultActiveColor,
                            shadows: [
                              Shadow(
                                color: kDefaultActiveColor.withOpacity(0.55),
                                offset: const Offset(0, 1),
                                blurRadius: 20,
                              ),
                            ],
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const CardSection(),
                Padding(
                  padding: const .symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          apiState.message ?? 'Warning message not available.',
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 15,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
