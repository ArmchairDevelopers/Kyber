import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/nexusmods/dialogs/nexusmods_login.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class NexusDownloadService {
  NexusDownloadService._();

  static Future<(String, String)> getNexusDownload(
    String downloadUrl, {
    int tries = 0,
  }) async {
    if (tries > 2) {
      throw Exception('Failed to download mod after 2 attempts');
    }

    if (sl.get<NexusModsService>().nexusUser?.isPremium ?? false) {
      final uri = Uri.parse(downloadUrl);
      final downloadLinks = await sl
          .get<NexusModsService>()
          .nexusBridge
          .apiClient
          .getDownloadLink(
            'starwarsbattlefront22017',
            int.parse(uri.pathSegments.last),
            int.parse(uri.queryParameters['file_id']!),
            null,
            null,
          );

      final downloadLink = Uri.parse(downloadLinks.first.uri);
      final filename = await resolveNexusFileName(
        modId: int.parse(uri.pathSegments.last),
        fileId: int.parse(uri.queryParameters['file_id']!),
        urlFallback: downloadLink.toString(),
      );
      return (downloadLink.toString(), filename);
    }

    final downloadCompleter = Completer<String>();
    late HeadlessInAppWebView webView;

    try {
      final fileId = Uri.parse(downloadUrl).queryParameters['file_id'];
      final body = 'fid=$fileId&game_id=2229';
      webView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            'https://www.nexusmods.com/Core/Libs/Common/Managers/Downloads?GenerateDownloadUrl',
          ),
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'x-requested-with': 'XMLHttpRequest',
          },
          body: Uint8List.fromList(body.codeUnits),
        ),
        onLoadStop: (controller, url) async {
          final currentDocumentContent = await controller.evaluateJavascript(
            source: 'document.body.innerText',
          );
          try {
            final decoded = currentDocumentContent != null
                ? jsonDecode(currentDocumentContent as String)
                : null;
            if (decoded != null && decoded['url'] != null) {
              final uri = decoded['url'] as String;
              if (!downloadCompleter.isCompleted) {
                return downloadCompleter.complete(uri);
              }
            }

            downloadCompleter.completeError(
              TimeoutException('Download URL not found in response'),
            );
          } catch (e) {
            downloadCompleter.completeError(
              TimeoutException('Download URL not found in response'),
            );
          }
        },
        initialSettings: InAppWebViewSettings(),
        webViewEnvironment: webViewEnvironment,
      );

      await webView.run();

      final uri = await downloadCompleter.future.timeout(
        const .new(seconds: 15),
      );

      final originalUri = Uri.parse(downloadUrl);
      final filename = await resolveNexusFileName(
        modId: int.parse(originalUri.pathSegments.last),
        fileId: int.parse(originalUri.queryParameters['file_id']!),
        urlFallback: uri,
      );

      return (uri, filename);
    } on TimeoutException catch (e, s) {
      NotificationService.error(
        message:
            'Failed to create download link. This is usually caused by being logged out of Nexus Mods.',
      );
      final x = await showKyberDialog<bool?>(
        context: navigatorKey.currentContext!,
        builder: (_) => const NexusmodsLogin(),
      );
      if (x != null && x) {
        return getNexusDownload(downloadUrl, tries: tries + 1);
      } else {
        throw Exception('Failed to find download button');
      }
    } catch (e, s) {
      Logger('download_service').severe('Failed to download mod', e, s);
      final htmlContent = await webView.webViewController?.evaluateJavascript(
        source: 'document.getElementById("section").innerHTML',
      );
      if (htmlContent != null) {
        await File(
          join(applicationDocumentsDirectory, 'error.html'),
        ).writeAsString(htmlContent as String);
      }
      rethrow;
    } finally {
      Logger.root.info('Disposing WebView');
      await webView.dispose();
    }
  }

  static Future<String> resolveNexusFileName({
    required int modId,
    required int fileId,
    required String urlFallback,
  }) async {
    final log = Logger('download_service');

    try {
      final apiClient = sl.get<NexusModsService>().nexusBridge.apiClient;
      final modFiles = await apiClient.getModFiles(
        'starwarsbattlefront22017',
        modId,
      );

      final file = modFiles.files.firstWhere((f) => f.fileId == fileId);
      if (file.fileName.isNotEmpty) {
        return file.fileName;
      }
    } catch (e, s) {
      log.warning(
        'Could not resolve filename from Nexus API for file $fileId, '
        'falling back to the download URL',
        e,
        s,
      );
    }

    try {
      final resp = await Dio().head<void>(urlFallback);
      final disposition = resp.headers.value('content-disposition');

      if (disposition != null) {
        final match = RegExp('filename="?([^";]+)"?').firstMatch(disposition);
        final filename = match?.group(1)?.trim();

        if (filename != null) {
          return _ensureArchiveExtension(filename);
        }
      }
    } catch (_) {
      // ignore and fall back to URL-based naming
    }

    final cleanUrl = urlFallback.split('?').first.split('/').last;
    final fromUrl = cleanUrl.replaceAll('%', '_');

    return _ensureArchiveExtension(fromUrl);
  }

  static String _ensureArchiveExtension(String name) {
    const archiveExtensions = ['.zip', '.rar', '.7z'];
    final lower = name.toLowerCase();

    if (archiveExtensions.any(lower.endsWith)) {
      return name;
    }
    return '$name.zip';
  }
}
