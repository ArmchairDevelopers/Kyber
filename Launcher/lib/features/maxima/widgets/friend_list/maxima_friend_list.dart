import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

class MaximaFriendList extends StatefulWidget {
  const MaximaFriendList({this.onFriendSelected, super.key});

  final ValueChanged<ServicePlayer>? onFriendSelected;

  @override
  State<MaximaFriendList> createState() => _MaximaFriendListState();
}

class _MaximaFriendListState extends State<MaximaFriendList> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaximaRtmCubit, MaximaRtmState>(
      builder: (context, state) {
        final partyState = switch (context.watch<SessionCubit>().state) {
          final InParty inParty => inParty,
          _ => null,
        };

        final friends = state.getSortedPlayers(partyState: partyState?.party);

        return SuperListView.separated(
          itemBuilder: (context, index) {
            if (index == friends.length) {
              return const SizedBox.shrink();
            }

            return ButtonBuilder(
              // onDoubleClick: () {
              //   final friend = friends[index];
              //   widget.onFriendSelected?.call(friend);
              // },
              builder: (context, hovered) {
                final friend = friends[index];
                final presence = state.presences[friend.id];
                var isOnline = false;

                if (presence != null && presence.basic != .offline) {
                  isOnline = true;
                }

                var text = 'Offline';
                if (isOnline) {
                  if (presence!.status.isEmpty) {
                    text = 'Online';
                  } else {
                    text = 'Playing ${presence.status}';
                  }
                }

                return Padding(
                  padding: const .symmetric(
                    horizontal: 15,
                    vertical: 5,
                  ),
                  child: Row(
                    spacing: 10,
                    children: [
                      Container(
                        clipBehavior: .antiAliasWithSaveLayer,
                        decoration: const BoxDecoration(
                          borderRadius: .all(.circular(6)),
                        ),
                        child: MaximaAvatar(
                          height: 50,
                          width: 50,
                          pd: friend.pd,
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                child: Column(
                                  crossAxisAlignment: .start,
                                  children: [
                                    Text(
                                      friend.displayName,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(
                                          !isOnline ? .5 : 1,
                                        ),
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 18,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    const Divider(
                                      size: 8,
                                      style: DividerThemeData(
                                        thickness: .5,
                                        horizontalMargin: .zero,
                                        verticalMargin: .symmetric(
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: decoColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 15,
                                        color: kWhiteColor.withOpacity(
                                          !isOnline ? .25 : 1,
                                        ),
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hovered)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  child: FadeIn(
                                    duration: const .new(milliseconds: 150),
                                    child: Row(
                                      mainAxisAlignment: .end,
                                      mainAxisSize: .min,
                                      children: [
                                        SizedBox(
                                          height: 33,
                                          child: KyberButton(
                                            text: 'INVITE',
                                            onPressed: () => widget
                                                .onFriendSelected
                                                ?.call(friend),
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
                    ],
                  ),
                );
              },
            );
          },
          separatorBuilder: (context, index) {
            return Container(
              height: 1,
              color: decoColor,
            );
          },
          itemCount: friends.length + 1,
        );
      },
    );
  }
}
