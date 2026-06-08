import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart' hide ServerMod;
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_start_game_dialog.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';

class KyberServerHelper {
  static final _logger = Logger('kyber_server_helper');

  static Future<void> joinServer(
    Server server, {
    ModCollectionMetaData? selectedCollection,
    bool? spectator,
    String? password,
  }) async {
    final localMods = sl.get<ModService>().mods;
    final mods = server.mods.map((e) {
      final matches = localMods
          .where(
            (element) => element.toKyberString() == '${e.name} (${e.version})',
          )
          .toList();

      return matches.firstWhereOrNull(
            (m) => !m.isCollection || !m.isCorrupted(),
          ) ??
          matches.first;
    });
    final collectionMods = <CollectionMod>[];
    for (final mod in mods) {
      if (mod.isCollection) {
        final cMods = mod.getMods()!.map(
          (e) => localMods
              .firstWhereOrNull((x) => x.filename == e)
              ?.toCollectionMod(),
        );
        if (cMods.contains(null)) {
          throw Exception(
            '"${mod.details.name}" is corrupted. Please reinstall it',
          );
        }

        collectionMods.addAll(cMods.whereType<CollectionMod>());
      } else {
        collectionMods.add(mod.toCollectionMod());
      }
    }

    final tmpCollection = ModCollectionMetaData(
      title: server.name,
      mods: [
        if (selectedCollection != null &&
            !selectedCollection.containsGameplayMods())
          ...collectionMods,
        if (selectedCollection != null) ...selectedCollection.mods,
      ],
      localId: server.id,
    );

    var serverIp = server.ip;
    final currentIp = await KyberNetworkHelper.getCurrentIpAddress();
    if (serverIp == currentIp) {
      serverIp = '127.0.0.1';
    }

    final proxies = navigatorKey.currentContext!
        .read<KyberProxyCubit>()
        .state
        .proxies;
    var selectedProxy = proxies.firstWhereOrNull(
      (p) => p.proxy.id == Preferences.general.proxy,
    );
    if (selectedProxy == null) {
      selectedProxy = proxies.firstOrNull;
      _logger.warning(
        'No proxy selected, using ${selectedProxy?.proxy.name} instead',
      );
      if (selectedProxy == null) {
        _logger.severe('No proxy available');
        throw Exception('No proxy available');
      }

      NotificationService.showNotification(
        message:
            'Selected Proxy not available, using ${selectedProxy.proxy.name} instead',
        severity: InfoBarSeverity.warning,
      );
    }

    _logger.info(
      'Joining server with proxy ${selectedProxy.proxy.name} (${selectedProxy.proxy.ip})',
    );

    try {
      final service = sl.get<KyberGRPCService>();
      final joinToken = await service.clientServerClient.createJoinToken(
        .new(
          server: server.id,
          password: password,
        ),
      );

      final joinRequest = JoinServerRequest(
        id: server.id,
        ip: server.requiresProxy ? selectedProxy.proxy.ip : serverIp,
        port: server.requiresProxy ? null : server.port,
        type: server.requiresProxy ? .PROXIED : .DIRECT,
        spectate: spectator ?? false,
        joinToken: joinToken.token,
      );

      if (!sl.isRegistered<MaximaGameInstance>()) {
        await showKyberDialog(
          context: navigatorKey.currentContext!,
          builder: (_) => MaximaStartGameDialog(
            mods: tmpCollection.getLocalMods().whereType<FrostyMod>().toList(),
            initializeRequest: InitializeRequest(
              joinServer: joinRequest,
              modData: tmpCollection.getInterfaceData(),
            ),
          ),
        );
      } else {
        final instance = sl.get<MaximaGameInstance>();
        await instance.clientService.client.joinServer(
          joinRequest,
        );
      }
    } on GrpcError catch (e) {
      _logger.severe('Failed to join server: ${e.message}', e);
      NotificationService.error(
        message: 'Failed to join server: ${e.message}',
      );
    } catch (e) {
      _logger.severe('Failed to join server: $e', e);
      NotificationService.error(
        message: 'Failed to join server: $e',
      );
    }
  }
}
