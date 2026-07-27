import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/utils/transparent_image.dart';
import 'package:kyber_launcher/features/mod_browser/dialogs/file_download_dialog.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_details/mod_description.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_image_viewer.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/nexus_mod_page/mod_author_info.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/nexus_mod_page/mod_header.dart';
import 'package:kyber_launcher/features/mods/helper/mod_helper.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/features/nexusmods/widgets/graphql_provider.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tab_bar.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:logging/logging.dart';
import 'package:nexus_bridge/nexus_bridge.dart';
import 'package:nexus_gql/nexus_gql.dart';

class ModInfo extends StatefulWidget {
  const ModInfo({required this.id, super.key});

  final String id;

  @override
  State<ModInfo> createState() => _ModInfoState();
}

class _ModInfoState extends State<ModInfo> {
  List<WSNexusModImage> images = [];
  bool showImages = false;
  int selectedImage = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    sl.get<NexusModsService>().nexusBridge.getModImages(widget.id).then((
      value,
    ) {
      if (!mounted) {
        return;
      }

      setState(() {
        images = value;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Query$modByUID$Widget(
      options: .new(
        variables: .new(uid: .parse(widget.id)),
        cacheRereadPolicy: .ignoreAll,
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.hasException) {
          late String error;
          if (result.exception == null) {
            error = 'Unknown error';
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

        final data = result.parsedData?.legacyMods.nodes.firstOrNull;
        final isLoading = result.isLoading;

        if (!isLoading && data == null) {
          return const Center(
            child: Text('No data found'),
          );
        }

        if (showImages && data != null) {
          return ModImageViewer(
            initialIndex: selectedImage,
            data: data,
            images: images,
            onClose: () {
              setState(() {
                showImages = false;
              });
            },
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
                      child: ModAuthorInfo(
                        data: data,
                        images: images,
                        onImageSelected: (index) {
                          setState(() {
                            selectedImage = index;
                            showImages = true;
                          });
                        },
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
                          ModHeader(data: data),
                          const ContainerSeparator(),
                          Expanded(
                            child: Stack(
                              children: [
                                Builder(
                                  builder: (context) {
                                    return ModDescription(
                                      description: data?.description ?? '',
                                    );
                                  },
                                ),
                                if (showImages)
                                  Positioned.fill(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          showImages = false;
                                        });
                                      },
                                      child: ColoredBox(
                                        color: Colors.black.withOpacity(.8),
                                        child: Center(
                                          child: CachedNetworkImage(
                                            imageUrl:
                                                data?.pictureUrl ??
                                                data?.thumbnailUrl ??
                                                '',
                                            fit: .contain,
                                            errorWidget:
                                                (context, url, error) =>
                                                    Image.memory(
                                                      kTransparentImage,
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ),
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
                  borderRadius: .circular(
                    kDefaultOuterBorderRadius,
                  ),
                  border: .all(
                    color: decoColor,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: .circular(
                    kDefaultOuterBorderRadius - 2,
                  ),
                  child: BackgroundBlur(
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        SizedBox(
                          height: 70,
                          child: Padding(
                            padding: const .symmetric(
                              horizontal: 16,
                              vertical: 14.5,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      Text(
                                        'MOD INFORMATION',
                                        style: .new(
                                          fontSize: 20,
                                          fontFamily: FontFamily.battlefrontUI,
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        'VIEW MOD FILES, SHARE AND ENDORSE',
                                        style: .new(
                                          color: kWhiteColor,
                                          fontFamily: FontFamily.battlefrontUI,
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
                                    onChanged: (_) =>
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
                        Container(
                          height: 90,
                          padding: const .symmetric(
                            horizontal: 15,
                            vertical: 12,
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: KyberTabBar(
                                        tabs: const [
                                          Text('FILES'),
                                          Text('POSTS'),
                                        ],
                                        onChanged: (value) {
                                          setState(() {
                                            _currentIndex = value;
                                          });
                                        },
                                        selectedIndex: 0,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 100,
                                      child: KyberTabBar(
                                        tabs: [
                                          Icon(
                                            (data?.viewerEndorsed ?? false)
                                                ? mt.Icons.thumb_up_alt
                                                : mt
                                                      .Icons
                                                      .thumb_up_alt_outlined,
                                          ),
                                          const Icon(mt.Icons.share),
                                        ],
                                        onChanged: (value) async {
                                          if (value == 0) {
                                            if (data?.viewerEndorsed ?? false) {
                                              await nexusGqlClient!
                                                  .mutate$abstainFromModEndorsement(
                                                    .new(
                                                      variables: .new(
                                                        modUid: data!.uid,
                                                      ),
                                                    ),
                                                  );
                                            } else {
                                              final resp = await nexusGqlClient!
                                                  .mutate$endorseMod(
                                                    .new(
                                                      variables: .new(
                                                        modUid: data!.uid,
                                                      ),
                                                    ),
                                                  );
                                              if (resp.exception != null &&
                                                  resp
                                                      .exception!
                                                      .graphqlErrors
                                                      .isNotEmpty) {
                                                final error = resp
                                                    .exception!
                                                    .graphqlErrors
                                                    .first;
                                                var message = error.message;
                                                if (error.extensions?['code'] ==
                                                    'NOT_DOWNLOADED_MOD') {
                                                  message =
                                                      'You must download the mod before endorsing it';
                                                } else if (error
                                                        .extensions?['code'] ==
                                                    'TOO_SOON_AFTER_DOWNLOAD') {
                                                  message =
                                                      'You must wait some time after downloading the mod before endorsing it';
                                                } else if (error
                                                        .extensions?['code'] ==
                                                    'UNAUTHORIZED') {
                                                  message =
                                                      'You must be logged in to endorse mods';
                                                }

                                                Logger.root.severe(
                                                  'Error endorsing mod: $message; Code: ${error.extensions?['code']}',
                                                );
                                                NotificationService.showNotification(
                                                  message: message,
                                                  severity:
                                                      InfoBarSeverity.error,
                                                );
                                                return;
                                              }
                                            }
                                            await refetch!();
                                            return;
                                          }

                                          if (value == 1) {
                                            await Clipboard.setData(
                                              .new(
                                                text:
                                                    'https://www.nexusmods.com/starwarsbattlefront22017/mods/${data?.modId}',
                                              ),
                                            );
                                            NotificationService.success(
                                              message:
                                                  'Link copied to clipboard',
                                            );
                                          }
                                        },
                                        selectedIndex: -1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                // FORMAT LIKE THIS: 08/08/2021 12:00:00
                                children: [
                                  const Text(
                                    'Updated: ',
                                    style: TextStyle(
                                      color: kWhiteColor,
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    DateFormat.yMd().add_jm().format(
                                      .tryParse(data?.updatedAt ?? '') ??
                                          DateTime.now(),
                                    ),
                                    style: const TextStyle(
                                      color: kWhiteColor,
                                      fontFamily: FontFamily.battlefrontUI,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (data != null)
                          Expanded(
                            child: Query$modFiles$Widget(
                              options: .new(
                                variables: .new(
                                  modId: data.modId.toString(),
                                ),
                              ),
                              builder: (result, {fetchMore, refetch}) {
                                if (result.isLoading) {
                                  return const Center(
                                    child: ProgressRing(),
                                  );
                                }

                                if (result.hasException) {
                                  return Center(
                                    child: Text(result.exception.toString()),
                                  );
                                }

                                final files = result.parsedData!.modFiles;

                                // Sort by date descending (newest first)
                                final sorted = [...files]..sort(
                                  (a, b) => b.date.compareTo(a.date),
                                );

                                // Group files by (version, date) — files with
                                // the same version uploaded at the same time
                                // are part of the same upload batch.
                                final groups = _groupByVersionBatch(sorted);

                                final mainFiles = groups
                                    .where((g) => g.category == .MAIN)
                                    .toList();
                                final optionalFiles = groups
                                    .where((g) => g.category == .OPTIONAL)
                                    .toList();
                                final miscFiles = groups
                                    .where(
                                      (g) => g.category == .MISCELLANEOUS,
                                    )
                                    .toList();
                                final archivedFiles = groups
                                    .where((g) => g.category == .ARCHIVED)
                                    .toList();
                                return SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      const ContainerSeparator(),
                                      _FileList(
                                        title: 'MAIN FILES',
                                        initialExpanded: true,
                                        groups: mainFiles,
                                      ),
                                      if (miscFiles.isNotEmpty)
                                        _FileList(
                                          title: 'MISCELLANEOUS FILES',
                                          groups: miscFiles,
                                        ),
                                      if (optionalFiles.isNotEmpty)
                                        _FileList(
                                          title: 'OPTIONAL FILES',
                                          groups: optionalFiles,
                                        ),
                                      if (archivedFiles.isNotEmpty)
                                        _FileList(
                                          title: 'ARCHIVED FILES',
                                          groups: archivedFiles,
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A group of mod files uploaded together as a version batch.
class _VersionFileGroup {
  _VersionFileGroup({
    required this.version,
    required this.date,
    required this.category,
    required this.files,
  });

  final String version;
  final int date;
  final Enum$ModFileCategory category;
  final List<Query$modFiles$modFiles> files;

  int get totalFiles => files.length;
}

/// Groups files by version so all files sharing the same version are
/// displayed as a single group. Expects input already sorted by date
/// descending (newest version first).
List<_VersionFileGroup> _groupByVersionBatch(
  List<Query$modFiles$modFiles> files,
) {
  final groups = <_VersionFileGroup>[];
  for (final file in files) {
    final existing = groups.cast<_VersionFileGroup?>().firstWhere(
      (g) => g!.version == file.version,
      orElse: () => null,
    );
    if (existing != null) {
      existing.files.add(file);
    } else {
      groups.add(
        _VersionFileGroup(
          version: file.version,
          date: file.date,
          category: file.category,
          files: [file],
        ),
      );
    }
  }
  return groups;
}

class _FileList extends StatefulWidget {
  const _FileList({
    required this.title,
    required this.groups,
    this.initialExpanded = false,
  });

  final String title;
  final bool initialExpanded;
  final List<_VersionFileGroup> groups;

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  late bool _expanded;

  int get totalFiles =>
      widget.groups.fold(0, (sum, g) => sum + g.totalFiles);

  @override
  void initState() {
    _expanded = widget.initialExpanded;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: Colors.black.withOpacity(.7),
          child: ButtonBuilder(
            onClick: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            builder: (context, hovered) {
              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: hovered ? kActiveColor : kInactiveColor,
                  shadows: hovered
                      ? <Shadow>[
                          .new(
                            color: kActiveColor.withOpacity(.4),
                            blurRadius: 5,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const .symmetric(
                          horizontal: 10,
                          vertical: 2.5,
                        ),
                        child: Text(
                          '${widget.title.toUpperCase()} ($totalFiles)',
                          style: const .new(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    Icon(
                      _expanded
                          ? mt.Icons.arrow_drop_up
                          : mt.Icons.arrow_drop_down,
                      color: hovered ? kActiveColor : kInactiveColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              );
            },
          ),
        ),
        const ContainerSeparator(),
        if (_expanded)
          ColoredBox(
            color: Colors.black.withOpacity(.4),
            child: ListView.builder(
              padding: .zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.groups.length,
              itemBuilder: (context, groupIndex) {
                final group = widget.groups[groupIndex];
                final formattedDate = DateFormat.yMd().add_jm().format(
                  DateTime.fromMillisecondsSinceEpoch(group.date * 1000),
                );
                return Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    // Group header: version + date
                    ColoredBox(
                      color: Colors.white.withOpacity(.05),
                      child: Padding(
                        padding: const .symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'v${group.version}',
                                style: const .new(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 13,
                                  color: kGrayColor,
                                ),
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: const .new(
                                fontFamily: FontFamily.battlefrontUI,
                                fontSize: 11,
                                color: kGrayColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const ContainerSeparator(),
                    // Individual files within the version group
                    ...group.files.map((file) {
                      final isInstalled = ModHelper.isInstalled(
                        file.name,
                        file.version,
                      );
                      return ButtonBuilder(
                        onClick: () {
                          showKyberDialog(
                            context: context,
                            builder: (_) => FileDownloadDialog(
                              file: file,
                              modId: file.modId.toString(),
                            ),
                          );
                        },
                        builder: (context, hovered) {
                          return AbsorbPointer(
                            child: AnimatedDefaultTextStyle(
                              duration: const .new(milliseconds: 150),
                              style: TextStyle(
                                fontFamily: FontFamily.battlefrontUI,
                                color: hovered ? kActiveColor : kWhiteColor,
                              ),
                              child: Container(
                                padding: const .symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 8),
                                    Icon(
                                      FluentIcons.download,
                                      color:
                                          isInstalled
                                              ? kActiveColor.withOpacity(.6)
                                              : kWhiteColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: .start,
                                        children: [
                                          AutoSizeText(
                                            file.name,
                                            maxLines: 1,
                                            minFontSize: 14,
                                          ),
                                          if (group.files.length > 1)
                                            Text(
                                              'Part of v${group.version} batch (${group.totalFiles} files)',
                                              style: const .new(
                                                fontSize: 10,
                                                color: kGrayColor,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isInstalled)
                                      Container(
                                        margin: const .only(right: 8),
                                        padding: const .symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: kActiveColor.withOpacity(.15),
                                          borderRadius: .circular(4),
                                          border: .all(
                                            color: kActiveColor.withOpacity(.3),
                                          ),
                                        ),
                                        child: Text(
                                          'INSTALLED',
                                          style: .new(
                                            fontSize: 10,
                                            color: kActiveColor,
                                            fontFamily:
                                                FontFamily.battlefrontUI,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      formatBytes(
                                        int.parse(file.sizeInBytes ?? '0'),
                                        1,
                                      ),
                                      style: const .new(color: kGrayColor),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                    if (groupIndex < widget.groups.length - 1)
                      const ContainerSeparator(),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}

class ContainerSeparatorH extends StatelessWidget {
  const ContainerSeparatorH({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: .infinity,
      color: decoColor,
    );
  }
}

class ContainerSeparator extends StatelessWidget {
  const ContainerSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      color: decoColor,
    );
  }
}

class SidebarItem extends StatelessWidget {
  const SidebarItem({
    required this.title,
    required this.subtitle,
    this.subtitleWidget,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? subtitleWidget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const .new(
            height: 1,
            fontFamily: FontFamily.battlefrontUI,
            fontSize: 16,
            color: kInactiveColor,
          ),
          maxLines: 2,
        ),
        subtitleWidget ??
            Text(
              subtitle,
              style: const .new(
                fontFamily: FontFamily.battlefrontUI,
                fontSize: 19,
              ),
            ),
      ],
    );
  }
}
