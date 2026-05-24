import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/features/frosty/dialogs/frosty_pack_selector_dialog.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_server_helper.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/join_server_dialog.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class DirectConnectDialog extends StatefulWidget {
  const DirectConnectDialog({super.key, this.initialIp, this.initialPort});

  final String? initialIp;
  final int? initialPort;

  @override
  State<DirectConnectDialog> createState() => _DirectConnectDialogState();
}

class _DirectConnectDialogState extends State<DirectConnectDialog> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  ModCollectionMetaData? _collection;
  bool _spectator = false;

  @override
  void initState() {
    super.initState();
    final savedIp = Preferences.general.lastDirectConnectIp;
    final savedPort = Preferences.general.lastDirectConnectPort;
    final savedCollectionId = Preferences.general.lastDirectConnectCollectionId;

    _ipController = TextEditingController(
      text: widget.initialIp ?? savedIp ?? '',
    );
    _portController = TextEditingController(
      text: (widget.initialPort ?? savedPort ?? KyberServerHelper.defaultLanPort)
          .toString(),
    );

    if (savedCollectionId != null && collectionBox.containsKey(savedCollectionId)) {
      _collection = collectionBox.get(savedCollectionId);
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _selectCollection() async {
    final collection = await showKyberDialog<ModCollectionMetaData?>(
      context: context,
      builder: (_) => const FrostyPackSelectorDialog(),
    );
    if (collection != null) {
      setState(() => _collection = collection);
    }
  }

  Future<void> _join() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (ip.isEmpty || port == null || port <= 0 || port > 65535) {
      return;
    }

    Preferences.general.lastDirectConnectIp = ip;
    Preferences.general.lastDirectConnectPort = port;
    Preferences.general.lastDirectConnectCollectionId = _collection?.localId;

    Navigator.of(context).pop();

    final result = await showKyberDialog<JoinDialogResult?>(
      context: navigatorKey.currentContext!,
      builder: (_) => CosmeticModsDialog.directConnect(),
    );

    if (result == null) {
      return;
    }

    await KyberServerHelper.joinByAddress(
      ip: ip,
      port: port,
      selectedCollection: _resolveJoinCollection(_collection, result),
      spectator: _spectator || result.spectator,
    );
  }

  ModCollectionMetaData _resolveJoinCollection(
    ModCollectionMetaData? base,
    JoinDialogResult result,
  ) {
    if (result.collection.localId == 'no-mods') {
      return base ?? ModCollectionMetaData.noMods();
    }

    if (base == null) {
      return result.collection;
    }

    return base.copyWith(
      mods: [...base.mods, ...result.collection.mods],
    );
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('Direct Connect'.toUpperCase()),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 420),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Join a LAN server by IP address. The game will be started in LAN mode and will not connect to Kyber proxies.',
          ),
          const SizedBox(height: 16),
          TextBox(
            controller: _ipController,
            placeholder: 'Server IP',
          ),
          const SizedBox(height: 10),
          TextBox(
            controller: _portController,
            placeholder: KyberServerHelper.defaultLanPort.toString(),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          Checkbox(
            checked: _spectator,
            content: const Text('Join as spectator'),
            onChanged: (value) => setState(() => _spectator = value ?? false),
          ),
          const SizedBox(height: 16),
          KyberButton(
            text: _collection == null
                ? 'SELECT MOD COLLECTION'
                : 'MODS: ${_collection!.title.toUpperCase()}',
            onPressed: _selectCollection,
          ),
        ],
      ),
      actions: [
        KyberButton(
          text: 'CANCEL',
          onPressed: () => Navigator.of(context).pop(),
        ),
        KyberButton(
          text: 'JOIN',
          onPressed: _join,
        ),
      ],
    );
  }
}
