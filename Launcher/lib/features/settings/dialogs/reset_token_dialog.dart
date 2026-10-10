import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';

class ResetTokenDialog extends StatefulWidget {
  const ResetTokenDialog({super.key});

  @override
  State<ResetTokenDialog> createState() => _ResetTokenDialogState();
}

class _ResetTokenDialogState extends State<ResetTokenDialog> {
  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: const Text('Reset Kyber Auth Token'),
      content: const Text(
        'Are you sure you want to reset your authentication token?\n\nThis will log you out of all devices.\n\nIf you are hosting dedicated servers you will need to update the token for them as well.',
        textAlign: .center,
      ),
      constraints: const .new(
        maxWidth: 600,
        maxHeight: 400,
      ),
      actions: [
        KyberButton(
          text: 'Cancel',
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        KyberButton(
          text: 'Confirm',
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}
