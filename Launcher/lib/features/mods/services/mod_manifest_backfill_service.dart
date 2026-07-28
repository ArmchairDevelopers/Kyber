import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/nexusmods/widgets/graphql_provider.dart';
import 'package:logging/logging.dart';
import 'package:nexus_gql/nexus_gql.dart';
import 'package:path/path.dart';

/// Runs a one-time backfill to populate [nexus_mod_manifest.json] for
/// installed mods that were downloaded before the manifest system existed.
///
/// For each unmanifested mod, searches NexusMods by name, then
/// cross-references file versions to find a deterministic match.
/// Only writes an entry when exactly one mod matches both name AND version.
class ModManifestBackfillService {
  ModManifestBackfillService._();

  static final _log = Logger('mod_manifest_backfill');

  static bool _running = false;
  static bool _hasRun = false;

  /// Scans all installed mods and backfills any missing manifest entries.
  /// Safe to call multiple times — skips if already running or already done.
  /// Retries after a delay if the GQL client isn't ready yet.
  static Future<void> backfillAll(List<FrostyMod> installedMods) async {
    if (_running || _hasRun) return;
    _running = true;

    try {
      final client = nexusGqlClient;
      if (client == null) {
        _running = false;
        Future.delayed(const Duration(seconds: 3), () {
          if (!_hasRun) backfillAll(installedMods);
        });
        return;
      }

      // Read current manifest
      final manifest = await ModService.readManifest();

      final files =
          (manifest['files'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final mods =
          (manifest['mods'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      // Build set of sub-mod filenames within collections — these
      // don't have their own NexusMods entries, only the collection does.
      final collectionSubMods = <String>{};
      for (final mod in installedMods) {
        if (mod.isCollection && mod.mods != null) {
          for (final sub in mod.mods!) {
            collectionSubMods.add(basename(sub));
          }
        }
      }

      // Find mods not in the manifest (check by basename).
      // Skip sub-mods that belong to collections.
      final unmanifested = <FrostyMod>[];
      for (final mod in installedMods) {
        final name = basename(mod.filename);
        if (collectionSubMods.contains(name)) continue;
        if (!files.containsKey(name)) {
          if (!(manifest.containsKey(name) && manifest[name] is int)) {
            unmanifested.add(mod);
          }
        }
      }

      _log.info(
        'Backfilling ${unmanifested.length} mods '
        '(skipped ${collectionSubMods.length} collection sub-mods)...',
      );

      if (unmanifested.isEmpty) {
        _hasRun = true;
        _running = false;
        return;
      }

      var backfilled = 0;
      for (final mod in unmanifested) {
        final modId = await _resolveModId(client, mod);
        if (modId != null) {
          files[basename(mod.filename)] = modId;
          mods[modId.toString()] = <String, dynamic>{
            'title': mod.details.name,
            'latestVersion': mod.details.version,
            'lastDownloaded': DateTime.now().toIso8601String(),
          };
          backfilled++;
          manifest['files'] = files;
          manifest['mods'] = mods;
          await ModService.writeManifest(manifest);
        }
      }

      _log.info(
        'Backfill done: $backfilled matched, '
        '${unmanifested.length - backfilled} unmatched '
        '(of ${unmanifested.length} total)',
      );
      _hasRun = true;
    } catch (e) {
      _log.warning('Backfill error: $e');
      _hasRun = true;
    } finally {
      _running = false;
    }
  }

  /// Tries to deterministically resolve a mod's NexusMods ID by searching
  /// by name then cross-referencing file versions. Returns null if not found.
  static Future<int?> _resolveModId(
    GraphQLClient client,
    FrostyMod mod,
  ) async {
    final modName = mod.details.name;
    final installedVersion = mod.details.version;

    // Try full name first, then simplified variants
    final queries = <String>{
      modName,
      modName.replaceAll(RegExp(r'\s*[-–]\s*Kyber(\s*Collection)?$'), ''),
      modName.replaceAll(RegExp(r'\s+V\d[\d.]*$'), ''),
    }.where((q) => q.isNotEmpty).toList();

    for (final query in queries) {
      final result = await _searchModAndMatchVersion(client, query, modName, installedVersion);
      if (result != null) return result;
    }
    return null;
  }

  static Future<int?> _searchModAndMatchVersion(
    GraphQLClient client,
    String query,
    String originalName,
    String installedVersion,
  ) async {
    try {
      final result = await client.query$searchMods(
        .new(
          variables: .new(
            query: query,
            sort: Input$ModsSort(
              downloads: .new(direction: .DESC),
            ),
          ),
        ),
      );

      if (result.hasException) return null;
      if (result.parsedData == null) return null;

      final nodes = result.parsedData!.mods.nodes;
      if (nodes.isEmpty) return null;

      // Match against the original mod name
      final exactMatches = nodes
          .where((n) => n.name.toLowerCase() == originalName.toLowerCase())
          .toList();

      if (exactMatches.isEmpty) {
        // Fuzzy: mod name substring of top result (or vice versa)
        if (nodes.isNotEmpty) {
          final top = nodes.first.name.toLowerCase();
          final q = originalName.toLowerCase();
          if (top.contains(q) || q.contains(top)) {
            return nodes.first.modId;
          }
        }
        return null;
      }

      // If only one mod has this exact name, it's unambiguous — accept it
      if (exactMatches.length == 1) {
        return exactMatches.first.modId;
      }

      // Multiple mods share this name — cross-reference file versions
      // to find a deterministic match
      for (final candidate in exactMatches.take(3)) {
        try {
          final filesResult = await client.query$modFiles(
            .new(
              variables: .new(modId: candidate.modId.toString()),
            ),
          );
          if (filesResult.hasException || filesResult.parsedData == null) {
            continue;
          }

          final files = filesResult.parsedData!.modFiles;
          final versionMatch = files.where(
            (f) => f.version == installedVersion,
          );
          if (versionMatch.isNotEmpty) {
            return candidate.modId;
          }
        } catch (_) {
          continue;
        }
      }
    } catch (e) {
      _log.fine('GQL search failed for query "$query": $e');
    }

    return null;
  }
}
