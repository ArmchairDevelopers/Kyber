import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';

const _rules = '''
When using KYBER, you agree to the following:

- **No Cheating**:  
  You will not use cheats, bots, or unauthorized tools to gain an unfair advantage.

- **No DDoSing or Hacking**:  
  You will not disrupt or interfere with KYBER’s services, servers, or users.

- **No Abuse or Exploitation**:  
  You will not abuse, misuse, or exploit KYBER’s APIs, systems, or features.

- **Lawful Use Only**:  
  You will not use KYBER for any unlawful or malicious activities.

- **Respect Our Community**:  
  You will not engage in harassment, unwelcome communication, hate speech, or other harmful behavior towards other users or our team.

Violating these rules may result in account suspension, banning, or other corrective actions.

(Read the full [Terms of Service](https://kyber.gg/about/tos))

Armchair Developers and/or Electronic Arts may take action against users who violate the KYBER Code of Conduct and the STAR WARS™ Battlefront™ II [EULA](https://www.ea.com/legal/user-agreement), respectively.''';

Future<void> showRulesDialog(BuildContext context) async {
  if (Preferences.general.acceptedRules) {
    return;
  }
  final result = await showKyberDialog<bool?>(
    context: context,
    builder: (_) => const RulesDialog(),
  );
  if (result == null || !result) {
    return showRulesDialog(context);
  }

  Preferences.general.acceptedRules = true;
}

class RulesDialog extends StatefulWidget {
  const RulesDialog({super.key});

  @override
  State<RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<RulesDialog> {
  int countdown = 5;
  late Timer timer;

  @override
  void initState() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown == 0) {
        return t.cancel();
      }

      setState(() => countdown--);
    });
    super.initState();
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: const Text('CODE OF CONDUCT'),
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
      content: Container(
        padding: const EdgeInsets.only(top: 4),
        width: 800,
        child: SingleChildScrollView(
          child: MarkdownBody(
            data: _rules,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontFamily: FontFamily.battlefrontUI,
                color: kWhiteColor,
              ),
              a: TextStyle(
                color: kActiveColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ),
      actions: [
        KyberButton(
          icon: countdown == 0
              ? const Icon(mt.Icons.check)
              : Text(countdown.toString()),
          text: 'ACCEPT',
          onPressed: countdown != 0
              ? null
              : () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
