import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:kyber/gen/Proto/mod_bridge.pb.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/models/download_link_type.dart';
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:nexus_gql/nexus_gql.dart';

class FileDownloadDialog extends StatefulWidget {
  const FileDownloadDialog({
    required this.file,
    required this.modId,
    super.key,
  });

  final String modId;
  final Query$modFiles$modFiles file;

  @override
  State<FileDownloadDialog> createState() => _FileDownloadDialogState();
}

class _FileDownloadDialogState extends State<FileDownloadDialog> {
  @override
  Widget build(BuildContext context) {
    return KyberContentDialog(
      constraints: const BoxConstraints(
        maxWidth: 700,
        maxHeight: 500,
      ),
      title: Text(widget.file.name),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Description'.toUpperCase(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: kWhiteColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: HtmlWidget(
                widget.file.description ?? '-',
              ),
            ),
          ),
        ],
      ),
      actions: [
        KyberButton(
          text: 'CLOSE',
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        KyberButton(
          text: 'Download',
          onPressed: () async {
            // Use new DownloadRequest API
            final request = DownloadRequest(
              link:
                  'https://www.nexusmods.com/starwarsbattlefront22017/mods/${widget.modId}?tab=files&file_id=${widget.file.fileId}',
              displayName: widget.file.name,
              metadata: {
                'name': widget.file.name,
                'version': widget.file.version,
                'modId': int.parse(widget.modId),
                'fileSize': int.tryParse(widget.file.sizeInBytes ?? '0') ?? 0,
              },
            );

            await sl.get<DownloadOrchestrator>().enqueueDownload(request);

            NotificationService.showNotification(
              message: 'Downloading mod ${widget.file.name}',
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
