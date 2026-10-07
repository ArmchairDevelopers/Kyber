import 'package:fluent_ui/fluent_ui.dart';
import 'package:grpc/grpc.dart' hide Server;
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/features/server_browser/dialogs/server_ban_dialog.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:logging/logging.dart';

class ServerPasswordDialog extends StatefulWidget {
  const ServerPasswordDialog({required this.serverInfo, super.key});

  final Server serverInfo;

  static Future<String?> show(
    BuildContext context, {
    required Server serverInfo,
  }) {
    return showKyberDialog<String?>(
      context: context,
      builder: (context) => ServerPasswordDialog(serverInfo: serverInfo),
    );
  }

  @override
  State<ServerPasswordDialog> createState() => _ServerPasswordDialogState();
}

class _ServerPasswordDialogState extends State<ServerPasswordDialog> {
  String password = '';
  bool checking = false;

  Future<void> checkPassword() async {
    if (checking) {
      return;
    }

    setState(() => checking = true);

    try {
      final service = sl.get<KyberGRPCService>();
      final result = await service.serverBrowserClient.canJoinServer(
        .new(
          id: widget.serverInfo.id,
          password: password,
        ),
      );

      if (!mounted) {
        return;
      }

      if (result.deniedReason == .BANNED) {
        await ServerBanDialog.show(context, banInfo: result.banInfo);
        if (!mounted) {
          return;
        }

        Navigator.of(context).pop();
        return;
      }

      if (result.canJoin || result.deniedReason == .SERVER_FULL) {
        Navigator.of(context).pop(password);
        return;
      }

      NotificationService.error(message: 'Invalid password');
    } catch (e, s) {
      if (!mounted) return;

      if (e is GrpcError && e.code == StatusCode.notFound) {
        Navigator.of(context).pop();
        NotificationService.error(message: 'Server not found');
      } else {
        Logger.root.severe('An error occurred', e, s);
        NotificationService.error(message: 'An error occurred');
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: Text('Server Password'.toUpperCase()),
      constraints: const .new(
        maxWidth: 600,
        maxHeight: 400,
      ),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: .min,
          children: [
            const Text(
              'This server requires a password to join.',
              style: TextStyle(
                color: kWhiteColor,
              ),
            ),
            const SizedBox(height: 10),
            Align(child: Text('Enter Password'.toUpperCase())),
            const SizedBox(height: 2.5),
            KyberInput(
              onFieldSubmitted: (value) => checkPassword(),
              placeholder: 'Password',
              isSensitive: true,
              autofocus: true,
              disabled: checking,
              onChanged: (value) => password = value,
            ),
          ],
        ),
      ),
      actions: [
        KyberButton(
          text: 'Cancel',
          onPressed: Navigator.of(context).pop,
        ),
        KyberButton(
          text: 'Join Server',
          onPressed: checking ? null : checkPassword,
        ),
      ],
    );
  }
}
