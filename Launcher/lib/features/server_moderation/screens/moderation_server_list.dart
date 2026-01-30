import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/kyber/models/maps.dart';
import 'package:kyber_launcher/features/kyber/models/mode.dart';
import 'package:kyber_launcher/features/kyber/models/modes.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/entry.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_servers_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:tinycolor2/tinycolor2.dart';

class ModerationServerList extends StatefulWidget {
  const ModerationServerList({super.key});

  @override
  State<ModerationServerList> createState() => _ModerationServerListState();
}

class _ModerationServerListState extends State<ModerationServerList> {
  List<Server> servers = [];
  int? hoverIndex;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      children: [
        Expanded(
          child: BlocBuilder<ModerationServersCubit, ModerationServersState>(
            builder: (context, state) {
              if (state is ModerationServersLoading) {
                return const Column(
                  children: [
                    _Header(),
                    Expanded(child: Center(child: ProgressBar())),
                  ],
                );
              }

              if (state is ModerationServersLoaded) {
                return Column(
                  children: [
                    const _Header(),
                    Expanded(
                      child: FadeIn(
                        curve: Curves.easeOut,
                        duration: const Duration(milliseconds: 100),
                        child: Builder(
                          builder: (_) {
                            final servers = state.servers;

                            if (servers.isEmpty) {
                              return Center(
                                child: StrokeText(
                                  l10n.noServersFound.toUpperCase(),
                                  color: kWhiteColor,
                                  fontWeight: FontWeight.w500,
                                  strokeColor: kWhiteBackgroundColor.darken(20),
                                  fontSize: 21,
                                  strokeWidth: 2,
                                ),
                              );
                            }

                            return SuperListView.builder(
                              shrinkWrap: true,
                              itemBuilder: (context, index) {
                                if (index == 0 || index == servers.length + 1) {
                                  return const SizedBox.shrink();
                                }

                                final server = servers[index - 1];
                                final mode =
                                    modes
                                        .where(
                                          (element) =>
                                              element.mode ==
                                              server.levelSetup.mode,
                                        )
                                        .firstOrNull ??
                                    Mode.customMode();
                                final map = mode.maps.isEmpty
                                    ? maps.first
                                    : maps.firstWhereOrNull(
                                            (element) =>
                                                element['map'] ==
                                                server.levelSetup.map,
                                          ) ??
                                          maps.first;

                                return ServerListEntry(
                                  server: server,
                                  index: index - 1,
                                  hoveredIndex: hoverIndex ?? -1,
                                  isLast: index == servers.length,
                                  withoutQuickJoin: true,
                                  onClick: () => context
                                      .read<ModerationCubit>()
                                      .loadServer(server),
                                  onHover: (value) => setState(
                                    () => hoverIndex = value ? index : null,
                                  ),
                                  mode: mode,
                                  map: map,
                                );
                              },
                              itemCount: servers.length + 1,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              }

              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border.symmetric(
          vertical: BorderSide(
            color: decoColor,
            width: 2,
          ),
        ),
      ),
      child: KyberHeader(
        title: l10n.serverBrowser,
        headerLength: 150,
        sections: const [
          ExpandedHeaderSection(
            children: [],
          ),
        ],
      ),
    );
  }
}