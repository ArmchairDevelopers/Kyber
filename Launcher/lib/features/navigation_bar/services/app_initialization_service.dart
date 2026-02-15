import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/module_version_service.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/services/process_info.dart';
import 'package:kyber_launcher/core/services/rich_presence.dart';
import 'package:kyber_launcher/core/services/storage_helper.dart';
import 'package:kyber_launcher/core/services/taskbar_icon_helper.dart';
import 'package:kyber_launcher/core/services/windows_utils.dart';
import 'package:kyber_launcher/features/events/providers/event_cubic.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_proxy_cubit.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/mods/dialogs/move_directory_dialog.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/navigation_bar/dialogs/disable_comp_mode_dialog.dart';
import 'package:kyber_launcher/features/navigation_bar/helper/protocol_helper.dart';
import 'package:kyber_launcher/features/nexusmods/widgets/graphql_provider.dart';
import 'package:kyber_launcher/features/server_moderation/providers/moderation_servers_cubit.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/features/settings/dialogs/update_dialog.dart';
import 'package:kyber_launcher/features/setup/dialogs/open_beta_dialog.dart';
import 'package:kyber_launcher/features/setup/dialogs/rules_dialog.dart';
import 'package:kyber_launcher/features/stats/providers/stats_cubit.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:logging/logging.dart';

class AppInitializationService {
  static final _logger = Logger('app_initialization_service');

  static Future<void> initialize(BuildContext context) async {
    if (!context.mounted) return;

    context
      ..read<MaximaCubit>()
      ..read<KyberStatusCubit>()
      ..read<KyberProxyCubit>();

    sl.get<RichPresence>().start();
  }

  static Future<void> startServices(BuildContext context) async {
    await StorageHelper.saveCurrentVersion();

    if (!context.mounted) return;

    context.read<ModerationServersCubit>();
    context.read<SessionCubit>();

    unawaited(
      sl.isReady<ModService>().then((_) {
        if (!context.mounted) return;

        NotificationService.showNotification(
          context: context,
          message: '${sl.get<ModService>().mods.length} mods loaded',
        );
      }),
    );

    if (context.mounted) {
      context.read<MaximaRtmCubit>().startPresenceStream();
      context
        ..read<StatsCubit>()
        ..read<EventCubit>();
    }

    await ProtocolHelper.initialize();

    await _checkCompatibilityMode(context);
    await _checkForUpdates(context);
    await showOpenBetaDialog(context);
    await showRulesDialog(context);
    await _showPlatformWarnings();
    await _validateModDirectory(context);
    await _handleVersionUpdate();

    TaskbarIconHelper.setWindowIcon();
  }

  static Future<void> _checkCompatibilityMode(BuildContext context) async {
    if (Platform.isWindows && WindowsUtils.isWindowsCompMode()) {
      await showKyberDialog(
        context: context,
        builder: (_) => const DisableCompModeDialog(),
      );
      exit(0);
    }
  }

  static Future<void> _checkForUpdates(BuildContext context) async {
    final update = await ModuleVersionService().updateAvailable(
      module: VersionModule.installer,
    );
    if (update && context.mounted) {
      await showKyberDialog(
        context: context,
        builder: (_) => const UpdateDialog(),
      );
    }
  }

  static Future<void> _showPlatformWarnings() async {
    if (!Platform.isWindows) return;

    if (ProcessHelper.isRunningAsAdmin()) {
      NotificationService.error(
        title: 'Admin mode',
        message: 'Drag and drop is disabled when running as admin',
      );
    }

    final isVcRuntimeInstalled = WindowsUtils.isVcRuntimeInstalled;
    if (!isVcRuntimeInstalled) {
      NotificationService.error(
        title: 'Visual C++ Runtime not installed',
        message:
            'Please install the Visual C++ Redistributable for Visual Studio 2015, 2017 and 2019',
      );
    }
  }

  static Future<void> _validateModDirectory(BuildContext context) async {
    final currentPath = ModService.getBasePath();
    final containsNonAscii = currentPath.codeUnits.any(
      (element) => element > 127,
    );

    if (containsNonAscii && context.mounted) {
      await showKyberDialog(
        context: context,
        builder: (_) => const MoveModsDirectoryDialog(isInvalid: true),
      );
    }
  }

  static Future<void> _handleVersionUpdate() async {
    if (Preferences.general.currentVersion != launcherVersion) {
      _logger.info('App updated to version $launcherVersion');

      if (Preferences.general.currentVersion != null) {
        _logger.warning('Clearing cache from previous version');
        nexusGqlClient?.cache.store.reset();
      }

      Preferences.general.currentVersion = launcherVersion;
    }
  }
}
