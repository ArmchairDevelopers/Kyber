import 'package:kyber_collection/kyber_collection.dart';

/// A group of installed mods that share the same NexusMods mod ID.
/// Mods not found in the manifest appear as individual groups
/// with [title] and [modId] set to null.
class ModListGroup {
  const ModListGroup({
    this.title,
    this.modId,
    this.latestVersion,
    this.lastDownloaded,
    required this.mods,
  });

  final String? title;
  final int? modId;
  final String? latestVersion;
  final String? lastDownloaded;
  final List<FrostyMod> mods;

  String get displayName => title ?? mods.first.details.name;
  bool get isNamed => title != null && modId != null;
}