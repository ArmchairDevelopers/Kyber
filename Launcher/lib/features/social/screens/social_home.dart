import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/reports/dialogs/report_player_dialog.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list_header.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:rxdart/rxdart.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class SocialHome extends StatefulWidget {
  const SocialHome({super.key});

  @override
  State<SocialHome> createState() => _SocialHomeState();
}

class _SocialHomeState extends State<SocialHome> {
  final BehaviorSubject<String> _searchQuery = BehaviorSubject<String>();
  List<KyberPlayer>? searchResults;

  @override
  void initState() {
    _searchQuery.debounceTime(const Duration(milliseconds: 100)).listen((
      query,
    ) async {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;

      if (query.isEmpty) {
        setState(() {
          searchResults = null;
        });
        return;
      }

      try {
        final results = await sl.get<KyberGRPCService>().statsClient.searchUser(
          StatsSearchRequest(query: query),
        );
        setState(() {
          searchResults = results.users
              .where((e) => e.isKyberUser)
              .map((e) => KyberPlayer(id: e.id, name: e.username))
              .toList(growable: false);
        });
      } on GrpcError catch (e) {
        NotificationService.error(
          message: l10n.searchFailed(e.message ?? ''),
        );
      } catch (e) {
        NotificationService.error(message: l10n.unexpectedError(e.toString()));
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _searchQuery.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Row(
      spacing: 15,
      children: [
        Expanded(
          flex: 5,
          child: KyberCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SizedBox(
                  height: 65,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 14,
                    ),
                    child: Align(
                      child: SizedBox(
                        child: Row(
                          spacing: 10,
                          children: [
                            Container(
                              height: 45,
                              decoration: BoxDecoration(
                                border: kDefaultAllBorder,
                                borderRadius: BorderRadius.circular(
                                  kDefaultInnerBorderRadius,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  kDefaultInnerBorderRadius - 2,
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: context
                                      .read<MaximaCubit>()
                                      .state
                                      .servicePlayer!
                                      .avatar!
                                      .large
                                      .path,
                                  fadeInDuration: Duration.zero,
                                ),
                              ),
                            ),
                            Text(
                              context
                                  .read<MaximaCubit>()
                                  .state
                                  .servicePlayer!
                                  .displayName,
                              style: TextStyle(
                                fontSize: 18,
                                fontFamily: currentFont,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: KyberInput(
                                placeholder: l10n.searchKyberUser,
                                onChanged: _searchQuery.add,
                              ),
                            ),
                            KyberIconButton(
                              onPressed: () {},
                              iconData: mt.Icons.settings,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const CardSection(),
                if (searchResults != null && searchResults!.isNotEmpty)
                  Expanded(
                    child: SuperListView.separated(
                      itemCount: searchResults!.length + 1,
                      separatorBuilder: (context, index) =>
                          const ContainerSeparator(),
                      itemBuilder: (context, index) {
                        if (index == searchResults!.length) {
                          return const SizedBox.shrink();
                        }

                        return ButtonBuilder(
                          onClick: () {
                            showKyberDialog(
                              context: context,
                              builder: (_) => ReportPlayerDialog(
                                targetPlayer: ServerPlayer(
                                  name: searchResults![index].name,
                                  id: searchResults![index].id,
                                ),
                              ),
                            );
                          },
                          builder: (context, hovered) {
                            return Container(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 150),
                                style: TextStyle(
                                  fontFamily: currentFont,
                                  color: hovered ? kActiveColor : kWhiteColor,
                                ),
                                child: Container(
                                  height: 45,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          searchResults![index].name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontFamily: currentFont,
                                          ),
                                        ),
                                      ),
                                      KyberIconButton(
                                        onPressed: () {
                                          showKyberDialog(
                                            context: context,
                                            builder: (_) => ReportPlayerDialog(
                                              targetPlayer: ServerPlayer(
                                                name:
                                                    searchResults![index].name,
                                                id: searchResults![index].id,
                                              ),
                                            ),
                                          );
                                        },
                                        iconData: mt.Icons.report,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                else if (searchResults != null && searchResults!.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      l10n.noResultsFound(_searchQuery.value),
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: currentFont,
                        color: kInactiveColor,
                      ),
                    ),
                  )
                else
                  Expanded(
                    // TODO: convert this to a sliver list
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _Expandable(
                            initialExpanded: true,
                            logo: Assets.logos.eaPlay.svg(),
                            title: l10n.friendsCount(
                              context.read<MaximaRtmCubit>().state.friends.length,
                            ),
                            players: context
                                .read<MaximaRtmCubit>()
                                .state
                                .getSortedPlayers(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 400,
          child: KyberCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SizedBox(
                  height: 65,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        child: Column(
                          spacing: 2,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.recentlyViewed,
                              style: TextStyle(
                                fontSize: 20,
                                fontFamily: currentFont,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                            Text(
                              l10n.userSearchHistory,
                              style: TextStyle(
                                fontSize: 15,
                                fontFamily: currentFont,
                                color: kInactiveColor,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const CardSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Expandable extends StatefulWidget {
  const _Expandable({
    required this.title,
    required this.logo,
    required this.players,
    this.initialExpanded = false,
  });

  final Widget logo;
  final String title;
  final bool initialExpanded;
  final List<ServicePlayer> players;

  @override
  State<_Expandable> createState() => _ExpandableState();
}

class _ExpandableState extends State<_Expandable> {
  late bool _expanded;

  @override
  void initState() {
    _expanded = widget.initialExpanded;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      children: [
        ColoredBox(
          color: Colors.black.withOpacity(.7),
          child: ButtonBuilder(
            onClick: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            builder: (context, hovered) {
              return AbsorbPointer(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: hovered ? kActiveColor : kInactiveColor,
                    shadows: hovered
                        ? [
                            Shadow(
                              color: kActiveColor.withOpacity(.4),
                              blurRadius: 5,
                            ),
                          ]
                        : null,
                  ),
                  child: SizedBox(
                    height: 40,
                    child: Row(
                      children: [
                        Container(
                          width: 45,
                          padding: const EdgeInsets.all(8),
                          child: widget.logo,
                        ),
                        CustomPaint(
                          size: const Size(2, 40),
                          painter: DashedLineVerticalPainter(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2.5,
                            ),
                            child: Text(
                              widget.title.toUpperCase(),
                              style: TextStyle(
                                fontFamily: currentFont,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const VCardSection(),
                        const SizedBox(width: 10),
                        Icon(
                          _expanded
                              ? mt.Icons.arrow_drop_up
                              : mt.Icons.arrow_drop_down,
                          color: hovered ? kActiveColor : kInactiveColor,
                          size: 25,
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const ContainerSeparator(),
        if (_expanded)
          ColoredBox(
            color: Colors.black.withOpacity(.4),
            child: SuperListView.separated(
              itemBuilder: (context, index) {
                if (index == widget.players.length) {
                  return const SizedBox.shrink();
                }

                final player = widget.players[index];
                final presence = context
                    .read<MaximaRtmCubit>()
                    .state
                    .presences[player.id];
                var isOnline = false;
                if (presence != null &&
                    presence.basic != BasicPresence.offline) {
                  isOnline = true;
                }

                var statusText = '';
                if (isOnline) {
                  if (presence!.status.isEmpty) {
                    statusText = l10n.online;
                  } else {
                    statusText = l10n.playingStatus(presence.status);
                  }
                }

                return ButtonBuilder(
                  onClick: () {
                    //showKyberDialog(context: context, builder: (_) => FileDownloadDialog(file: file, modId: file.modId.toString()));
                  },
                  builder: (context, hovered) {
                    return AbsorbPointer(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 150),
                        style: TextStyle(
                          fontFamily: currentFont,
                          color: hovered ? kActiveColor : kWhiteColor,
                        ),
                        child: SizedBox(
                          height: 45,
                          child: Row(
                            children: [
                              if (player.avatar != null) ...[
                                CachedNetworkImage(
                                  imageUrl: player.avatar!.medium.path,
                                  height: 45,
                                  width: 45,
                                  fadeInDuration: Duration.zero,
                                ),
                                const VCardSection(),
                              ],
                              const SizedBox(width: 10),
                              Text(
                                player.displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontFamily: currentFont,
                                  color:
                                      presence?.basic ==
                                              BasicPresence.offline ||
                                          presence == null &&
                                              player.relationship != 'KYBER'
                                      ? kInactiveColor.withOpacity(.5)
                                      : kWhiteColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(statusText),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) => const ContainerSeparator(),
              padding: EdgeInsets.zero,
              itemCount: widget.players.length + 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ),
      ],
    );
  }
}