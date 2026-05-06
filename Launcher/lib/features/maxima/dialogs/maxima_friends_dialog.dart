import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/friend_list/maxima_friend_list.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class MaximaFriendsDialog extends StatelessWidget {
  const MaximaFriendsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: .centerLeft,
          child: Padding(
            padding: const .only(left: 50),
            child: FractionallySizedBox(
              heightFactor: .7,
              widthFactor: .7,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.5),
                  border: .all(color: decoColor, width: 2),
                  borderRadius: .circular(5),
                ),
                padding: .zero,
                child: Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    Expanded(child: _PartyPanel()),
                    const SizedBox(
                      width: 1.5,
                      child: ColoredBox(color: decoColor),
                    ),
                    Expanded(child: _FriendsPanel()),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 20,
          child: _BottomActions(),
        ),
      ],
    );
  }
}

class _PartyPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 20),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const _SectionHeader(title: 'Multiplayer Group'),
          const SizedBox(height: 1, child: ColoredBox(color: decoColor)),
          Expanded(
            child: BlocBuilder<SessionCubit, SessionState>(
              builder: (context, state) {
                if (state is InParty) {
                  return _PartyMemberList(party: state);
                }

                return _CurrentUserTile();
              },
            ),
          ),
          const Padding(
            padding: .only(left: 20, bottom: 20),
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 14,
                color: kInactiveColor,
                fontFamily: FontFamily.battlefrontUI,
              ),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    'Invite friends and then choose what to play in the Play menu.',
                  ),
                  Text(
                    'The whole group will be matchmade and kept together.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 20),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          BlocSelector<MaximaRtmCubit, MaximaRtmState, int>(
            selector: (state) => state.getOnlinePlayers().length,
            builder: (context, count) =>
                _SectionHeader(title: 'Friends Online: $count'),
          ),
          const SizedBox(height: 1, child: ColoredBox(color: decoColor)),
          //_FriendsSearchField(),
          Expanded(child: _FriendsList()),
        ],
      ),
    );
  }
}

class _FriendsSearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35,
      child: mt.TextField(
        style: const .new(
          fontFamily: FontFamily.battlefrontUI,
          fontSize: 16,
          height: 1,
        ),
        decoration: .new(
          filled: false,
          fillColor: kInactiveColor.withOpacity(.05),
          isDense: true,
          enabledBorder: .none,
          focusedBorder: .none,
          contentPadding: const .symmetric(
            horizontal: 15,
            vertical: 12.5,
          ),
          hintText: 'Search for Friends'.toUpperCase(),
          hintStyle: .new(
            color: kInactiveColor.withOpacity(.75),
            fontFamily: FontFamily.battlefrontUI,
            fontSize: 16,
            height: 1,
          ),
          hintMaxLines: 1,
        ),
      ),
    );
  }
}

class _FriendsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final friends = context.select(
      (MaximaRtmCubit cubit) => cubit.state.friends,
    );

    if (friends.isEmpty) {
      return const Center(
        child: Text(
          'No friends online',
          style: .new(
            fontFamily: FontFamily.battlefrontUI,
            fontSize: 17,
            color: kButtonBorder,
            height: 1,
          ),
        ),
      );
    }

    return FadeIn(
      child: MaximaFriendList(
        onFriendSelected: (value) async => inviteFriend(context, value),
      ),
    );
  }

  void inviteFriend(BuildContext context, ServicePlayer player) async {
    try {
      await context.read<SessionCubit>().inviteToParty(player.id);
      NotificationService.info(
        message: 'Invited friend to the party',
      );
    } on GrpcError catch (e) {
      NotificationService.error(
        message: 'Failed to invite friend: ${e.message}',
      );
    }
  }
}

class _PartyMemberList extends StatelessWidget {
  const _PartyMemberList({required this.party});

  final InParty party;

  @override
  Widget build(BuildContext context) {
    final members = party.party.members;

    return SuperListView.separated(
      itemCount: members.length + 1,
      itemBuilder: (_, index) {
        if (index == members.length) {
          return const SizedBox.shrink();
        }

        final player = members[index].player;
        final isLeader = party.party.leaderId == player.id;

        return _MemberTile(
          name: player.name,
          avatar: MaximaAvatar(pd: player.id, height: 50, width: 50),
          id: player.id,
          status: switch (isLeader) {
            true => Text(
              'Group Leader',
              style: .new(color: kActiveColor),
            ),
            _ => const Text('Online'),
          },
        );
      },
      separatorBuilder: (context, index) {
        return Container(
          height: 1,
          color: decoColor,
        );
      },
    );
  }
}

class _CurrentUserTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.read<MaximaCubit>().state.servicePlayer!;
    return Column(
      children: [
        _MemberTile(
          name: player.displayName,
          avatar: MaximaAvatar(pd: player.id, height: 50, width: 50),
          id: player.id,
        ),
        const _MemberDivider(),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.name,
    required this.avatar,
    this.status,
    this.id = '',
  });

  final String name;
  final Widget avatar;
  final Text? status;
  final String id;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<MaximaCubit>().state.servicePlayer!.id;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.05),
      ),
      child: ButtonBuilder(
        builder: (context, hovered) {
          final partyState = context.select(
            (SessionCubit cubit) => cubit.state,
          );
          final isLeader =
              partyState is InParty && partyState.party.leaderId == userId;

          return Padding(
            padding: const .symmetric(
              horizontal: 15,
              vertical: 5,
            ),
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: .start,
                  children: [
                    Container(
                      clipBehavior: .antiAliasWithSaveLayer,
                      decoration: const BoxDecoration(
                        borderRadius: .all(.circular(6)),
                      ),
                      child: avatar,
                    ),
                    const SizedBox(width: 10),
                    DefaultTextStyle(
                      style: const .new(
                        height: 1,
                        fontFamily: FontFamily.battlefrontUI,
                      ),
                      child: Padding(
                        padding: const .symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: .start,
                          mainAxisAlignment: .center,
                          spacing: 5,
                          children: [
                            Text(name, style: const .new(fontSize: 18)),
                            const Divider(
                              size: 10,
                              style: DividerThemeData(
                                horizontalMargin: .zero,
                                verticalMargin: .symmetric(vertical: 10),
                                decoration: BoxDecoration(color: decoColor),
                              ),
                            ),
                            ?status,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (hovered && isLeader && userId != id)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      height: 35,
                      child: Row(
                        spacing: 15,
                        children: [
                          SizedBox(
                            child: KOutlinedButton(
                              child: const Text('MAKE LEADER'),
                              onPressed: () async {
                                try {
                                  await context.read<SessionCubit>().transferLeader(id);
                                } on GrpcError catch (e) {
                                  NotificationService.error(
                                    message:
                                        'Failed to transfer leadership: ${e.message}',
                                  );
                                }
                              },
                            ),
                          ),
                          KOutlinedButton(
                            padding: const .symmetric(horizontal: 20, vertical: 5),
                            child: const Icon(mt.Icons.close_sharp, size: 22),
                            onPressed: () async {
                              try {
                                await context.read<SessionCubit>().kickFromParty(id);
                              } on GrpcError catch (e) {
                                NotificationService.error(
                                  message: 'Failed to kick member: ${e.message}',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Padding(
          padding: const .only(left: 15, bottom: 5),
          child: Text(
            title.toUpperCase(),
            style: const .new(
              fontSize: 15,
              color: decoColor,
              fontFamily: FontFamily.aurebesh,
              height: 1,
            ),
          ),
        ),
        Padding(
          padding: const .only(left: 15, bottom: 15),
          child: Text(
            title.toUpperCase(),
            style: const .new(
              fontSize: 20,
              fontFamily: FontFamily.battlefrontUI,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 10,
      children: [
        KyberButton(
          text: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        BlocSelector<SessionCubit, SessionState, bool>(
          selector: (state) => state is InParty,
          builder: (context, inParty) {
            if (!inParty) return const SizedBox.shrink();
            return KyberButton(
              text: 'Leave Party',
              onPressed: () => context.read<SessionCubit>().leaveParty(),
            );
          },
        ),
      ],
    );
  }
}

class _MemberDivider extends StatelessWidget {
  const _MemberDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      style: DividerThemeData(
        horizontalMargin: .zero,
        thickness: 0,
        decoration: BoxDecoration(color: decoColor),
      ),
    );
  }
}
