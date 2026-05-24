class LanServerMod {
  const LanServerMod({
    required this.name,
    required this.version,
  });

  factory LanServerMod.fromJson(Map<String, dynamic> json) {
    return LanServerMod(
      name: json['name'] as String? ?? '',
      version: json['version'] as String? ?? '',
    );
  }

  factory LanServerMod.parseEntry(dynamic entry) {
    if (entry is Map<String, dynamic>) {
      return LanServerMod.fromJson(entry);
    }

    if (entry is String) {
      final separator = entry.lastIndexOf('@');
      if (separator > 0) {
        return LanServerMod(
          name: entry.substring(0, separator),
          version: entry.substring(separator + 1),
        );
      }
    }

    return const LanServerMod(name: '', version: '');
  }

  final String name;
  final String version;

  String get key => '$name@$version';

  @override
  bool operator ==(Object other) {
    return other is LanServerMod && other.name == name && other.version == version;
  }

  @override
  int get hashCode => Object.hash(name, version);
}
