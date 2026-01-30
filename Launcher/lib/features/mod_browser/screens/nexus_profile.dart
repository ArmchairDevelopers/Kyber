import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/utils/transparent_image.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_tile.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tab_bar.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:nexus_bridge/nexus_bridge.dart';
import 'package:nexus_gql/nexus_gql.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class NexusProfile extends StatefulWidget {
  const NexusProfile({required this.userId, super.key});

  final int userId;

  @override
  State<NexusProfile> createState() => _NexusProfileState();
}

class _NexusProfileState extends State<NexusProfile> {
  int tabIndex = 0;
  int currentPage = 1;
  int downloads = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Query$userById$Widget(
      options: .new(
        variables: .new(
          id: widget.userId,
          uploaderId: widget.userId.toString(),
        ),
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.hasException) {
          late String error;
          if (result.exception == null) {
            error = l10n.unknownError;
          } else if (result.exception!.linkException != null) {
            error = result.exception!.linkException!.originalStackTrace
                .toString();
          } else if (result.exception!.graphqlErrors.isNotEmpty) {
            error = result.exception!.graphqlErrors.first.message;
          } else {
            error = result.exception.toString();
          }

          return Center(
            child: Text(error),
          );
        }

        final data = result.parsedData;
        final isLoading = result.isLoading;

        if (!isLoading && data == null) {
          return Center(
            child: Text(l10n.noDataFound),
          );
        }

        return Row(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(
              child: KyberCard(
                padding: .zero,
                child: Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    Expanded(
                      flex: 8,
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          SizedBox(
                            height: 100,
                            child: Column(
                              children: [
                                Container(
                                  padding: const .symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          border: .all(
                                            color: decoColor,
                                            width: 2,
                                          ),
                                          borderRadius: .circular(
                                            6,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: .circular(
                                            4,
                                          ),
                                          child: CachedNetworkImage(
                                            imageUrl: data?.user?.avatar ?? '',
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                const Center(
                                                  child: ProgressRing(),
                                                ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Center(
                                                      child: ProgressRing(),
                                                    ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data?.user?.name ?? '...',
                                            style: TextStyle(
                                              fontFamily: currentFont,
                                              fontSize: 19,
                                              color: kWhiteColor,
                                            ),
                                          ),
                                          if (data != null &&
                                              data.user!.recognizedAuthor)
                                            Row(
                                              children: [
                                                Icon(
                                                  mt.Icons.verified_user,
                                                  color: kActiveColor,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  l10n.verifiedModAuthor
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: kGrayColor,
                                                    fontFamily: currentFont,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                  ).copyWith(bottom: 6),
                                  child: ButtonBuilder(
                                    onClick: router.pop,
                                    builder: (context, hovered) {
                                      return AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        style: TextStyle(
                                          color: hovered
                                              ? kActiveColor
                                              : kWhiteColor,
                                          fontFamily: currentFont,
                                          fontSize: 15,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              l10n.viewingProfile.toUpperCase(),
                                              style: TextStyle(
                                                fontFamily: currentFont,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(
                                              mt.Icons.circle,
                                              color: kActiveColor,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const ContainerSeparator(),
                          if (data != null)
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  return Markdown(
                                    data: data.user?.about ?? '',
                                    onTapLink: (text, href, title) async {
                                      if (href == null) {
                                        return;
                                      }

                                      final uri = Uri.parse(href);
                                      if (!(await canLaunchUrl(uri))) return;
                                      await launchUrl(uri);
                                    },
                                    styleSheet: MarkdownStyleSheet(
                                      a: TextStyle(
                                        color: kActiveColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      color: decoColor,
                    ),
                    Expanded(
                      flex: 19,
                      child: Column(
                        children: [
                          Container(
                            color: Colors.black,
                            height: 100,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ShaderMask(
                                    shaderCallback: (rect) {
                                      return LinearGradient(
                                        stops: const [0.3, 1],
                                        colors: [
                                          Colors.transparent.withOpacity(.2),
                                          Colors.black,
                                        ],
                                      ).createShader(
                                        Rect.fromLTRB(
                                          0,
                                          0,
                                          rect.width,
                                          rect.height,
                                        ),
                                      );
                                    },
                                    blendMode: BlendMode.dstIn,
                                    child: CachedNetworkImage(
                                      imageUrl: '',
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) =>
                                          Image.memory(kTransparentImage),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(15),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.publishedMods,
                                                style: TextStyle(
                                                  fontSize: 24,
                                                  fontFamily: currentFont,
                                                  height: 1,
                                                ),
                                              ),
                                              const SizedBox(height: 15),
                                              Row(
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        FluentIcons.download,
                                                        color: kWhiteColor,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        NumberFormat.decimalPattern()
                                                            .format(
                                                              data
                                                                      ?.user
                                                                      ?.uniqueModDownloads ??
                                                                  0,
                                                            ),
                                                        style: TextStyle(
                                                          color: kWhiteColor,
                                                          fontFamily: currentFont,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 15),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        mt.Icons.public,
                                                        color: kWhiteColor,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Text(
                                                        NumberFormat.decimalPattern()
                                                            .format(
                                                              data
                                                                      ?.user
                                                                      ?.modCount ??
                                                                  0,
                                                            ),
                                                        style: TextStyle(
                                                          color: kWhiteColor,
                                                          fontFamily: currentFont,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  //if (data?.user.country != null) ...[
                                                  //  const SizedBox(width: 15),
                                                  //  SvgPicture.network(
                                                  //    'https://flagicons.lipis.dev/flags/4x3/${data?.user.country?.toLowerCase()}.svg',
                                                  //    height: 15,
                                                  //  ),
                                                  //],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const ContainerSeparator(),
                          Expanded(
                            child: Stack(
                              children: [
                                Builder(
                                  builder: (context) {
                                    //return ModDescription(description: data?.description ?? '');
                                    return Query$modsByUser$Widget(
                                      options: Options$Query$modsByUser(
                                        variables: Variables$Query$modsByUser(
                                          uploaderId: widget.userId.toString(),
                                        ),
                                      ),
                                      builder: (result, {fetchMore, refetch}) {
                                        final currentOffset =
                                            (currentPage - 1) * 15;

                                        final totalPages =
                                            result.parsedData != null
                                            ? (result
                                                          .parsedData!
                                                          .mods
                                                          .totalCount /
                                                      15)
                                                  .ceil()
                                            : 0;
                                        return Builder(
                                          builder: (context) {
                                            if (result.isLoading) {
                                              return const Center(
                                                child: ProgressRing(),
                                              );
                                            }

                                            if (result.hasException) {
                                              return Center(
                                                child: Text(
                                                  result.exception.toString(),
                                                ),
                                              );
                                            }

                                            return GridView.builder(
                                              gridDelegate:
                                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                                    maxCrossAxisExtent: 375,
                                                    childAspectRatio: 16 / 9,
                                                    crossAxisSpacing: 15,
                                                    mainAxisSpacing: 15,
                                                  ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 15,
                                                    horizontal: 15,
                                                  ),
                                              itemBuilder: (context, index) {
                                                final mod = result
                                                    .parsedData!
                                                    .mods
                                                    .nodes
                                                    .elementAt(index);
                                                final formattedMod =
                                                    NexusListMod(
                                                      id: mod.modId,
                                                      description: mod.summary,
                                                      views: 200,
                                                      author: 'AA',
                                                      date: DateTime.now(),
                                                      downloads: mod.downloads,
                                                      endorsements: mod
                                                          .endorsements
                                                          .toString(),
                                                      name: mod.name,
                                                      image: mod.pictureUrl!,
                                                      size: mod.fileSize!
                                                          .toString(),
                                                      uploader: 'aa',
                                                    );
                                                return ModTile(
                                                  key: Key(index.toString()),
                                                  mod: formattedMod,
                                                );
                                              },
                                              itemCount: result
                                                  .parsedData!
                                                  .mods
                                                  .nodes
                                                  .length,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              width: 375,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    kDefaultOuterBorderRadius,
                  ),
                  border: Border.all(
                    color: decoColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    kDefaultOuterBorderRadius - 2,
                  ),
                  child: BackgroundBlur(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 70,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14.5,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.userInformation,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontFamily: currentFont,
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        l10n.viewUserStats,
                                        style: TextStyle(
                                          color: kWhiteColor,
                                          fontFamily: currentFont,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 20),
                                SizedBox(
                                  height: 32,
                                  width: 32,
                                  child: KyberTabBar(
                                    onChanged: (index) =>
                                        Navigator.of(context).pop(),
                                    selectedIndex: -1,
                                    tabs: const [
                                      Icon(mt.Icons.close),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          height: 2,
                          color: decoColor,
                        ),
                        if (data != null)
                          Expanded(
                            child: DefaultTextStyle.merge(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14.5,
                                ),
                                child: GridView(
                                  gridDelegate:
                                      const mt.SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 8,
                                      ),
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          l10n.joinedLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          DateFormat.yMd().format(
                                            DateTime.parse(data.user!.joined),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.modsLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          NumberFormat.decimalPattern().format(
                                            data.user!.modCount,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.postsLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          NumberFormat.decimalPattern().format(
                                            data.user!.posts,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.uniqueDlsLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          NumberFormat.decimalPattern().format(
                                            data.user!.uniqueModDownloads,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.viewsLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          NumberFormat.decimalPattern().format(
                                            data.user!.views,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.kudosLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          NumberFormat.decimalPattern().format(
                                            data.user?.kudos,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.contributedLabel,
                                          style: const TextStyle(color: kWhiteColor),
                                        ),
                                        Text(
                                          NumberFormat.decimalPattern().format(
                                            data.user?.contributedModCount,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ButtonBuilder(
                                      onClick: () => launchUrlString(
                                        'https://www.nexusmods.com/users/${data.user?.memberId}',
                                      ),
                                      builder: (context, hovered) {
                                        return AnimatedDefaultTextStyle(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          style: TextStyle(
                                            color: hovered
                                                ? kActiveColor
                                                : Colors.white,
                                            fontFamily: currentFont,
                                            fontSize: 15,
                                          ),
                                          child: Row(
                                            children: [
                                              Text(
                                                l10n.viewOnNexusMods
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontFamily: currentFont,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Icon(
                                                mt.Icons.circle_outlined,
                                                color: kActiveColor,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}