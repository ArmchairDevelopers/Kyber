import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/server_browser/helpers/server_browser_helper.dart';
import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_browser_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class ServerButtonRow extends StatelessWidget {
  const ServerButtonRow({
    super.key,
    this.server,
    this.onServerSelected,
    this.onClose,
    this.onPageChanged,
    this.selectedIndex = 0,
    this.hasModsInstalled = false,
  });

  final bool hasModsInstalled;
  final Server? server;
  final VoidCallback? onServerSelected;
  final void Function(int page)? onPageChanged;
  final int selectedIndex;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final server =
        this.server ??
        context.read<ServerBrowserCubit>().state.selectedServer!.serverInfo;
    final state = onServerSelected != null
        ? null
        : context.watch<ServerBrowserCubit>().state;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ListenableBuilder(
          listenable: sl.get<ModService>(),
          builder: (_, __) {
            var disabled = false;
            if (onServerSelected == null && !hasModsInstalled) {
              disabled = !ServerBrowserHelper.canJoinServer(
                context,
                server: server,
                ignoreInstalled: true,
              );
            }

            return KyberButton(
              onPressed:
                  onServerSelected ??
                  (!disabled
                      ? () async {
                          context.read<ServerBrowserCubit>().joinServer();
                        }
                      : null),
              text: onServerSelected != null
                  ? 'MODERATE'
                  : hasModsInstalled
                  ? 'Play Now'
                  : 'Download Mods',
            );
          },
        ),
        if (onPageChanged != null &&
            (server.description.isNotEmpty ||
                state?.selectedServer is GroupedServer))
          SizedBox(
            height: 35,
            width: 200,
            child: KyberTabBar(
              tabs: [
                const Text('MODS'),
                if (server.description.isNotEmpty) const Text('INFO'),
                if (context.read<ServerBrowserCubit>().state.selectedServer
                    is GroupedServer)
                  const Text('SERVERS'),
              ],
              onChanged: onPageChanged ?? (index) {},
              selectedIndex: selectedIndex,
            ),
          ),
      ],
    );
  }
}
