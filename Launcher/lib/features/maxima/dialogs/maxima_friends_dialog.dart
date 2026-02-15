import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/friend_list/maxima_friend_list.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';

class MaximaFriendsDialog extends StatelessWidget {
  const MaximaFriendsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 50),
            child: FractionallySizedBox(
              heightFactor: .7,
              widthFactor: .7,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.5),
                  border: Border.all(
                    color: decoColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: EdgeInsets.zero,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 25,
                                bottom: 5,
                              ),
                              child: Text(
                                'Multiplayer Group'.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: FontFamily.aurebesh,
                                  color: decoColor,
                                  fontSize: 15,
                                  height: 1,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 25,
                                bottom: 15,
                              ),
                              child: Text(
                                'Multiplayer Group'.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 26,
                                  height: 1,
                                ),
                              ),
                            ),
                            Expanded(
                              child: BlocBuilder<SessionCubit, SessionState>(
                                builder: (context, state) {
                                  if (state is InParty) {
                                    return _buildPartyList(context);
                                  }

                                  return _buildDefaultUser();
                                },
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 20, bottom: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite friends and then choose what to play in the Play menu.',
                                    style: TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 17,
                                      color: kButtonBorder,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    'The whole group will be matchmade and kept together.',
                                    style: TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 17,
                                      color: kButtonBorder,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 1.5,
                      child: ColoredBox(color: decoColor),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 25,
                                bottom: 5,
                              ),
                              child: Text(
                                'Friends Online'.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: FontFamily.aurebesh,
                                  color: decoColor,
                                  fontSize: 15,
                                  height: 1,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 25,
                                bottom: 15,
                              ),
                              child:
                              BlocBuilder<MaximaRtmCubit, MaximaRtmState>(
                                builder: (context, state) {
                                  final friends = state.getOnlinePlayers();
                                  return Text(
                                    'Friends Online: ${friends.length}'
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 26,
                                      height: 1,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(
                              height: 1,
                              child: ColoredBox(color: decoColor),
                            ),
                            SizedBox(
                              height: 35,
                              child: mt.TextField(
                                style: const mt.TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 16,
                                  height: 1,
                                ),
                                decoration: mt.InputDecoration(
                                  filled: false,
                                  fillColor: kInactiveColor.withOpacity(.05),
                                  isDense: true,
                                  enabledBorder: mt.InputBorder.none,
                                  focusedBorder: mt.InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12.5,
                                  ),
                                  hintText: 'Search for Friends'.toUpperCase(),
                                  hintStyle: TextStyle(
                                    color: kInactiveColor.withOpacity(.75),
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 16,
                                    height: 1,
                                  ),
                                  hintMaxLines: 1,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final friends = context.select(
                                        (MaximaRtmCubit cubit) =>
                                    cubit.state.friends,
                                  );

                                  if (friends.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        'No friends online',
                                        style: TextStyle(
                                          fontFamily: FontFamily.battlefrontUI,
                                          fontSize: 20,
                                          color: kButtonBorder,
                                          height: 1,
                                        ),
                                      ),
                                    );
                                  }

                                  return FadeIn(
                                    child: MaximaFriendList(
                                      onFriendSelected: (value) async {
                                        final partyCubit = context
                                            .read<SessionCubit>();
                                        await partyCubit.inviteToParty(
                                          value.id,
                                        );
                                        NotificationService.info(
                                          message:
                                          'Invited ${value
                                              .displayName} to the party',
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          bottom: 20,
          child: KyberButton(
            text: 'Back',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildPartyList(BuildContext context) {
    final party = context
        .watch<SessionCubit>()
        .state;
    final state = (party as InParty).party;

    return ListView.separated(
      itemCount: state.members.length,
      separatorBuilder: (context, index) {
        return const Divider(
          style: DividerThemeData(
            horizontalMargin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: decoColor,
            ),
          ),
        );
      },
      itemBuilder: (context, index) {
        final player = state.members[index].player;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.05),
            border: const Border(
              bottom: BorderSide(
                color: decoColor,
                width: 1.5,
              ),
              top: BorderSide(
                color: decoColor,
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ).copyWith(left: 25),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                MaximaAvatar(pd: player.id, height: 45, width: 45),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: .start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      player.name,
                      style: const TextStyle(
                        fontFamily:
                        FontFamily.battlefrontUI,
                        fontSize: 20,
                        height: 1,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    const Divider(
                      size: 10,
                      style: DividerThemeData(
                        horizontalMargin:
                            .zero,
                        verticalMargin:
                        EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: decoColor,
                        ),
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
  }

  Widget _buildDefaultUser() {
    return ListView.separated(
      itemCount: 1,
      separatorBuilder: (context, index) {
        return const Divider(
          style: DividerThemeData(
            horizontalMargin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: decoColor,
            ),
          ),
        );
      },
      itemBuilder: (context, index) {
        final player = context
            .read<MaximaCubit>()
            .state
            .servicePlayer!;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.05),
            border: const Border(
              bottom: BorderSide(
                color: decoColor,
                width: 1.5,
              ),
              top: BorderSide(
                color: decoColor,
                width: 1.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ).copyWith(left: 25),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                if (player.avatar != null)
                  CachedNetworkImage(
                    imageUrl:
                    player.avatar!.medium.path,
                    height: 55,
                  ),
                if (player.avatar == null)
                  Assets.images.usericonTmp.image(
                    height: 55,
                  ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: .start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      player.displayName,
                      style: const TextStyle(
                        fontFamily:
                        FontFamily.battlefrontUI,
                        fontSize: 20,
                        height: 1,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    const Divider(
                      size: 10,
                      style: DividerThemeData(
                        horizontalMargin:
                        EdgeInsets.zero,
                        verticalMargin:
                        EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: decoColor,
                        ),
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
  }
}
