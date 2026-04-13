import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/reports/dialogs/report_player_dialog.dart';
import 'package:kyber_launcher/features/server_browser/providers/ingame_view_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/layout/bordered_content.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class IngameView extends StatefulWidget {
  const IngameView({super.key});

  @override
  State<IngameView> createState() => _IngameViewState();
}

class _IngameViewState extends State<IngameView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return BlocBuilder<IngameViewCubit, IngameViewState>(
      builder: (context, state) {
        return BorderedContent(
          header: Row(
            mainAxisAlignment: .spaceBetween,
            children: [
              Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    state.server?.name ?? l10n.unknownServer,
                    style: TextStyle(
                      fontFamily: currentFont,
                      fontSize: 20,
                      height: 1,
                    ),
                  ),
                  if (state.server != null && state.server!.official)
                    Text(
                      l10n.hostedBy(state.server?.creator ?? l10n.unknownServer),
                      style: const TextStyle(
                        fontSize: 12,
                        color: kWhiteColor,
                        height: 1,
                      ),
                    ),
                ],
              ),
              KyberTooltip(
                message: l10n.backToServerBrowser.toUpperCase(),
                child: KyberIconButton(
                  onPressed: router.pop,
                  iconData: mt.Icons.close,
                  size: 19,
                ),
              ),
            ],
          ),
          content: Column(
            children: [
              KyberHeader(
                sections: [
                  ExpandedHeaderSection(
                    children: [Text(l10n.eventLog.toUpperCase())],
                  ),
                  ExpandedHeaderSection(
                    children: [Text(l10n.lightSide.toUpperCase())],
                  ),
                  ExpandedHeaderSection(
                    children: [Text(l10n.darkSide.toUpperCase())],
                  ),
                ],
              ),
              const ContainerSeparator(),
              const Expanded(
                child: Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    Expanded(child: _Console()),
                    ContainerSeparatorH(),
                    Expanded(child: _TeamContainer(teamId: 1)),
                    ContainerSeparatorH(),
                    Expanded(child: _TeamContainer(teamId: 2)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Console extends StatefulWidget {
  const _Console();

  @override
  State<_Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<_Console> {
  final controller = TextEditingController();
  final FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<IngameViewCubit, IngameViewState>(
      builder: (context, state) {
        return SingleChildScrollView(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: state.commands.map((item) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text.rich(
                    formatText(item),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  TextSpan formatText(String text) {
    final spans = <TextSpan>[];

    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    final strikeThroughRegex = RegExp('~~(.*?)~~');

    final boldMatches = boldRegex.allMatches(text);
    final strikeMatches = strikeThroughRegex.allMatches(text);
    var currentIndex = 0;

    const defaultStyle = TextStyle(
      fontFamily: FontFamily.iBMPlexMono,
      fontSize: 12,
    );

    while (currentIndex < text.length) {
      final boldMatch = boldMatches.isNotEmpty ? boldMatches.first : null;
      final strikeMatch = strikeMatches.isNotEmpty ? strikeMatches.first : null;

      if (boldMatch != null && boldMatch.start == currentIndex) {
        spans.add(
          TextSpan(
            text: boldMatch.group(1),
            style: defaultStyle.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        currentIndex = boldMatch.end;
      } else if (strikeMatch != null && strikeMatch.start == currentIndex) {
        spans.add(
          TextSpan(
            text: strikeMatch.group(1),
            style: defaultStyle.copyWith(
              decoration: TextDecoration.lineThrough,
            ),
          ),
        );
        currentIndex = strikeMatch.end;
      } else {
        spans.add(
          TextSpan(
            text: text[currentIndex],
            style: defaultStyle,
          ),
        );
        currentIndex++;
      }
    }

    return TextSpan(
      children: spans,
    );
  }
}

class _TeamContainer extends StatefulWidget {
  const _TeamContainer({required this.teamId});

  final int teamId;

  @override
  State<_TeamContainer> createState() => _TeamContainerState();
}

class _TeamContainerState extends State<_TeamContainer> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return BlocBuilder<IngameViewCubit, IngameViewState>(
      builder: (context, state) {
        final players = state.players
            .where((element) => element.teamId == widget.teamId)
            .toList();
        return SuperListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          itemBuilder: (context, index) {
            final player = players.elementAt(index);
            return HoverBuilder(
              builder: (context, hovered) {
                return AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: TextStyle(
                    color: hovered ? Colors.black : Colors.white,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: hovered
                          ? const Color(0xFFD9D9D9)
                          : index.isEven
                          ? const Color(0xFFD9D9D9).withOpacity(.1)
                          : const Color(0xFFD9D9D9).withOpacity(.2),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          player.name,
                          style: TextStyle(
                            fontFamily: currentFont,
                            fontSize: 18,
                          ),
                        ),
                        Row(
                          children: [
                            AnimatedOpacity(
                              opacity: hovered ? 1 : 0,
                              duration: const Duration(milliseconds: 100),
                              curve: Curves.easeOut,
                              child: Row(
                                children: [
                                  KyberTooltip(
                                    message: l10n.reportPlayer.toUpperCase(),
                                    child: CustomIconButton(
                                      onPressed: () => showKyberDialog(
                                        context: context,
                                        builder: (_) => ReportPlayerDialog(
                                          targetPlayer: player,
                                        ),
                                      ),
                                      iconData: mt.Icons.report,
                                      hoverColor: Colors.black,
                                      color: hovered ? kButtonBorder : null,
                                      size: 19,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          separatorBuilder: (context, index) {
            return const Divider();
          },
          itemCount: players.length,
        );
      },
    );
  }
}