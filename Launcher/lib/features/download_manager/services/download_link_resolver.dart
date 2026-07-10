import 'package:dio/dio.dart';
import 'package:kyber/gen/Proto/mod_bridge.pb.dart';
import 'package:kyber_launcher/features/download_manager/models/download_link_type.dart';
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/services/mod_bridge_service.dart';
import 'package:kyber_launcher/features/nexusmods/services/download_service.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class ResolvedDownload {
  const ResolvedDownload({
    required this.url,
    required this.filename,
    required this.type,
    this.size,
  });

  final String url;
  final String filename;
  final DownloadLinkType type;
  final int? size;
}

class DownloadLinkResolver {
  DownloadLinkResolver({
    ModBridgeGRPCService? modBridgeService,
  }) : _modBridgeService = modBridgeService ?? sl.get<ModBridgeGRPCService>();

  final ModBridgeGRPCService _modBridgeService;
  final Logger _logger = Logger('download_link_resolver');

  Future<ResolvedDownload> resolve(DownloadRequest request) async {
    switch (request.linkType) {
      case DownloadLinkType.nxm:
        return _resolveNxmLink(request);

      case DownloadLinkType.nexus:
        return _resolveNexusLink(request);

      case DownloadLinkType.direct:
        return _resolveDirectLink(request);

      case DownloadLinkType.kyber:
        return _resolveKyberLink(request);
    }
  }

  Future<ResolvedDownload> _resolveNxmLink(DownloadRequest request) async {
    try {
      final uri = Uri.parse(request.link);
      final downloadUrl = await sl.get<NexusModsService>().generateDownloadLink(
        uri,
      );
      final filename =
          request.filename ??
          await NexusDownloadService.resolveNexusFileName(
            modId: int.parse(uri.pathSegments[1]),
            fileId: int.parse(uri.pathSegments.last),
            urlFallback: downloadUrl,
          );

      _logger.info('Resolved NXM link to: $filename');

      return ResolvedDownload(
        url: downloadUrl,
        filename: request.filename ?? filename,
        type: DownloadLinkType.nxm,
        size: request.size,
      );
    } catch (e, s) {
      _logger.severe('Failed to resolve NXM link', e, s);
      rethrow;
    }
  }

  Future<ResolvedDownload> _resolveNexusLink(DownloadRequest request) async {
    try {
      final (url, filename) = await NexusDownloadService.getNexusDownload(
        request.link,
      );

      _logger.info('Resolved Nexus link to: $filename');

      return ResolvedDownload(
        url: url,
        filename: filename,
        type: DownloadLinkType.nexus,
        size: request.size,
      );
    } catch (e, s) {
      _logger.severe('Failed to resolve Nexus link', e, s);
      rethrow;
    }
  }

  Future<ResolvedDownload> _resolveDirectLink(DownloadRequest request) async {
    var filename =
        request.filename ?? request.link.split('/').last.split('?').first;
    var size = request.size;

    if (filename.isEmpty || !filename.contains('.') || size == null) {
      try {
        _logger.info('HEAD request: ${request.link}');
        final resp = await Dio().head<void>(
          request.link,
          options: Options(),
        );

        size ??= int.tryParse(resp.headers.value('content-length') ?? '');

        final contentDisposition = resp.headers.value('content-disposition');
        if (contentDisposition != null) {
          final match = RegExp(
            'filename="(.+)"',
          ).firstMatch(contentDisposition);
          if (match != null) {
            filename = match.group(1)!;
          }
        }

        _logger.info('Resolved direct link - Size: $size, Filename: $filename');
      } catch (e, s) {
        _logger.warning('HEAD request failed, using fallback filename', e, s);
      }
    }

    return ResolvedDownload(
      url: request.link,
      filename: filename,
      type: DownloadLinkType.direct,
      size: size,
    );
  }

  Future<ResolvedDownload> _resolveKyberLink(DownloadRequest request) async {
    try {
      final parts = request.link.split('(');
      if (parts.length < 2) {
        throw Exception('Invalid Kyber link format: ${request.link}');
      }

      final modName = parts[0].trim();
      final modVersion = parts[1].split(')')[0].trim();

      final response = await _modBridgeService.searchClient.searchMod(
        SearchModRequest(
          modName: modName,
          modVersion: modVersion,
        ),
      );

      final downloadUrl = response.mod.link;
      final filename = downloadUrl.split('/').last.split('?').first;
      final size = response.mod.fileSize.toInt();

      _logger.info('Resolved Kyber link to: $filename ($size bytes)');

      return ResolvedDownload(
        url: downloadUrl,
        filename: request.filename ?? filename,
        type: DownloadLinkType.kyber,
        size: size,
      );
    } catch (e, s) {
      _logger.severe('Failed to resolve Kyber link', e, s);
      rethrow;
    }
  }
}
