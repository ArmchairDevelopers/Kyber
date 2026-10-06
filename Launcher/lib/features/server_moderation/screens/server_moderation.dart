import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart';
import 'package:intl/intl.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_server_helper.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/join_server_dialog.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/widgets/server_list/server_list_header.dart';
import 'package:kyber_launcher/features/server_moderation/dialogs/moderation_ban_dialog.dart';
import 'package:kyber_launcher/features/server_moderation/dialogs/moderation_input_dialog.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:logging/logging.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:tinycolor2/tinycolor2.dart';

class ServerModeration extends StatefulWidget {
  const ServerModeration({required this.selectedPage, super.key});

  final int selectedPage;

  @override
  State<ServerModeration> createState() => _ServerModerationState();
}

class _ServerModerationState extends State<ServerModeration> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModerationCubit, ModerationServerState>(
      builder: (context, state) {
        if (state.id == null) {
          return const Placeholder();
        }

        if (widget.selectedPage == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KyberHeader(
                sections: [
                  FixedWidthHeaderSection(
                    width: 131,
                    children: [
                      const SizedBox(width: 10),
                      Text('OPTIONS'.toUpperCase()),
                    ],
                  ),
                  ExpandedHeaderSection(
                    children: [Text('MODERATORS'.toUpperCase())],
                  ),
                  ExpandedHeaderSection(
                    children: [Text('BANNED PLAYERS'.toUpperCase())],
                  ),
                ],
              ),
              const ContainerSeparator(),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              spacing: 15,
                              children: [
                                KyberButton(
                                  text: 'PLAY',
                                  onPressed: () async {
                                    if (state.server == null) return;

                                    final sessionState = context
                                        .read<SessionCubit>()
                                        .state;
                                    if (sessionState is InParty) {
                                      if (!sessionState.isLeader()) {
                                        NotificationService.warning(
                                          message:
                                              'Only the party leader can join a server!',
                                        );
                                        return;
                                      }
                                      try {
                                        await context
                                            .read<SessionCubit>()
                                            .startJoinGame(
                                              serverId: state.server!.id,
                                            );
                                      } catch (e) {
                                        NotificationService.error(
                                          message:
                                              'Failed to start party join: $e',
                                        );
                                      }
                                      return;
                                    }

                                    final result =
                                        await showKyberDialog<
                                          JoinDialogResult?
                                        >(
                                          context: context,
                                          builder: (_) => CosmeticModsDialog(
                                            server: SingleServer(
                                              server: state.server!,
                                            ),
                                            skipPasswordCheck: true,
                                          ),
                                        );

                                    if (result == null) {
                                      return;
                                    }

                                    final server = state.server!;
                                    await KyberServerHelper.joinServer(
                                      server,
                                      selectedCollection: result.collection,
                                      spectator: result.spectator,
                                      password: result.password,
                                    );
                                  },
                                ),
                                KyberButton(
                                  text: 'SPECTATE',
                                  onPressed: () {
                                    if (context.read<SessionCubit>().state
                                        is InParty) {
                                      NotificationService.warning(
                                        message:
                                            'You cannot spectate while in a party!',
                                      );
                                      return;
                                    }
                                    KyberServerHelper.joinServer(
                                      state.server!,
                                      spectator: true,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const CardSection(),
                          Padding(
                            padding: const .all(10),
                            child: Column(
                              children: [
                                KyberButton(
                                  text: 'COPY LINK',
                                  onPressed: () {
                                    final uri = Uri(
                                      scheme: 'https',
                                      host: 'api.prod.kyber.gg',
                                      path: 'redirect',
                                      queryParameters: {
                                        'target':
                                            'join_server?server_id=${state.server?.id}',
                                      },
                                    );
                                    Clipboard.setData(
                                      .new(text: uri.toString()),
                                    );
                                    NotificationService.info(
                                      message: 'Copied to clipboard!',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const CardSection(),
                          const Padding(
                            padding: EdgeInsets.all(10),
                            child: Column(
                              spacing: 15,
                              children: [
                                NormalButton(
                                  label: Text('EXPORT BANS'),
                                  onPressed: NotificationService.notImplemented,
                                ),
                                NormalButton(
                                  label: Text('IMPORT BANS'),
                                  onPressed: NotificationService.notImplemented,
                                ),
                                NormalButton(
                                  label: Text('KICK ALL'),
                                  onPressed: NotificationService.notImplemented,
                                ),
                                NormalButton(
                                  label: Text(
                                    'BAN ALL',
                                    textAlign: TextAlign.center,
                                  ),
                                  onPressed: NotificationService.notImplemented,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const ContainerSeparatorH(),
                    const Expanded(child: _ModeratorContainer()),
                    const ContainerSeparatorH(),
                    const Expanded(child: _PunishmentContainer()),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KyberHeader(
              sections: [
                ExpandedHeaderSection(
                  children: [Text('Event Log'.toUpperCase())],
                ),
                ExpandedHeaderSection(
                  children: [Text('Light Side'.toUpperCase())],
                ),
                ExpandedHeaderSection(
                  children: [Text('Dark Side'.toUpperCase())],
                ),
              ],
            ),
            const ContainerSeparator(),
            const Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
        );
      },
    );
  }
}

class _UserManager extends StatefulWidget {
  const _UserManager();

  @override
  State<_UserManager> createState() => _UserManagerState();
}

class _UserManagerState extends State<_UserManager> {
  @override
  Widget build(BuildContext context) {
    return KyberEventContainer(
      child: Text(
        'User Manager'.toUpperCase(),
        style: const TextStyle(
          fontFamily: FontFamily.battlefrontUI,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
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
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<ModerationCubit, ModerationServerState>(
            builder: (context, state) {
              return SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
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
          ),
        ),
        Container(
          padding: const EdgeInsets.all(15),
          child: mt.TextFormField(
            controller: controller,
            style: const TextStyle(
              color: kWhiteColor,
              fontFamily: FontFamily.battlefrontUI,
              height: 1.5,
            ),
            maxLines: 4,
            minLines: 1,
            decoration: const mt.InputDecoration(
              hintText: '/COMMAND OR SEND MESSAGE',
              hintStyle: TextStyle(
                fontSize: 14,
                height: 1,
                color: kWhiteColor,
                fontFamily: FontFamily.battlefrontUI,
              ),
              isDense: true,
              enabledBorder: mt.OutlineInputBorder(
                borderSide: BorderSide(color: kGrayColor, width: 2),
                borderRadius: BorderRadius.all(
                  Radius.circular(kDefaultInnerBorderRadius),
                ),
              ),
              focusedBorder: mt.OutlineInputBorder(
                borderSide: BorderSide(color: kWhiteColor, width: 2),
                borderRadius: BorderRadius.all(
                  Radius.circular(kDefaultInnerBorderRadius),
                ),
              ),
              //suffixIcon: Padding(
              //  padding: const EdgeInsets.all(10),
              //  child: CustomSvgButton(
              //    onPressed: () {
              //      if (controller.text.isEmpty) {
              //        return;
              //      }
              //      context.read<ModerationCubit>().sendCommand(controller.text);
              //      controller.clear();
              //    },
              //    path: Assets.icons.kblSend.path,
              //    size: 12,
              //  ),
              //),
            ),
            focusNode: focusNode,
            textInputAction: TextInputAction.send,
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null,
            maxLength: controller.text.startsWith('/') ? null : 127,
            onChanged: (value) {
              setState(() {});
            },
            onFieldSubmitted: (value) {
              if (value.isEmpty) {
                return;
              }

              context.read<ModerationCubit>().sendCommand(value);
              controller.clear();
              focusNode.requestFocus();
            },
          ),
        ),
      ],
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

class _ModeratorContainer extends StatefulWidget {
  const _ModeratorContainer();

  @override
  State<_ModeratorContainer> createState() => _ModeratorContainerState();
}

class _PunishmentContainer extends StatefulWidget {
  const _PunishmentContainer();

  @override
  State<_PunishmentContainer> createState() => _PunishmentContainerState();
}

class _PunishmentContainerState extends State<_PunishmentContainer> {
  int? expanded;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModerationCubit, ModerationServerState>(
      builder: (context, state) {
        final punishments = state.punishments;
        return SuperListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          itemBuilder: (context, index) {
            final punishment = punishments.elementAt(index);
            return _Punishment(
              expanded: index == expanded,
              isEven: index.isEven,
              onTap: () {
                if (index == expanded) {
                  expanded = null;
                } else {
                  expanded = index;
                }

                setState(() {});
              },
              punishment: punishment,
            );
          },
          separatorBuilder: (context, index) {
            return const Divider();
          },
          itemCount: punishments.length,
        );
      },
    );
  }
}

class _Punishment extends StatelessWidget {
  const _Punishment({
    required this.expanded,
    required this.isEven,
    required this.onTap,
    required this.punishment,
  });

  final bool expanded;
  final bool isEven;
  final VoidCallback onTap;
  final Punishment punishment;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ButtonBuilder(
          onClick: onTap,
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
                      : isEven
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
                      '${punishment.user.name} (${punishment.user.id})',
                      style: const TextStyle(
                        fontFamily: FontFamily.battlefrontUI,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (expanded)
          Stack(
            children: [
              Positioned.fill(
                right: null,
                left: 2,
                child: SizedBox(
                  width: 2,
                  child: CustomPaint(
                    foregroundPainter: DashedLineVerticalPainter(),
                    willChange: true,
                  ),
                ),
              ),
              Positioned.fill(
                left: null,
                child: SizedBox(
                  width: 2,
                  child: CustomPaint(
                    foregroundPainter: DashedLineVerticalPainter(),
                    willChange: true,
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final until = DateTime.fromMillisecondsSinceEpoch(
                    punishment.expiresAt.toInt(),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UNTIL: ${punishment.expiresAt == 0 ? 'PERMANENT' : DateFormat.yMd().format(until)} ${punishment.expiresAt != 0 ? '(${formatDuration(until.difference(DateTime.now()))})' : ''}',
                          style: const TextStyle(
                            fontFamily: FontFamily.iBMPlexMono,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'REASON: ${punishment.reason}',
                          style: const TextStyle(
                            fontFamily: FontFamily.iBMPlexMono,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 10,
                            children: [
                              KyberButton(
                                text: 'UNBAN',
                                onPressed: () {
                                  context.read<ModerationCubit>().unbanPlayer(
                                    punishment.user.id,
                                  );
                                  NotificationService.info(
                                    message: 'Player unbanned',
                                  );
                                },
                              ),
                              const KyberButton(
                                text: 'MODIFY',
                                onPressed: NotificationService.notImplemented,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  );
                },
              ),
              CustomPaint(
                painter: DashedLineVerticalPainter(),
              ),
            ],
          ),
      ],
    );
  }

  String formatDuration(Duration duration) {
    if (duration.isNegative) {
      return 'Time has elapsed';
    }

    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    final parts = <String>[];

    if (days > 0) {
      parts.add("$days day${days != 1 ? 's' : ''}");
    }

    if (hours > 0 && days < 1) {
      parts.add("$hours hour${hours != 1 ? 's' : ''}");
    }

    if (minutes > 0 && days < 1 && hours < 1) {
      parts.add("$minutes minute${minutes != 1 ? 's' : ''}");
    }

    if (seconds > 0 && days < 1 && hours < 1 && minutes < 1) {
      parts.add("$seconds second${seconds != 1 ? 's' : ''}");
    }

    return '${parts.join(", ")} remaining';
  }
}

class _ModeratorContainerState extends State<_ModeratorContainer> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ModerationCubit, ModerationServerState>(
      builder: (context, state) {
        final moderators = state.moderators;
        return SuperListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          itemBuilder: (context, index) {
            final player = moderators.elementAt(index);
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
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
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
                                  _ModeratorWidget(state, hovered, player),
                                ],
                              ),
                            ),
                            if (state.isModerator(player.id)) ...[
                              _ModeratorWidget(state, hovered, player),
                            ],
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
          itemCount: moderators.length,
        );
      },
    );
  }

  Widget _ModeratorWidget(
    ModerationServerState state,
    bool hovered,
    KyberPlayer player,
  ) => KyberTooltip(
    message: 'Promote User'.toUpperCase(),
    child: CustomSvgButton(
      hoverColor: Colors.black,
      onPressed: () async {
        if (state.isModerator(player.id)) {
          await context.read<ModerationCubit>().demotePlayer(player.id).onError(
            (error, stackTrace) {
              if (error is GrpcError) {
                NotificationService.showNotification(
                  message: error.message!,
                  severity: InfoBarSeverity.error,
                );
              } else {
                NotificationService.showNotification(
                  message: 'An error occurred',
                  severity: InfoBarSeverity.error,
                );
                Logger.root.severe('Error promoting player', error, stackTrace);
              }
            },
          );
        } else {
          await context
              .read<ModerationCubit>()
              .promotePlayer(player.id)
              .onError((error, stackTrace) {
                if (error is GrpcError) {
                  NotificationService.showNotification(
                    message: error.message!,
                    severity: InfoBarSeverity.error,
                  );
                } else {
                  NotificationService.showNotification(
                    message: 'An error occurred',
                    severity: InfoBarSeverity.error,
                  );
                  Logger.root.severe(
                    'Error demoting player',
                    error,
                    stackTrace,
                  );
                }
              });
        }
        context.read<ModerationCubit>().loadModerators();
      },
      color: state.isModerator(player.id)
          ? Colors.green
          : /* state.server?.creator == player.name
                  ? kActiveColor.darken(10)
                  :*/ hovered
          ? kButtonBorder
          : kActiveColor,
      path: Assets.icons.kblOpUser.path,
      size: 17,
    ),
  );
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
    return BlocBuilder<ModerationCubit, ModerationServerState>(
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
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
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
                                    message: 'Swap Player'.toUpperCase(),
                                    child: CustomSvgButton(
                                      onPressed: () {
                                        context
                                            .read<ModerationCubit>()
                                            .swapTeam(player);
                                      },
                                      path: Assets.icons.kblSwap.path,
                                      hoverColor: Colors.black,
                                      color: hovered ? kButtonBorder : null,
                                      size: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  KyberTooltip(
                                    message: 'Kick player'.toUpperCase(),
                                    child: CustomSvgButton(
                                      onPressed: () async {
                                        final reason =
                                            await showKyberDialog<String?>(
                                              context: context,
                                              builder: (_) =>
                                                  const ModerationInputDialog(),
                                            );
                                        if (reason == null) {
                                          return;
                                        }

                                        await context
                                            .read<ModerationCubit>()
                                            .kickPlayer(
                                              player.id,
                                              reason: reason,
                                            )
                                            .onError((error, stackTrace) {
                                              if (error is GrpcError) {
                                                NotificationService.showNotification(
                                                  message: error.message!,
                                                  severity:
                                                      InfoBarSeverity.error,
                                                );
                                              } else {
                                                NotificationService.showNotification(
                                                  message: 'An error occurred',
                                                  severity:
                                                      InfoBarSeverity.error,
                                                );
                                                Logger.root.severe(
                                                  'Error kicking player',
                                                  error,
                                                  stackTrace,
                                                );
                                              }
                                            });
                                      },
                                      path: Assets.icons.kblKick.path,
                                      hoverColor: Colors.black,
                                      color: hovered ? kButtonBorder : null,
                                      size: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  KyberTooltip(
                                    message: 'Ban player'.toUpperCase(),
                                    child: CustomSvgButton(
                                      onPressed: () async {
                                        final result = await showKyberDialog(
                                          context: context,
                                          builder: (_) => BlocProvider.value(
                                            value: context
                                                .read<ModerationCubit>(),
                                            child: ModerationBanDialog(
                                              player: player,
                                            ),
                                          ),
                                        );
                                      },
                                      path: Assets.icons.kblBan.path,
                                      hoverColor: Colors.black,
                                      color: hovered ? kButtonBorder : null,
                                      size: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  if ((!state.moderators.contains(player) &&
                                          state.server?.creatorId !=
                                              player.id) &&
                                      context
                                              .read<MaximaCubit>()
                                              .state
                                              .servicePlayer
                                              ?.id ==
                                          state.server?.creatorId)
                                    _ModeratorWidget(state, hovered, player),
                                ],
                              ),
                            ),
                            if (state.moderators.contains(player) ||
                                state.server?.creatorId == player.id) ...[
                              _ModeratorWidget(state, hovered, player),
                            ],
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

  Widget _ModeratorWidget(
    ModerationServerState state,
    bool hovered,
    ServerPlayer player,
  ) => KyberTooltip(
    message: 'Promote User'.toUpperCase(),
    child: CustomSvgButton(
      hoverColor: Colors.black,
      onPressed: () async {
        if (state.isModerator(player.id)) {
          await context.read<ModerationCubit>().demotePlayer(player.id).onError(
            (error, stackTrace) {
              if (error is GrpcError) {
                NotificationService.showNotification(
                  message: error.message!,
                  severity: InfoBarSeverity.error,
                );
              } else {
                NotificationService.showNotification(
                  message: 'An error occurred',
                  severity: InfoBarSeverity.error,
                );
                Logger.root.severe('Error promoting player', error, stackTrace);
              }
            },
          );
        } else {
          await context
              .read<ModerationCubit>()
              .promotePlayer(player.id)
              .onError((error, stackTrace) {
                if (error is GrpcError) {
                  NotificationService.showNotification(
                    message: error.message!,
                    severity: InfoBarSeverity.error,
                  );
                } else {
                  NotificationService.showNotification(
                    message: 'An error occurred',
                    severity: InfoBarSeverity.error,
                  );
                  Logger.root.severe(
                    'Error demoting player',
                    error,
                    stackTrace,
                  );
                }
              });
        }

        context.read<ModerationCubit>().loadModerators();
      },
      color: state.isModerator(player.id)
          ? Colors.green
          : state.server?.creatorId == player.id
          ? kActiveColor.darken()
          : hovered
          ? kButtonBorder
          : kActiveColor,
      path: Assets.icons.kblOpUser.path,
      size: 17,
    ),
  );
}
