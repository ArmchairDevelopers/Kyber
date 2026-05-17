import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber/gen/Proto/kyber_common.pb.dart';
import 'package:kyber/kyber.dart' hide ServerMod;
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/image_helper.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/windows_env.dart';
import 'package:kyber_launcher/features/map_rotation/models/map_rotation_entry.dart';
import 'package:kyber_launcher/features/map_rotation/providers/map_rotation_cubit.dart';
import 'package:kyber_launcher/features/maxima/helper/maxima_helper.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/mods/services/level_declaration_service.dart';
import 'package:kyber_launcher/features/server_browser/services/lan_discovery_service.dart';
import 'package:kyber_launcher/features/server_host/providers/host_collection_cubit.dart';
import 'package:kyber_launcher/features/server_host/widgets/settings_box/server_settings_box.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';
import 'package:logging/logging.dart';

class SettingsBoxHeader extends StatelessWidget {
  const SettingsBoxHeader({
    required this.onPageChanged,
    required this.selectedPage,
    super.key,
  });

  final void Function(int page) onPageChanged;
  final int selectedPage;

  Future<void> uploadHashes(BuildContext context) async {
    final currentCollection = context
        .read<HostCollectionCubit>()
        .state
        .selectedModCollection;
    final imageHashes = <MapRotationEntry, String>{};
    for (final entry in context.read<MapRotationCubit>().state.maps.where(
      (e) => e.isCustom,
    )) {
      final imageData = sl.get<LevelDeclarationService>().getMapImage(
        currentCollection,
        entry.map,
      );
      if (imageData == null || imageData.isEmpty) {
        continue;
      }

      final hex = ImageHelper.generateHash(imageData);
      imageHashes[entry] = hex;
    }

    if (imageHashes.isEmpty) {
      return;
    }

    final create = <ModImage>[];
    final result = await sl
        .get<KyberGRPCService>()
        .serverBrowserClient
        .checkModImages(
          CheckModImagesRequest(
            items: imageHashes.entries
                .map(
                  (e) => CheckModImageItem(
                    hash: e.value,
                    level: e.key.map,
                    mode: e.key.mode,
                  ),
                )
                .toList(),
          ),
        );
    final missingHashes = imageHashes.values
        .where((hash) => !result.hashes.contains(hash))
        .toList();

    for (final hash in missingHashes) {
      final entry = imageHashes.entries.firstWhere((e) => e.value == hash).key;
      imageHashes.remove(entry);
      final imageData = sl.get<LevelDeclarationService>().getMapImage(
        currentCollection,
        entry.map,
      );
      final mod = sl.get<LevelDeclarationService>().getModByMap(
        map: entry.map,
        collection: currentCollection,
      );

      create.add(
        ModImage(
          image: imageData,
          level: entry.map,
          mode: entry.mode,
          mod: ServerMod(
            name: mod.details.name,
            version: mod.details.version,
            fileSize: Int64(0),
            link: "",
          ),
        ),
      );
    }

    if (missingHashes.isNotEmpty) {
      final stopWatch = Stopwatch()..start();
      await showKyberDialog(
        context: context,
        builder: (context) {
          sl
              .get<KyberGRPCService>()
              .serverBrowserClient
              .uploadModImages(
                UploadModImagesRequest(images: create),
              )
              .then((_) => Navigator.of(context).pop());

          return KyberContentDialog(
            title: Text('MAP IMAGES'.toUpperCase()),
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 300),
            content: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 15,
                      width: 15,
                      child: ProgressRing(),
                    ),
                    SizedBox(
                      width: 15,
                    ),
                    Text(
                      'Uploading map images...',
                      style: TextStyle(
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  'Please wait while ${missingHashes.length} map images are uploaded. This may take a few seconds.',
                  style: FluentTheme.of(context).typography.body?.copyWith(
                    color: kWhiteColor,
                  ),
                ),
              ],
            ),
          );
        },
      );

      stopWatch.stop();

      Logger.root.info(
        'Uploaded ${missingHashes.length} map images in ${stopWatch.elapsedMilliseconds}ms',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10).copyWith(left: 10, top: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlocBuilder<ModerationCubit, ModerationServerState>(
            builder: (context, state) {
              return FractionallySizedBox(
                widthFactor: 0.8,
                child: KyberFormInputField(
                  name: 'serverName',
                  initialValue: state.selected ? state.server?.name : null,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.minLength(3),
                    FormBuilderValidators.maxLength(25),
                  ]),
                  placeholder: 'Server Name',
                ),
              );
            },
          ),
          FutureBuilder<String>(
            future: LanDiscoveryService.getLanAddress(),
            builder: (context, snapshot) {
              final address = snapshot.data ?? 'detecting LAN IP';
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'LAN address: $address:${LanDiscoveryService.gamePort}',
                  style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: kWhiteColor,
                  ),
                ),
              );
            },
          ),
          const SizedBox(
            height: 10,
          ),

          //FractionallySizedBox(
          //  widthFactor: 0.8,
          //  child: KyberFormInputField(
          //    name: "tags",
          //    placeholder: Localization.current.hostServerTagsPlaceholder,
          //  ),
          //),
          const SizedBox(
            height: 30,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BlocBuilder<ModerationCubit, ModerationServerState>(
                builder: (context, state) {
                  return Row(
                    children: [
                      KyberButton(
                        text: state.selected ? 'UPDATE SERVER' : 'START SERVER',
                        onPressed: () async {
                          final form = hostingForm.currentState!;
                          if (!form.saveAndValidate()) {
                            final firstKey = form.errors.entries.first;
                            NotificationService.showNotification(
                              title: firstKey.key,
                              message: firstKey.value,
                              severity: InfoBarSeverity.error,
                            );
                            return;
                          }

                          if (state.selected) {
                            if (state.isLocalLanHost) {
                              NotificationService.showNotification(
                                message:
                                    'LAN servers are edited locally while '
                                    'hosting. Restart the server to change '
                                    'LAN metadata.',
                                severity: InfoBarSeverity.warning,
                              );
                              return;
                            }

                            if (form.value['lanMode'] as bool? ?? false) {
                              NotificationService.showNotification(
                                message:
                                    'LAN servers are edited locally while '
                                    'hosting. Restart the server to change '
                                    'LAN metadata.',
                                severity: InfoBarSeverity.warning,
                              );
                              return;
                            }
                            await sl
                                .get<KyberGRPCService>()
                                .serverBrowserClient
                                .updateServer(
                                  UpdateServerRequest(
                                    id: state.id,
                                    name: form.value['serverName'] as String,
                                    description:
                                        form.value['description'] as String?,
                                    password: form.value['password'] as String?,
                                  ),
                                );
                            NotificationService.showNotification(
                              message: 'Server updated',
                            );
                            return;
                          }

                          final lanMode =
                              form.value['lanMode'] as bool? ?? false;
                          final serverPort =
                              int.tryParse(
                                (form.value['serverPort'] ?? '').toString(),
                              ) ??
                              LanDiscoveryService.gamePort;

                          if (!lanMode) {
                            await uploadHashes(context);
                          }

                          final mapRotation = context
                              .read<MapRotationCubit>()
                              .state
                              .maps
                              .map(
                                (e) {
                                  return LevelSetup(
                                    map: e.map,
                                    mode: e.mode,
                                    mapName: sl
                                        .get<LevelDeclarationService>()
                                        .getMapByMode(
                                          map: e.map,
                                          mode: e.mode,
                                          collection: context
                                              .read<HostCollectionCubit>()
                                              .state
                                              .selectedModCollection,
                                        )
                                        ?.name,
                                    modeName: sl
                                        .get<LevelDeclarationService>()
                                        .getModeName(
                                          mode: e.mode,
                                          collection: context
                                              .read<HostCollectionCubit>()
                                              .state
                                              .selectedModCollection,
                                        ),
                                  );
                                },
                              )
                              .toList();
                          final collection = context
                              .read<HostCollectionCubit>()
                              .state
                              .selectedModCollection;

                          if (mapRotation.isEmpty) {
                            NotificationService.error(
                              message:
                                  'You need to add at least one map to the map rotation',
                            );
                            return;
                          }

                          try {
                            final startRequest = StartServerRequest(
                              name: form.value['serverName'] as String,
                              description: form.value['description'] as String?,
                              password: form.value['password'] as String?,
                              maxPlayers: form.value['maxPlayers'] as int?,
                              mapRotation: mapRotation,
                            );

                            ProcessEnv.set(
                              'KYBER_ONLINE_MODE',
                              lanMode ? '0' : '1',
                            );
                            ProcessEnv.set(
                              'KYBER_SERVER_PORT',
                              lanMode
                                  ? serverPort.toString()
                                  : LanDiscoveryService.gamePort.toString(),
                            );

                            if (!lanMode) {
                              await sl
                                  .get<KyberGRPCService>()
                                  .serverBrowserClient
                                  .validateServer(
                                    RegisterServerRequest(
                                      name: startRequest.name,
                                      description: startRequest.description,
                                      password: startRequest.password,
                                      maxPlayerCount: startRequest.maxPlayers,
                                      explodedMods: [],
                                      mods: [],
                                      levelSetup: LevelSetup(map: '', mode: ''),
                                      statsSource: .KYBER,
                                    ),
                                  );
                            }

                            final initialCommands = <String>[];

                            if (form.value['friendlyFire'] as bool? ?? false) {
                              initialCommands.add(
                                'SyncedGame.EnableFriendlyFire 1',
                              );
                            }

                            final healthRegen =
                                form.value['healthRegeneration'] as bool? ??
                                true;
                            if (!healthRegen) {
                              initialCommands.add(
                                'SyncedGame.DisableRegenerateHealth 1',
                              );
                            }

                            if (sl.isRegistered<MaximaGameInstance>()) {
                              if (initialCommands.isNotEmpty) {
                                NotificationService.showNotification(
                                  message:
                                      'Friendly Fire and Health Regeneration can only be set when no game is running',
                                  severity: InfoBarSeverity.error,
                                );
                              }

                              final client = sl
                                  .get<MaximaGameInstance>()
                                  .clientService;
                              final state = await client.commonClient.getInfo(
                                Empty(),
                              );
                              if (state.hasClient() || state.hasServer()) {
                                Logger.root.info(
                                  'Client or server is already running',
                                );
                                return;
                              }

                              await client.serverClient.startServer(
                                startRequest,
                                options: lanMode
                                    ? CallOptions(
                                        metadata: {'kyber-lan-mode': '1'},
                                      )
                                    : null,
                              );
                            } else {
                              await MaximaHelper.requestGameLaunch(
                                context,
                                initializeRequest: InitializeRequest(
                                  startServer: startRequest,
                                  startupCommands: initialCommands,
                                ),
                                modCollection: collection,
                              );
                            }

                            if (lanMode) {
                              await sl.get<LanDiscoveryService>().startBeacon(
                                name: startRequest.name,
                                port: serverPort,
                                maxPlayers: startRequest.maxPlayers,
                                requiresPassword:
                                    startRequest.password.isNotEmpty,
                                mapRotation: mapRotation,
                                collection: collection,
                              );
                              final lanAddress =
                                  await LanDiscoveryService.getLanAddress();
                              NotificationService.showNotification(
                                message:
                                    'LAN server available at $lanAddress:$serverPort. Allow UDP $serverPort and ${LanDiscoveryService.discoveryPort} in your firewall.',
                              );
                            } else {
                              await sl.get<LanDiscoveryService>().stopBeacon();
                            }
                          } on GrpcError catch (e) {
                            Logger.root.severe(
                              'Failed to start server: ${e.message}',
                            );
                            NotificationService.error(
                              message: 'Failed to start server: ${e.message}',
                            );
                          } catch (e, stack) {
                            Logger.root.severe(
                              'Unexpected error while starting server',
                              e,
                              stack,
                            );
                            NotificationService.error(
                              message:
                                  'An unexpected error occurred while starting the server',
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              SizedBox(
                height: 35,
                width: 220,
                child: KyberTabBar(
                  tabs: [
                    Text('Settings'.toUpperCase()),
                    Text('Info'.toUpperCase()),
                  ],
                  onChanged: onPageChanged,
                  selectedIndex: selectedPage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
