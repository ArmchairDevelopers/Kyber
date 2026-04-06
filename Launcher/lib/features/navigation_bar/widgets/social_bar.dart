import 'package:fluent_ui/fluent_ui.dart' hide Button;
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class SocialBar extends StatefulWidget {
  const SocialBar({super.key});

  @override
  State<SocialBar> createState() => _SocialBarState();
}

class _SocialBarState extends State<SocialBar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      // TODO: just a placeholder, should never use MediaQuery directly in widgets like this :)
      width: MediaQuery.of(context).size.width * 0.3 + 25,
      child: BackgroundBlur(
        child: Container(
          decoration: const BoxDecoration(
            border: .symmetric(vertical: kDefaultBorder),
          ),
          padding: const .symmetric(horizontal: 15, vertical: 4),
          alignment: .center,
          child: Row(
            spacing: 15,
            children: [
              Button(
                onPressed: () => null,
                child: const Icon(mt.Icons.group),
              ),
              const VCardSection(),
              const Flexible(child: _FriendsBar()),
              const VCardSection(),
              Button(
                onPressed: () => null,
                child: const Icon(mt.Icons.download),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendsBar extends StatelessWidget {
  const _FriendsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaximaRtmCubit, MaximaRtmState>(
      builder: (context, state) {
        final friends = state.getSortedPlayers();

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxItems = ((constraints.maxWidth - 15) / 43).floor();
            final displayedFriends = friends.take(maxItems).toList();

            return Row(
              spacing: 10,
              children: [
                for (final friend in displayedFriends)
                  Container(
                    decoration: const BoxDecoration(
                      border: kDefaultAllBorder,
                      borderRadius: .all(.circular(3))
                    ),
                    clipBehavior: .antiAliasWithSaveLayer,
                    child: MaximaAvatar(pd: friend.pd, height: 33, width: 33),
                  ),
                if (friends.length > maxItems)
                  Text(
                    '+${friends.length - maxItems}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: kInactiveColor,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
