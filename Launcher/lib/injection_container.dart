import 'package:get_it/get_it.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/rich_presence.dart';
import 'package:kyber_launcher/core/services/vivox_sdk_service.dart';
import 'package:kyber_launcher/core/services/voip_service.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/features/download_manager/services/mod_bridge_service.dart';
import 'package:kyber_launcher/features/kyber/services/kyber_grpc_service.dart';
import 'package:kyber_launcher/features/map_rotation/services/custom_rotation_service.dart';
import 'package:kyber_launcher/features/maxima/services/maxima_instance_service.dart';
import 'package:kyber_launcher/features/mods/services/level_declaration_service.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/features/plugin_manager/services/plugin_manager.dart';
import 'package:kyber_launcher/features/server_browser/services/lan_discovery_service.dart';

final GetIt sl = GetIt.instance;

void initializeDependencies() {
  sl
    ..registerSingleton<KyberGRPCService>(
      KyberGRPCService.fromEnv(Preferences.admin.apiEnv),
    )
    ..registerSingleton<RichPresence>(RichPresence())
    ..registerSingleton<MaximaInstanceService>(MaximaInstanceService())
    ..registerSingleton<KyberGRPCServer>(KyberGRPCServer())
    ..registerSingleton<ModBridgeGRPCService>(
      ModBridgeGRPCService.fromEnv(Preferences.admin.apiEnv),
    )
    ..registerSingleton<VoipService>(VoipService().getInstance())
    ..registerSingleton<PluginManager>(PluginManager())
    ..registerSingleton<LevelDeclarationService>(LevelDeclarationService())
    ..registerSingleton<LanDiscoveryService>(LanDiscoveryService())
    ..registerSingletonAsync<ModService>(ModService.getInstance)
    ..registerSingletonAsync<DownloadOrchestrator>(
      DownloadOrchestrator.getInstance,
    )
    ..registerSingletonAsync<KyberMapService>(KyberMapService().getInstance)
    ..registerSingletonAsync<VivoxService>(VivoxService().getInstance)
    ..registerSingletonAsync<NexusModsService>(NexusModsService().getInstance);
}
