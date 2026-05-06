import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:grpc/grpc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/settings/dialogs/update_dialog.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/buttons/normal_button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/utils/hive_listener.dart';

class ExitDevPlaytestButton extends StatelessWidget {
  const ExitDevPlaytestButton({super.key});

  @override
  Widget build(BuildContext context) {
    return HiveListener(
      box: box,
      keys: const ['apiEnv'],
      builder: (_) {
        final env = Preferences.admin.apiEnv;
        if (env != kDevPlaytestEnv) {
          return const SizedBox.shrink();
        }

        return _ExitButton(currentEnv: env);
      },
    );
  }
}

class _ExitButton extends StatefulWidget {
  const _ExitButton({required this.currentEnv});

  final String currentEnv;

  @override
  State<_ExitButton> createState() => _ExitButtonState();
}

class _ExitButtonState extends State<_ExitButton> {
  bool _busy = false;

  Future<void> _exit() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final service = KyberGRPCService.fromEnv(kProdEnv);
      final token = await getAuthToken();
      await service.login(token);

      Preferences.admin.apiEnv = kProdEnv;
      final config = await service.launcherClient.getLauncherConfig(.new());
      for (final target in config.defaultChannels.entries) {
        await box.put('${target.key}_release_channel', target.value);
      }

      final updateAvailable = await ModuleVersionService().updateAvailable(
        module: .installer,
      );
      if (!updateAvailable) {
        NotificationService.warning(
          message: 'Please restart the Launcher to apply the changes.',
        );
      } else {
        NotificationService.info(
          message:
              'Switched back to production. '
              'Downloading latest version of the Launcher...',
        );
        await showKyberDialog(
          context: navigatorKey.currentContext!,
          builder: (context) => const UpdateDialog(forceInstall: true),
        );
      }
    } on GrpcError catch (e) {
      NotificationService.error(
        message: 'Failed to switch back to production: ${e.message ?? e.code}',
      );
    } catch (e) {
      NotificationService.error(
        message: 'Failed to switch back to production: $e',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = switch (_busy) {
      true => const SizedBox(
        width: 20,
        height: 20,
        child: ProgressRing(),
      ),
      _ => const Icon(
        mt.Icons.exit_to_app,
        size: 20,
      ),
    };

    return KOutlinedButton(
      onPressed: () => _busy ? null : _exit(),
      child: Row(
        spacing: 10,
        children: [
          icon,
          const Text(
            'Leave DevPlaytest',
          ),
        ],
      ),
    );
  }
}
