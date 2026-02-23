import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';

class ModLimitDialog extends StatelessWidget {
  const ModLimitDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      title: const Text('Mod Limit Reached'),
      constraints: const BoxConstraints(
        maxWidth: 600,
        maxHeight: 400,
      ),
      content: const Text(
        '''
        You have reached the maximum number of mods (1739) that can be loaded. 
        To continue you must remove some mods from your collection.
        
        This is a current technical limitation of KYBER and may be lifted in the future.
        ''',
        textAlign: TextAlign.center,
      ),
      actions: [
        KyberButton(text: 'OKAY', onPressed: () => Navigator.of(context).pop()),
      ],
    );
  }
}
