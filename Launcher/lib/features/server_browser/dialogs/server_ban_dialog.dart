import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;

class ServerBanDialog extends StatelessWidget {
  const ServerBanDialog({required this.banInfo, super.key});

  final BanInfo banInfo;

  static Future<void> show(BuildContext context, {required BanInfo banInfo}) {
    return showKyberDialog(
      context: context,
      builder: (context) => ServerBanDialog(banInfo: banInfo),
    );
  }

  @override
  Widget build(BuildContext context) {
    var expires = 'Never';
    if (banInfo.hasExpiresAt()) {
      final expirationDate = DateTime.fromMillisecondsSinceEpoch(
        banInfo.expiresAt.toInt() * 1000,
      );
      final date = DateFormat.yMd().format(expirationDate);
      final relative = timeago.format(expirationDate, allowFromNow: true);

      expires = '$relative ($date)';
    }

    return KyberContentDialog(
      constraints: const .new(
        maxWidth: 600,
        maxHeight: 400,
      ),
      title: const Text('Banned from Server'),
      content: Column(
        mainAxisSize: .min,
        children: [
          const Text('You are banned from this server.'),
          const SizedBox(height: 10),
          Text('Reason: ${banInfo.reason}'),
          const SizedBox(height: 10),
          Text('Expires: $expires'),
          const SizedBox(height: 10),
          const Text(
            'This ban was issued by the server host and not by Kyber directly. '
            'If you believe this ban was issued in error, please contact the server host for appeals.',
            style: TextStyle(
              fontSize: 12,
              color: kWhiteColor,
            ),
            textAlign: .center,
          ),
        ],
      ),
      actions: [
        KyberButton(
          text: 'OK',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
