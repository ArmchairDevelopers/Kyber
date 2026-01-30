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
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/features/nexusmods/widgets/graphql_provider.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tab_bar.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:logging/logging.dart';
import 'package:nexus_bridge/nexus_bridge.dart';
import 'package:nexus_gql/nexus_gql.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

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
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Query$modByUID$Widget(
      options: .new(
        variables: .new(uid: .parse(widget.id)),
        cacheRereadPolicy: .ignoreAll,
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

        final data = result.parsedData?.legacyMods.nodes.firstOrNull;
        final isLoading = result.isLoading;

        if (!isLoading && data == null) {
          return Center(
            child: Text(l10n.noDataFound),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: .start,
                                    children: [
                                      Text(
                                        l10n.modInformation,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontFamily: currentFont,
                                          height: 1,
                                        ),
                                      ),
                                      Text(
                                        l10n.viewModFilesShareEndorse,
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
                                        tabs: [
                                          Text(l10n.files),
                                          Text(l10n.posts),
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
                                                  message = l10n.endorseMustDownload;
                                                } else if (error
                                                        .extensions?['code'] ==
                                                    'TOO_SOON_AFTER_DOWNLOAD') {
                                                  message = l10n.endorseWaitTime;
                                                } else if (error
                                                        .extensions?['code'] ==
                                                    'UNAUTHORIZED') {
                                                  message = l10n.endorseLoginRequired;
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
                                              message: l10n.linkCopied,
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
                                  Text(
                                    l10n.updatedAt,
                                    style: TextStyle(
                                      color: kWhiteColor,
                                      fontFamily: currentFont,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    DateFormat.yMd().add_jm().format(
                                      .tryParse(data?.updatedAt ?? '') ??
                                          DateTime.now(),
                                    ),
                                    style: TextStyle(
                                      color: kWhiteColor,
                                      fontFamily: currentFont,
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
                                final mainFiles = files
                                    .where((e) => e.category == .MAIN)
                                    .toList();
                                final optionalFiles = files
                                    .where((e) => e.category == .OPTIONAL)
                                    .toList();
                                final miscFiles = files
                                    .where((e) => e.category == .MISCELLANEOUS)
                                    .toList();
                                final archivedFiles = files
                                    .where((e) => e.category == .ARCHIVED)
                                    .toList();
                                return SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      const ContainerSeparator(),
                                      _FileList(
                                        title: l10n.mainFiles,
                                        initialExpanded: true,
                                        files: mainFiles,
                                      ),
                                      if (miscFiles.isNotEmpty)
                                        _FileList(
                                          title: l10n.miscellaneousFiles,
                                          files: miscFiles,
                                        ),
                                      if (optionalFiles.isNotEmpty)
                                        _FileList(
                                          title: l10n.optionalFiles,
                                          files: optionalFiles,
                                        ),
                                      if (archivedFiles.isNotEmpty)
                                        _FileList(
                                          title: l10n.archivedFiles,
                                          files: archivedFiles,
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

class _FileList extends StatefulWidget {
  const _FileList({
    required this.title,
    required this.files,
    this.initialExpanded = false,
  });

  final String title;
  final bool initialExpanded;
  final List<Query$modFiles$modFiles> files;

  @override
  State<_FileList> createState() => _FileListState();
}

class _FileListState extends State<_FileList> {
  late bool _expanded;

  @override
  void initState() {
    _expanded = widget.initialExpanded;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

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
                          l10n.fileListTitle(widget.title, widget.files.length),
                          style: TextStyle(
                            fontFamily: currentFont,
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
            child: SuperListView.separated(
              itemBuilder: (context, index) {
                if (index == widget.files.length) {
                  return const SizedBox.shrink();
                }

                final file = widget.files[index];
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
                          fontFamily: currentFont,
                          color: hovered ? kActiveColor : kWhiteColor,
                        ),
                        child: Container(
                          padding: const .symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                FluentIcons.download,
                                color: kWhiteColor,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: AutoSizeText(
                                  file.name,
                                  maxLines: 1,
                                  minFontSize: 16,
                                ),
                              ),
                              Text(
                                formatBytes(
                                  int.parse(file.sizeInBytes ?? '0'),
                                  1,
                                ),
                                style: const .new(
                                  color: kGrayColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              separatorBuilder: (context, index) => const ContainerSeparator(),
              padding: .zero,
              itemCount: widget.files.length + 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            height: 1,
            fontFamily: currentFont,
            fontSize: 16,
            color: kInactiveColor,
          ),
          maxLines: 2,
        ),
        subtitleWidget ??
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: currentFont,
                fontSize: 19,
              ),
            ),
      ],
    );
  }
}