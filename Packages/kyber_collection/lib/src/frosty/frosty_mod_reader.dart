import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kyber_collection/src/frosty/base_mod_resource.dart';
import 'package:kyber_collection/src/frosty/types/frosty_custom_data.dart';
import 'package:kyber_collection/src/mod_collection.dart';
import 'package:kyber_collection/src/utils/file_byte_reader.dart';

part 'frosty_mod_reader.g.dart';

const _kFrostyMagic = 0x01005954534F5246;
const _kFrostyVersion = 1;

class ModReader extends FileByteReader {
  ModReader(super.file, [this.filename]);

  final String? filename;
  late int readerVersion;
  int? _dataOffset;
  int? _dataCount;

  Int64List? _entryOffsets;
  Int64List? _entrySizes;

  void _loadEntryTable() {
    file.setPositionSync(_dataOffset!);
    final bytes = file.readSync(_dataCount! * 16);
    final bd = ByteData.sublistView(bytes);
    _entryOffsets = Int64List(_dataCount!);
    _entrySizes   = Int64List(_dataCount!);
    for (var i = 0; i < _dataCount!; i++) {
      _entryOffsets![i] = bd.getInt64(i * 16, Endian.little);
      _entrySizes![i]   = bd.getInt64(i * 16 + 8, Endian.little);
    }
  }


  Uint8List? readResource(BaseModResource resource, [FrostyMod? mod]) {
    if (resource.resourceIndex == -1) {
      return null;
    }

    if (mod != null) {
      _initializeReader(mod);
    }

    if (_entryOffsets == null || _entrySizes == null) {
      _loadEntryTable();
    }

    final idx = resource.resourceIndex!;
    final off = _entryOffsets![idx];
    final size = _entrySizes![idx];

    final dataBase = _dataOffset! + (_dataCount! * 16);

    file.setPositionSync(dataBase + off);

    return file.readSync(size);
  }

  List<BaseModResource> _readResources({ModResourceType? type, int? limit}) {
    final count = readInt();
    final resources = <BaseModResource>[];
    final maxResources = switch(limit) {
      null => count,
      _ when limit < 0 => count,
      _ when limit > count => count,
      _ => limit,
    };

    for (var i = 0; i < maxResources; i++) {
      final byte = readByte();
      if (byte > 4) {
        resources.add(BaseModResource(ModResourceType.Invalid));
        continue;
      }

      final resource = BaseModResource(ModResourceType.values.elementAt(byte));
      if (type != null && type != resource.type) {
        break;
      }

      resources.add(resource);

      resource.read(this, readerVersion);
    }

    return resources;
  }

  void _initializeReader(FrostyMod mod) {
    readerVersion = mod.version;
    offset = mod.offset;
    _dataCount = mod.dataCount;
    _dataOffset = mod.dataOffset;
    _entryOffsets = null;
    _entrySizes = null;
    file.setPositionSync(offset);
  }

  List<BaseModResource> readResources(FrostyMod mod) {
    try {
      _initializeReader(mod);
      file.setPositionSync(offset);
      return _readResources();
    } finally {
      file.closeSync();
    }
  }

  List<Uint8List> readScreenshots(FrostyMod mod) {
    try {
      if (mod.isCollection) {
        return [];
      }

      _initializeReader(mod);
      file.setPositionSync(offset);
      final resources = _readResources(limit: 5);
      return resources.map(readResource).skip(1).whereType<Uint8List>().toList();
    } finally {
      file.closeSync();
    }
  }

  FrostyMod? readMod() {
    try {
      final magic = readUint64();
      final version = readUint32();
      if (magic != _kFrostyMagic || version < _kFrostyVersion) {
        return null;
      }

      readerVersion = version;

      _dataOffset = readUint64();
      _dataCount = readUint32();
      final profile = readSizedString();
      if (profile.toLowerCase() != 'starwarsbattlefrontii') {
        return null;
      }

      final gameVersion = readUint32();
      final title = readTerminatedString();
      final author = readTerminatedString();
      final category = readTerminatedString();
      final modVersion = readTerminatedString();
      final description = readTerminatedString();

      String? link;
      if (version >= 5) {
        link = readTerminatedString();
      }

      if (link != null && link.isEmpty) {
        link = null;
      }

      final resourceOffset = offset;
      final size = file.lengthSync();
      Uint8List? icon;
      CustomFrostyData? customData;
      if (category == 'Map' || category == 'Maps' || category == 'Gameplay') {
        final resources = _readResources(limit: 6);
        final parsedResources = resources.map(readResource).toList();
        icon = parsedResources.isNotEmpty ? parsedResources.first : null;
        try {
          customData = parsedResources.isNotEmpty && parsedResources.last != null
              ? CustomFrostyData.fromJson(jsonDecode(String.fromCharCodes(parsedResources.last!)) as Map<String, dynamic>)
              : null;
        } catch (_) {}
      } else {
        final resources = _readResources(limit: 1);
        icon = readResource(resources.first);
      }

      return FrostyMod(
        version: version,
        gameVersion: gameVersion,
        filename: filename!,
        icon: icon,
        size: size,
        dataCount: _dataCount!,
        dataOffset: _dataOffset!,
        offset: resourceOffset,
        customFrostyData: customData,
        details: FrostyModDetails(
          title,
          author,
          category,
          modVersion,
          description,
          link,
        ),
      );
    } finally {
      file.closeSync();
    }
  }
}

@JsonSerializable(explicitToJson: true)
class FrostyMod {
  FrostyMod({
    required this.version,
    required this.gameVersion,
    required this.filename,
    required this.details,
    this.isCollection = false,
    this.size = 0,
    this.offset = 0,
    this.dataCount = 0,
    this.dataOffset = 0,
    this.screenshotOffset = 0,
    this.mods,
    this.modVersions,
    this.icon,
    this.customFrostyData,
  });

  int version;
  int gameVersion;
  String filename;
  int size;
  int dataOffset;
  int dataCount;
  int offset;
  int screenshotOffset = 0;
  bool isCollection;
  CustomFrostyData? customFrostyData;
  @Uint8ListConverter()
  Uint8List? icon;
  List<String>? mods;
  List<String>? modVersions;
  FrostyModDetails details;

  Map<String, dynamic> toJson() => _$FrostyModToJson(this);

  factory FrostyMod.fromJson(Map<String, dynamic> json) => _$FrostyModFromJson(json);

  CollectionMod toCollectionMod({bool exportFile = false}) {
    return CollectionMod(
      name: details.name,
      version: details.version,
      link: details.link ?? '',
      filename: filename,
      mods: mods,
      isCollection: isCollection,
    );
  }

  String toString() {
    return '{${details.name} ${details.version} ${details.author} ${details.category} ${details.description} ${details.link}}';
  }

  String toKyberString() {
    return '${details.name} (${details.version})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FrostyMod &&
        version == other.version &&
        gameVersion == other.gameVersion &&
        filename == other.filename &&
        size == other.size &&
        dataOffset == other.dataOffset &&
        dataCount == other.dataCount &&
        offset == other.offset &&
        isCollection == other.isCollection &&
        const ListEquality().equals(mods, other.mods) &&
        details == other.details;
  }
}

@JsonSerializable()
class FrostyModDetails {
  FrostyModDetails(
      this.name,
      this.author,
      this.category,
      this.version,
      this.description, [
        this.link,
      ]);

  String name;
  String author;
  String category;
  String version;
  String description;
  String? link;

  Map<String, dynamic> toJson() => _$FrostyModDetailsToJson(this);

  factory FrostyModDetails.fromJson(Map<String, dynamic> json) => _$FrostyModDetailsFromJson(json);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FrostyModDetails &&
        name == other.name &&
        author == other.author &&
        category == other.category &&
        version == other.version &&
        description == other.description &&
        link == other.link;
  }
}

enum ModResourceType {
  Embedded,
  Ebx,
  Res,
  Chunk,
  Bundle,
  Invalid,
}

class Uint8ListConverter implements JsonConverter<Uint8List?, String?> {
  const Uint8ListConverter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null) return null;
    return Uint8List.fromList(base64Decode(json));
  }

  @override
  String? toJson(Uint8List? object) {
    if (object == null) return null;
    return base64Encode(object);
  }
}
