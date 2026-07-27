import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_details/mod_images.dart';
import 'package:kyber_launcher/features/mods/helper/frosty_mod_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_dropdown.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ModInfoBox extends StatefulWidget {
  const ModInfoBox({required this.mod, required this.onClose, super.key});

  final FrostyMod mod;
  final VoidCallback onClose;

  @override
  State<ModInfoBox> createState() => _ModInfoBoxState();
}

class _ModInfoBoxState extends State<ModInfoBox> {
  static final _log = Logger('mod_info_box');

  List<Uint8List> screenshots = <Uint8List>[];
  Map<String, List<String>>? affectedFiles;
  bool affectedFilesExpanded = false;
  int? _nexusModId;
  bool _lookupDone = false;

  @override
  void initState() {
    Timer.run(() {
      final file = File(join(ModService.getBasePath(), widget.mod.filename));
      if (widget.mod.isCollection) {
        final screenshots = FrostyCollectionReader(
          file.openSync(),
          '',
        ).readScreenshots(widget.mod);
        setState(() {
          this.screenshots = screenshots;
        });
      } else {
        final screenshots = ModReader(
          file.openSync(),
        ).readScreenshots(widget.mod);
        setState(() {
          this.screenshots = screenshots;
        });
      }
    });
    _resolveNexusModId();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ModInfoBox oldWidget) {
    if (oldWidget.mod.details.description != widget.mod.details.description) {
      setState(() {
        affectedFiles = null;
        affectedFilesExpanded = false;
      });
    }

    if (!widget.mod.isCollection) {
      final file = File(join(ModService.getBasePath(), widget.mod.filename));
      final screenshots = ModReader(
        file.openSync(),
      ).readScreenshots(widget.mod);
      setState(() {
        affectedFiles = null;
        this.screenshots = screenshots;
      });
    }

    if (oldWidget.mod.details.name != widget.mod.details.name ||
        oldWidget.mod.details.link != widget.mod.details.link) {
      _nexusModId = null;
      _lookupDone = false;
      _resolveNexusModId();
    }

    super.didUpdateWidget(oldWidget);
  }

  /// Resolves the NexusMods ID for this installed mod. Checks in order:
  /// 1. Global `nexus_mod_manifest.json` (written at download time)
  /// 2. Frosty mod `link` field → backfills manifest if found
  /// If neither source provides an ID the button is hidden.
  Future<void> _resolveNexusModId() async {
    // 1. Check global manifest file
    try {
      final manifestFile = File(
        join(ModService.getBasePath(), 'nexus_mod_manifest.json'),
      );
      if (await manifestFile.exists()) {
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        final normalizedName = basename(widget.mod.filename);
        final files = manifest['files'] as Map<String, dynamic>?;
        final id = files != null
            ? (files[widget.mod.filename] ?? files[normalizedName])
            : (manifest[widget.mod.filename] ?? manifest[normalizedName]);
        if (id != null) {
          final modId = (id as num).toInt();
          if (mounted) setState(() => _nexusModId = modId);
          _lookupDone = true;
          return;
        }
        // Fallback: match by mod title in the "mods" section
        final modsSection = manifest['mods'] as Map<String, dynamic>?;
        if (modsSection != null) {
          final modName = widget.mod.details.name;
          for (final entry in modsSection.entries) {
            final meta = entry.value as Map<String, dynamic>?;
            final title = meta?['title'] as String? ?? '';
            if (title.toLowerCase() == modName.toLowerCase()) {
              final modId = int.parse(entry.key);
              if (mounted) setState(() => _nexusModId = modId);
              _lookupDone = true;
              return;
            }
          }
        }
      }
    } catch (_) {}

    // 2. Try extracting from the link field and backfill the manifest
    final link = widget.mod.details.link;
    if (link != null && link.isNotEmpty) {
      final id = _extractNexusModId(link);
      if (id != null) {
        _writeManifestEntry(id);
        if (mounted) setState(() => _nexusModId = id);
        _lookupDone = true;
        return;
      }
    }

    _lookupDone = true;
  }

  /// Writes a resolved modId to the manifest so future lookups are instant.
  void _writeManifestEntry(int modId) {
    try {
      final manifestFile = File(
        join(ModService.getBasePath(), 'nexus_mod_manifest.json'),
      );
      Map<String, dynamic> manifest;
      if (manifestFile.existsSync()) {
        try {
          manifest =
              jsonDecode(manifestFile.readAsStringSync())
                  as Map<String, dynamic>;
        } catch (_) {
          manifest = <String, dynamic>{};
        }
      } else {
        manifest = <String, dynamic>{};
      }

      final files =
          (manifest['files'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final mods =
          (manifest['mods'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      files[basename(widget.mod.filename)] = modId;
      mods[modId.toString()] = <String, dynamic>{
        'title': widget.mod.details.name,
        'latestVersion': widget.mod.details.version,
        'lastDownloaded': DateTime.now().toIso8601String(),
      };

      manifest['files'] = files;
      manifest['mods'] = mods;

      manifestFile.writeAsStringSync(jsonEncode(manifest));
      _log.info(
        'Backfilled manifest: ${widget.mod.filename} → $modId',
      );
    } catch (e) {
      _log.warning('Failed to write manifest entry: $e');
    }
  }

  Future<void> readAffectedFiles() async {
    final path = ModService.getBasePath();
    var data = <String, List<String>>{};

    if (widget.mod.isCollection) {
      final mods = widget.mod.getCollectionMods();
      final results = await compute(_readFilesInIsolate, {
        'path': path,
        'mods': mods,
      });
      data = results.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    } else {
      final modJson = jsonEncode(widget.mod.toJson());
      final results = await compute(_readFileInIsolate, {
        'path': path,
        'modJson': modJson,
      });
      data = results.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      affectedFiles = data;
    });
  }

  static Map<String, List<String>> _readChunkedFilesInIsolate(
    Map<String, dynamic> args,
  ) {
    final mods = args['mods'] as List<FrostyMod>;
    final affectedFiles = <String, List<String>>{};
    for (final mod in mods) {
      final reader = ModReader(
        File(join(args['path'] as String, mod.filename)).openSync(),
      );
      final resources = _readResources(reader, mod);
      for (final entry in resources.entries) {
        affectedFiles.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }
    }

    return affectedFiles;
  }

  static Future<Map<String, List<String>>> _readFilesInIsolate(
    Map<String, dynamic> args,
  ) async {
    final path = args['path']! as String;

    final cores = Platform.numberOfProcessors - 2;
    final mods = (args['mods'] as List<FrostyMod>)..shuffle();
    final chunkSize = (mods.length / cores).ceil();
    final futures = <Future<Map<String, List<String>>>>[];

    for (var i = 0; i < cores; i++) {
      final chunk = mods.skip(i * chunkSize).take(chunkSize).toList();
      futures.add(
        compute(_readChunkedFilesInIsolate, {
          'path': path,
          'mods': chunk,
        }),
      );
    }

    final results = await Future.wait(futures);
    final affectedFiles = <String, List<String>>{};

    for (final result in results) {
      for (final entry in result.entries) {
        affectedFiles.addAll({entry.key: entry.value});
      }
    }

    return affectedFiles;
  }

  static Map<String, List<String>> _readFileInIsolate(
    Map<String, dynamic> args,
  ) {
    final path = args['path']! as String;
    final modJson = args['modJson']! as String;

    final mod = FrostyMod.fromJson(jsonDecode(modJson) as Map<String, dynamic>);
    final reader = ModReader(File(join(path, mod.filename)).openSync());

    return _readResources(reader, mod);
  }

  static Map<String, List<String>> _readResources(
    ModReader reader,
    FrostyMod mod,
  ) {
    final resources = reader.readResources(mod);

    final affectedFiles = <String, List<String>>{};
    for (final resource in resources.skip(5)) {
      final name = resource.type.toString().split('.').last;
      affectedFiles
          .putIfAbsent(name, () => [])
          .add(resource.name ?? 'Unknown resource name');
    }

    return affectedFiles;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackgroundBlur(
        child: Container(
          key: const Key('mod'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: decoColor,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 61,
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MOD INFORMATION',
                              style: TextStyle(
                                fontFamily: FontFamily.battlefrontUI,
                                fontSize: 21,
                                height: 1,
                              ),
                            ),
                            Text(
                              'VIEW INFORMATION ABOUT A MOD',
                              style: TextStyle(
                                fontFamily: FontFamily.battlefrontUI,
                                fontSize: 14,
                                color: kWhiteColor,
                                height: 0.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      KyberIconButton(
                        onPressed: widget.onClose,
                        iconData: mt.Icons.close,
                      ),
                    ],
                  ),
                ),
                const CardSection(),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(15),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              SizedBox(
                                height: 45,
                                width: 45,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    kDefaultInnerBorderRadius,
                                  ),
                                  child: widget.mod.icon != null
                                      ? Image.memory(
                                          widget.mod.icon!,
                                          fit: BoxFit.cover,
                                        )
                                      : const Placeholder(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.mod.details.name,
                                      style: const TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 19,
                                        height: 1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${widget.mod.details.version} - ${widget.mod.details.author}',
                                      style: const TextStyle(
                                        fontFamily: FontFamily.battlefrontUI,
                                        fontSize: 15,
                                        color: kWhiteColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Builder(
                                builder: (builderContext) {
                                  final modId = _nexusModId;
                                  if (modId == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: KyberIconButton(
                                      onPressed: () {
                                        router.go(
                                          '/mods/mod_browser/$modId',
                                        );
                                      },
                                      iconData: mt.Icons.open_in_new,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: CardSection()),
                      if (widget.mod.details.description.trim().isNotEmpty)
                        SliverToBoxAdapter(
                          child: KyberSectionDropdown(
                            initialExpanded: true,
                            title: 'DESCRIPTION',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                    horizontal: 10,
                                  ).copyWith(bottom: 15),
                                  child: MarkdownBody(
                                    data: widget.mod.details.description,
                                    onTapLink: (text, href, title) =>
                                        href != null
                                        ? launchUrlString(href)
                                        : null,
                                    styleSheet: MarkdownStyleSheet(
                                      a: TextStyle(
                                        color: kActiveColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const CardSection(),
                              ],
                            ),
                          ),
                        ),
                      if (screenshots
                          .skip(widget.mod.isCollection ? 0 : 1)
                          .isNotEmpty)
                        SliverToBoxAdapter(
                          child: KyberSectionDropdown(
                            title: 'IMAGES',
                            child: Column(
                              children: [
                                SuperListView.builder(
                                  shrinkWrap: true,
                                  itemCount: screenshots.length,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 15,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = screenshots[index];

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (index != 0)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            child: CustomPaint(
                                              painter: DashedLinePainter(),
                                              child: const SizedBox(height: 2),
                                            ),
                                          ),
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: ButtonBuilder(
                                            onClick: () {},
                                            builder: (context, hovered) {
                                              return AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 150,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: hovered
                                                        ? kActiveColor
                                                        : decoColor,
                                                    width: 2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  child: Image.memory(
                                                    item,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const CardSection(),
                              ],
                            ),
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: KyberSectionDropdown(
                          expanded: affectedFilesExpanded,
                          onExpanded: (bool expanded) {
                            setState(() {
                              affectedFilesExpanded = expanded;
                            });

                            if (expanded && affectedFiles == null) {
                              readAffectedFiles();
                            }
                          },
                          title: 'AFFECTED FILES',
                          child: const SizedBox.shrink(),
                        ),
                      ),
                      if (!affectedFilesExpanded)
                        const SliverToBoxAdapter(child: CardSection()),
                      if (affectedFilesExpanded)
                        if (affectedFiles == null)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 25,
                                  height: 25,
                                  child: ProgressRing(),
                                ),
                              ),
                            ),
                          )
                        else
                          _buildAffectedFilesSliverList(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAffectedFilesSliverList() {
    final totalItemCount = affectedFiles!.values.fold(
      0,
      (sum, list) => sum + list.length,
    );

    return SuperSliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          var currentIndex = index;
          String? key;
          String? value;

          for (final e in affectedFiles!.entries) {
            if (currentIndex < e.value.length) {
              key = e.key;
              value = e.value[currentIndex];
              break;
            } else {
              currentIndex -= e.value.length;
            }
          }

          if (key == null || value == null) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: kWhiteColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    key.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: FontFamily.battlefrontUI,
                      fontSize: 11,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: FontFamily.battlefrontUI,
                      fontSize: 13,
                      color: kWhiteColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
        childCount: totalItemCount,
      ),
    );
  }
}

/// Extracts the numeric mod ID from a NexusMods URL. Handles formats like:
/// - https://www.nexusmods.com/starwarsbattlefront22017/mods/12345
/// - https://www.nexusmods.com/starwarsbattlefront22017/mods/12345?tab=files
/// Returns null if the URL doesn't match the expected pattern.
int? _extractNexusModId(String url) {
  final match =
      RegExp(r'nexusmods\.com/\w+/mods/(\d+)').firstMatch(url);
  return match != null ? int.tryParse(match.group(1)!) : null;
}

class _AffectedFileEntry {
  _AffectedFileEntry({required this.key, required this.value});

  final String key;
  final String value;
}
