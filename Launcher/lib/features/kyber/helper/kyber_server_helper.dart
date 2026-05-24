import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart' hide ServerMod;
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/windows_env.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/maxima/dialogs/maxima_start_game_dialog.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mod_collections/providers/mod_collection_cubit.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/server_browser/models/lan_server.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';

class KyberServerHelper {
  static final _logger = Logger('kyber_server_helper');
  static const int defaultLanPort = 25200;

  static Future<void> joinServer(
    Server server, {
    ModCollectionMetaData? selectedCollection,
    bool? spectator,
    String? password,
  }) async {
    final localMods = sl.get<ModService>().mods;
    final mods = server.mods.map(
      (e) => localMods.firstWhere(
        (element) => element.toKyberString() == '${e.name} (${e.version})',
      ),
    );
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
      ProcessEnv.set('KYBER_ONLINE_MODE', '1');
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

  static Future<void> joinLanServer(
    LanServer server, {
    ModCollectionMetaData? selectedCollection,
    bool spectator = false,
  }) async {
    final localMods = sl.get<ModService>().mods;
    final collectionMods = <CollectionMod>[];

    for (final requiredMod in server.gameplayMods) {
      final mod = localMods.firstWhereOrNull(
        (element) =>
            element.details.name == requiredMod.name &&
            element.details.version == requiredMod.version,
      );
      if (mod == null) {
        throw Exception(
          'Required mod "${requiredMod.name}" (${requiredMod.version}) is not installed',
        );
      }

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
        if (selectedCollection == null) ...collectionMods,
      ],
      localId: server.id,
    );

    await joinByAddress(
      ip: server.address,
      port: server.port,
      selectedCollection: tmpCollection,
      spectator: spectator,
    );
  }

  static Future<void> joinByAddress({
    required String ip,
    int port = defaultLanPort,
    ModCollectionMetaData? selectedCollection,
    bool spectator = false,
  }) async {
    try {
      ProcessEnv.set('KYBER_ONLINE_MODE', '0');

      var serverIp = ip.trim();
      final currentIp = await _getCurrentIpAddressOrNull();
      if (currentIp != null && serverIp == currentIp) {
        serverIp = '127.0.0.1';
      }

      final joinRequest = JoinServerRequest(
        ip: serverIp,
        port: port,
        type: .DIRECT,
        spectate: spectator,
      );
      final initializeRequest = InitializeRequest(joinServer: joinRequest);
      if (selectedCollection != null) {
        initializeRequest.modData = selectedCollection.getInterfaceData();
      }

      if (!sl.isRegistered<MaximaGameInstance>()) {
        await showKyberDialog(
          context: navigatorKey.currentContext!,
          builder: (_) => MaximaStartGameDialog(
            mods: selectedCollection
                ?.getLocalMods()
                .whereType<FrostyMod>()
                .toList(),
            initializeRequest: initializeRequest,
          ),
        );
      } else {
        final instance = sl.get<MaximaGameInstance>();
        await instance.clientService.client.joinServer(
          joinRequest,
          options: CallOptions(metadata: {'kyber-lan-mode': '1'}),
        );
      }
    } on GrpcError catch (e) {
      _logger.severe('Failed to join LAN server: ${e.message}', e);
      NotificationService.error(
        message: 'Failed to join LAN server: ${e.message}',
      );
    } catch (e) {
      _logger.severe('Failed to join LAN server: $e', e);
      NotificationService.error(
        message: 'Failed to join LAN server: $e',
      );
    }
  }

  static Future<String?> _getCurrentIpAddressOrNull() async {
    try {
      return await KyberNetworkHelper.getCurrentIpAddress();
    } catch (_) {
      return null;
    }
  }
}
