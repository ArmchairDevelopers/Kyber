import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';

class JoinGameDialog extends StatelessWidget {
  const JoinGameDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SessionCubit,
      SessionState,
      (JoinGameInfo?, List<PartyMember>?)
    >(
      selector: (state) => state is InParty
          ? (state.joinGameInfo, state.party.members.toList())
          : (null, null),
      builder: (context, data) {
        final (info, members) = data;
        if (info == null || members == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        }

        final userId = context.read<MaximaCubit>().state.servicePlayer?.id;
        final myStatus = info.memberStatuses[userId];
        final isLeader = info.leaderId == userId;
        final hasMods = myStatus?.hasMods ?? false;
        final isDownloading =
            myStatus?.modDownloadPercentage != null && !hasMods;

        return KyberContentDialog(
          title: Text('Join Game'.toUpperCase()),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.serverName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: FontFamily.battlefrontUI,
                    fontSize: 18,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'WAITING FOR MEMBERS',
                  style: TextStyle(
                    fontFamily: FontFamily.battlefrontUI,
                    fontSize: 12,
                    color: kButtonBorder,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => Container(
                      height: 1,
                      color: decoColor,
                    ),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final status = info.memberStatuses[member.player.id];
                      final isLeader = member.player.id == info.leaderId;

                      return _MemberRow(
                        member: member,
                        status: status,
                        isLeader: isLeader,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            KyberButton(
              text: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (isLeader)
              KyberButton(
                text: 'Cancel Joining',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<SessionCubit>().cancelJoinGame();
                },
              ),
            if (!hasMods && !isDownloading)
              KyberButton(
                text: 'Download Mods',
                onPressed: () {
                  context.read<SessionCubit>().startModDownloads();
                },
              ),
            /*if (hasMods && !isLeader)
              KyberButton(
                text: 'Join Game',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<SessionCubit>().joinGameLate();
                },
              ),*/
            if (isLeader && hasMods)
              KyberButton(
                text: 'Join All Ready',
                onPressed: () {
                  context.read<SessionCubit>().readyUp();
                  context.read<SessionCubit>().joinAllReadyPlayers();
                },
              ),
          ],
        );
      },
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.status,
    required this.isLeader,
  });

  final PartyMember member;
  final JoinGameMemberStatusInfo? status;
  final bool isLeader;

  @override
  Widget build(BuildContext context) {
    final hasMods = status?.hasMods ?? false;
    final progress = status?.modDownloadPercentage;

    final String statusText;
    final Widget statusIcon;

    if (hasMods) {
      statusText = 'READY';
      statusIcon = Icon(
        FluentIcons.check_mark,
        size: 20,
        color: Colors.green.light,
      );
    } else if (progress != null) {
      statusText = 'DOWNLOADING $progress%';
      statusIcon = SizedBox(
        width: 20,
        height: 20,
        child: ProgressRing(
          value: progress.toDouble(),
          strokeWidth: 3,
          activeColor: kActiveColor,
        ),
      );
    } else if (!hasMods && status != null) {
      statusText = 'MISSING MODS';
      statusIcon = const Icon(
        FluentIcons.download,
        size: 20,
        color: kButtonBorder,
      );
    } else {
      statusText = 'WAITING';
      statusIcon = const SizedBox(
        width: 20,
        height: 20,
        child: ProgressRing(strokeWidth: 3),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          MaximaAvatar(pd: member.player.id, height: 36, width: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.player.name.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: FontFamily.battlefrontUI,
                          fontSize: 14,
                          color: kWhiteColor,
                          height: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLeader) ...[
                      const SizedBox(width: 6),
                      Icon(
                        FluentIcons.crown,
                        size: 12,
                        color: kActiveColor,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: FontFamily.battlefrontUI,
                    fontSize: 11,
                    color: hasMods ? Colors.green.light : kButtonBorder,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          statusIcon,
        ],
      ),
    );
  }
}
