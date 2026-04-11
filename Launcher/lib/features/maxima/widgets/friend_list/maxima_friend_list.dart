import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';

class MaximaFriendList extends StatefulWidget {
  const MaximaFriendList({this.onFriendSelected, super.key});

  final ValueChanged<ServicePlayer>? onFriendSelected;

  @override
  State<MaximaFriendList> createState() => _MaximaFriendListState();
}

class _MaximaFriendListState extends State<MaximaFriendList> {
  int hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaximaRtmCubit, MaximaRtmState>(
      builder: (context, state) {
        final friends = state.getSortedPlayers();
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const SizedBox.shrink();
            }

            return ButtonBuilder(
              onClick: () {},
              onDoubleClick: () {
                final friend = friends[index - 1];
                widget.onFriendSelected?.call(friend);
              },
              builder: (context, hovered) {
                final friend = friends[index - 1];
                final presence = state.presences[friend.id];
                var isOnline = false;
                if (presence != null &&
                    presence.basic != BasicPresence.offline) {
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

                return MouseRegion(
                  onEnter: (_) {
                    setState(() => hoveredIndex = index);
                  },
                  onExit: (_) {
                    setState(() => hoveredIndex = -1);
                  },
                  cursor: SystemMouseCursors.basic,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ).copyWith(left: 15),
                    child: Row(
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
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                horizontalMargin: EdgeInsets.zero,
                                verticalMargin: EdgeInsets.symmetric(
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
                      ],
                    ),
                  ),
                );
              },
            );
          },
          separatorBuilder: (context, index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 1,
              color: hoveredIndex == index || hoveredIndex == index + 1
                  ? kActiveColor
                  : decoColor,
            );
          },
          itemCount: friends.length + 1,
        );
      },
    );
  }
}
