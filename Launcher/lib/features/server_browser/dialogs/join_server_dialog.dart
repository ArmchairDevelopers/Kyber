import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/kyber/services/map_helper.dart';
  import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_icon.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/buttons/normal_button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/dropdown/kyber_dropdown.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tab_bar.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:logging/logging.dart';

class CosmeticModsDialog extends StatefulWidget {
  const CosmeticModsDialog({required this.server, this.skipPasswordCheck = false, super.key});

  final ServerEntry server;
  final bool skipPasswordCheck;

  @override
  State<CosmeticModsDialog> createState() => _CosmeticModsDialogState();
}

class _CosmeticModsDialogState extends State<CosmeticModsDialog> {
  late bool correctPassword;

  String password = '';
  bool withoutMods = true;
  bool spectator = false;
  bool showInstanceSelector = false;

  late Server serverInfo;

  List<ModCollectionMetaData> collections = [];
  ModCollectionMetaData? selectedCollection;

  @override
  void initState() {
    serverInfo = widget.server.serverInfo;
    correctPassword = widget.skipPasswordCheck || !serverInfo.requiresPassword;
    withoutMods = !Preferences.general.useCosmetics;
    final mods = serverInfo.mods.map((e) => CollectionMod(name: e.name, version: e.version, link: e.link)).toList();
    for (final collection in collectionBox.values) {
      final gameplayMods = collection
          .getLocalMods(
        onlyGameplay: true,
        expandCollections: true,
        expandGameplayCollections: false,
      )
          .whereType<FrostyMod>()
          .map((e) => e.toCollectionMod())
          .toList();

      if (const ListEquality<CollectionMod>().equals(gameplayMods, mods) || collection.isCosmetic || gameplayMods.isEmpty) {
        collections.add(collection);
      }
    }

    if (Preferences.general.selectedCosmeticCollection != null) {
      final selectedCollectionId = Preferences.general.selectedCosmeticCollection;
      if (collectionBox.containsKey(selectedCollectionId) && collections.any((x) => x.localId == selectedCollectionId)) {
        selectedCollection = collectionBox.get(selectedCollectionId);
      }
    }

    selectedCollection ??= collections.firstOrNull;

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> checkPassword() async {
    try {
      final service = sl.get<KyberGRPCService>();
      final result = await service.serverBrowserClient.canJoinServer(CanJoinServerRequest(
        id: serverInfo.id,
        password: password,
      ));

      if (result.canJoin) {
        return setState(() {
          correctPassword = true;
        });
      }

      NotificationService.showNotification(
        message: 'Invalid password',
        severity: InfoBarSeverity.error,
      );
    } catch (e, s) {
      if (e is GrpcError && e.code == StatusCode.notFound) {
        Navigator.pop(context);
        NotificationService.showNotification(
          message: 'Server not found',
          severity: InfoBarSeverity.error,
        );
      } else {
        Logger.root.severe('An error occurred', e, s);
        NotificationService.showNotification(
          message: 'An error occurred',
          severity: InfoBarSeverity.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('Start Game'.toUpperCase()),
      constraints: const BoxConstraints(
        maxHeight: 500,
        maxWidth: 700,
      ),
      content: SizedBox(
        width: 450,
        child: Builder(
          builder: (context) {
            if (!correctPassword) {
              return Column(
                children: [
                  const Text(
                    'This server requires a password to join.',
                    style: TextStyle(
                      color: kWhiteColor,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Align(child: Text('Enter Password'.toUpperCase())),
                  const SizedBox(
                    height: 2.5,
                  ),
                  KyberInput(
                    onFieldSubmitted: (value) => checkPassword(),
                    placeholder: 'Password',
                    isSensitive: true,
                    onChanged: (value) {
                      setState(() {
                        password = value;
                      });
                    },
                  ),
                ],
              );
            }

            return Column(
              children: [
                if (widget.server case GroupedServer(:final group)) ...[
                  RichText(
                    text: TextSpan(
                      text: 'JOINING INSTANCE ',
                      style: const TextStyle(
                        fontSize: 16,
                        color: kWhiteColor,
                        fontFamily: FontFamily.battlefrontUI,
                      ),
                      children: [
                        TextSpan(
                          text: '#${group.getInstanceId(serverInfo.id)}',
                          style: TextStyle(
                            color: kActiveColor,
                          ),
                        ),
                        const TextSpan(
                          text: ' | ',
                          style: TextStyle(
                            color: decoColor,
                          ),
                        ),
                        TextSpan(
                          text: '(${serverInfo.playerCount}/${serverInfo.maxPlayerCount})',
                        ),
                      ],
                    ),
                  ),
                  if (!showInstanceSelector) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ButtonBuilder(
                        onClick: () => setState(() => showInstanceSelector = true),
                        builder: (context, hovered) {
                          return Text(
                            'CHANGE INSTANCE',
                            style: TextStyle(
                              color: hovered ? kActiveColor : kWhiteColor,
                              fontFamily: FontFamily.battlefrontUI,
                              decoration: TextDecoration.underline,
                            ),
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: KyberDropdown<Server>(
                        onChanged: (value) {
                          setState(() => serverInfo = value);
                        },
                        itemBuilder: (DropdownItem<dynamic> item) {
                          item as DropdownItem<Server>;
                          final instanceId = group.getInstanceId(item.value.id);
                          final serverInfo = item.value;
                          return Row(
                            children: [
                              SizedBox(
                                width: 70,
                                height: 45,
                                child: Builder(builder: (context) {
                                  if (serverInfo.mapImageHash.isNotEmpty) {
                                    return CachedNetworkImage(
                                      imageUrl: 'https://${sl.get<KyberGRPCService>().httpHostname}/images/${serverInfo.mapImageHash}.jpeg',
                                      fit: BoxFit.cover,
                                      alignment: Alignment.centerLeft,
                                      colorBlendMode: BlendMode.darken,
                                      color: Colors.black.withOpacity(.12),
                                    );
                                  }

                                  return MapHelper.getImageForMap(serverInfo.levelSetup.map)!.image(
                                    fit: BoxFit.cover,
                                    alignment: Alignment.centerLeft,
                                    colorBlendMode: BlendMode.darken,
                                    color: Colors.black.withOpacity(.12),
                                  );
                                }),
                              ),
                              Container(width: 2, height: 45, color: decoColor),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10).copyWith(top: 5),
                                      child: Text(
                                        'INSTANCE #$instanceId',
                                        style: const TextStyle(
                                          fontFamily: FontFamily.battlefrontUI,
                                          fontSize: 16,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Row(
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: kWhiteColor1,
                                                fontFamily: FontFamily.battlefrontUI,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: serverInfo.levelSetup.modeName.isNotEmpty
                                                      ? serverInfo.levelSetup.modeName
                                                      : MapHelper.getMode(serverInfo.levelSetup.mode)?.name ?? 'UNKNOWN MODE',
                                                ),
                                                const TextSpan(
                                                  text: ' | ',
                                                  style: TextStyle(
                                                    color: decoColor,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: serverInfo.levelSetup.mapName.isNotEmpty
                                                      ? serverInfo.levelSetup.mapName
                                                      : MapHelper.getMap(serverInfo.levelSetup.mode, serverInfo.levelSetup.map)?.name ?? 'UNKNOWN MAP',
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  '${item.value.playerCount}/${item.value.maxPlayerCount}',
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                        items: group.getSorted().map((e) {
                          return DropdownItem(value: e, label: 'INSTANCE #${group.getInstanceId(e.id)}');
                        }).toList(),
                        selectedItem: serverInfo,
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                ],
                const Text('PLAY WITH OR WITHOUT COSMETIC MODS'),
                const Text(
                  'Select an option to load the game with or without cosmetic mods.',
                  style: TextStyle(
                    color: kWhiteColor,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                SizedBox(
                  height: 35,
                  child: KyberTabBar(
                    tabs: const [
                      Text('WITH COSMETICS'),
                      Text('WITHOUT COSMETICS'),
                    ],
                    selectedIndex: withoutMods ? 1 : 0,
                    onChanged: (index) {
                      Preferences.general.useCosmetics = index == 0;
                      setState(() {
                        withoutMods = index == 1;
                      });
                    },
                  ),
                ),
                if (!withoutMods) ...[
                  const SizedBox(
                    height: 30,
                  ),
                  KyberDropdown<ModCollectionMetaData>(
                    onChanged: (value) {
                      setState(() => selectedCollection = value);
                      Preferences.general.selectedCosmeticCollection = value.localId;
                    },
                    itemBuilder: (DropdownItem<dynamic> item) {
                      item as DropdownItem<ModCollectionMetaData>;
                      return Row(
                        children: [
                          SizedBox(height: 40, width: 40, child: CollectionIcon(collection: item.value)),
                          Container(width: 2, height: 40, color: decoColor),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                item.value.title,
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    items: collections.map((e) => DropdownItem(value: e, label: e.title)).toList(),
                    selectedItem: selectedCollection,
                    placeholder: 'SELECT A COLLECTION',
                  ),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        KyberButton(
          text: 'Cancel',
          onPressed: Navigator.of(context).pop,
        ),
        if (!correctPassword)
          KyberButton(
            text: 'Next',
            onPressed: checkPassword,
          ),
        if (correctPassword)
          NormalButton(
            onPressed: () => setState(() => spectator = !spectator),
            iconData: spectator ? mt.Icons.check_circle : mt.Icons.circle_outlined,
            label: const Row(
              children: [
                Icon(mt.Icons.remove_red_eye_outlined),
                SizedBox(width: 6),
                Text('SPECTATE'),
              ],
            ),
          ),
        if (correctPassword)
          KyberButton(
            text: 'Join Server',
            icon: Assets.icons.kyberLogo.svg(height: 20),
            onPressed: () async {
              if (!serverInfo.requiresPassword) {
                try {
                  final result = await sl.get<KyberGRPCService>().serverBrowserClient.canJoinServer(
                    CanJoinServerRequest(
                      id: serverInfo.id,
                      password: password,
                    ),
                  );

                  if (!result.canJoin) {
                    NotificationService.showNotification(
                      message: result.reason,
                      severity: InfoBarSeverity.error,
                    );
                    return;
                  }
                } catch (e, s) {
                  if (e is GrpcError && e.code == StatusCode.permissionDenied) {
                    Logger.root.severe('An error occurred', e, s);
                    Navigator.pop(context);
                    NotificationService.showNotification(
                      message: e.message ?? 'You are banned from this server',
                      severity: InfoBarSeverity.error,
                    );
                  } else {
                    Logger.root.severe('An error occurred', e, s);
                    NotificationService.showNotification(
                      message: e is GrpcError ? e.message ?? e.code.toString() : 'An error occurred',
                      severity: InfoBarSeverity.error,
                    );
                  }
                  return;
                }
              }

              final result = JoinDialogResult(
                collection: withoutMods ? ModCollectionMetaData.noMods() : selectedCollection ?? ModCollectionMetaData.noMods(),
                spectator: spectator,
                password: password,
                instanceId: widget.server is GroupedServer ? serverInfo.meta['instance_id'] : null,
              );

              Navigator.of(context).pop(result);
            },
          ),
      ],
    );
  }
}

class JoinDialogResult {
  JoinDialogResult({required this.collection, required this.spectator, this.password = '', this.instanceId});

  final ModCollectionMetaData collection;
  final bool spectator;
  final String password;

  /// Only useful for server groups
  final String? instanceId;
}