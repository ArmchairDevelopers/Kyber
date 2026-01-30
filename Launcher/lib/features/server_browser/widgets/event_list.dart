import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/events/providers/event_cubic.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeEventList extends StatelessWidget {
  const HomeEventList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Expanded(
      child: KyberCard(
        padding: EdgeInsets.zero,
        child: BlocBuilder<EventCubit, EventState>(
          builder: (context, state) {
            if (state is EventsLoading) {
              return const Center(child: ProgressRing());
            }

            if (state is EventsError) {
              return Center(
                child: Text(
                  state.error,
                  style: TextStyle(
                    fontFamily: currentFont,
                    fontSize: 18,
                  ),
                ),
              );
            }

            state as EventsLoaded;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 60,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          l10n.eventsAndAnnouncements,
                          style: TextStyle(
                            fontFamily: currentFont,
                            fontSize: 21,
                            height: 1,
                          ),
                        ),
                        Text(
                          l10n.viewUpcomingEventsDesc,
                          style: TextStyle(
                            fontFamily: currentFont,
                            fontSize: 14,
                            color: kWhiteColor,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const CardSection(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 165,
                        child: _EventContainer(
                          post: state.posts.first,
                          mainPost: true,
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const elementHeight = 100;
                            const dividerHeight = 2;
                            var elements =
                                (constraints.maxHeight /
                                        (elementHeight + dividerHeight))
                                    .floor();
                            elements = state.posts.length;

                            return SuperListView(
                              children: [
                                for (var i = 1; i < elements; i++) ...[
                                  const CardSection(),
                                  SizedBox(
                                    height: 100,
                                    child: _EventContainer(
                                      post: state.posts[i],
                                    ),
                                  ),
                                  if (i == elements - 1) const CardSection(),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                      //for (var i = 0; i < elements; i++) ...[
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventContainer extends StatelessWidget {
  const _EventContainer({
    required this.post,
    this.mainPost = false,
  });

  final Post post;
  final bool mainPost;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return ButtonBuilder(
      onClick: () {
        if (post.link.isNotEmpty) {
          launchUrlString(post.link);
        }
      },
      builder: (context, hovered) {
        return Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: post.imageUrl,
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.darken,
                color: Colors.black.withOpacity(0.75),
                fadeInDuration: Duration.zero,
              ),
            ),
            if (mainPost)
              Positioned(
                top: 20,
                right: 20,
                child: SvgPicture.network(
                  post.iconUrl,
                  height: 14,
                  width: 14,
                  color: kWhiteColor,
                ),
              ),
            if (!mainPost)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          kDefaultInnerBorderRadius,
                        ),
                        child: BackgroundBlur(
                          child: AnimatedContainer(
                            width: 55,
                            height: 55,
                            duration: kDefaultDuration,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                kDefaultInnerBorderRadius,
                              ),
                              border: Border.all(
                                color: hovered
                                    ? kActiveColor
                                    : kDefaultBorder.color,
                                width: kDefaultBorder.width,
                              ),
                              color: Colors.black.withOpacity(0.8),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: SvgPicture.network(
                              post.iconUrl,
                              color: kWhiteColor,
                              width: 40,
                              height: 40,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Flexible(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.header,
                              style: TextStyle(
                                fontFamily: currentFont,
                                fontSize: 18,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: kActiveColor),
                                  bottom: BorderSide(color: kActiveColor),
                                ),
                              ),
                              child: Text(
                                post.body,
                                style: TextStyle(
                                  fontFamily: currentFont,
                                  color: kActiveColor,
                                  fontSize: 12,
                                  height: 1,
                                ),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (mainPost)
              Positioned(
                bottom: 25,
                left: 25,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.header,
                      style: TextStyle(
                        fontFamily: currentFont,
                        fontSize: 28,
                      ),
                    ),
                    Row(
                      children: [
                        SizedBox(
                          height: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: kActiveColor),
                                bottom: BorderSide(color: kActiveColor),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                post.body,
                                style: TextStyle(
                                  fontFamily: currentFont,
                                  color: kActiveColor,
                                  fontSize: 12,
                                  height: 1,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}