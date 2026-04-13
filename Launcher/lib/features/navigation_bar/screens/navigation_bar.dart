import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/features/kyber/helper/kyber_status_helper.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_api_status_cubit.dart';
import 'package:kyber_launcher/features/kyber/providers/kyber_status_cubit.dart';
import 'package:kyber_launcher/features/kyber/services/kyber_grpc_service.dart';
import 'package:kyber_launcher/features/kyber/widgets/api_status_box.dart';
import 'package:kyber_launcher/features/lightswitch/models/status.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/dialogs/confirm_close_dialog.dart';
import 'package:kyber_launcher/features/navigation_bar/helper/drag_and_drop_handler.dart';
import 'package:kyber_launcher/features/navigation_bar/helper/protocol_helper.dart';
import 'package:kyber_launcher/features/navigation_bar/providers/status_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/services/app_initialization_service.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/drag_drop_overlay.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/keyboard_shortcuts_wrapper.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/navigation_content.dart';
import 'package:kyber_launcher/features/server_browser/providers/ingame_view_cubit.dart';
import 'package:kyber_launcher/features/setup/screens/walk_through_setup.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:window_manager/window_manager.dart';

class NavigationBar extends StatefulWidget {
  const NavigationBar({
    required this.child,
    required this.shellContext,
    required this.state,
    super.key,
  });

  final Widget child;
  final BuildContext? shellContext;
  final GoRouterState state;

  @override
  State<NavigationBar> createState() => _NavigationBarState();
}

class _NavigationBarState extends State<NavigationBar>
    with ProtocolListener, WindowListener {
  bool isDragging = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _deferredInitialization();
  }

  void _setupListeners() {
    sl.get<KyberGRPCServer>().start();
    windowManager.addListener(this);
    protocolHandler.addListener(this);
  }

  void _deferredInitialization() {
    Timer.run(() async {
      if (!context.read<StatusCubit>().state.initialized) return;
      await AppInitializationService.initialize(context);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    protocolHandler.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    final isPreventClose = await windowManager.isPreventClose();
    if (!mounted) return;

    if (isPreventClose) {
      if (!sl.isRegistered<MaximaGameInstance>()) {
        await windowManager.destroy();
        return;
      }

      await showKyberDialog(
        context: context,
        builder: (_) => const ConfirmCloseDialog(),
      );
    }
  }

  @override
  void onProtocolUrlReceived(String url) => ProtocolHelper.handleCall(url);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return KeyboardShortcutsWrapper(
      child: BlocConsumer<StatusCubit, ApplicationStatus>(
        listenWhen: (prev, state) => prev.initialized != state.initialized,
        listener: _handleStatusChange,
        builder: (context, state) => _buildContent(state),
      ),
    );
  }

  Future<void> _handleStatusChange(
    BuildContext context,
    ApplicationStatus state,
  ) async {
    if (!state.initialized) return;

    await AppInitializationService.initialize(context);
    await AppInitializationService.startServices(context);
  }

  Widget _buildContent(ApplicationStatus state) {
    return BlocConsumer<LightswitchCubit, LightswitchStatus>(
      listener: _handleApiStatusChange,
      listenWhen: (prev, state) =>
          prev.status == .down && state.status != .down,
      builder: (context, apiState) {
        if (apiState.status == .down) {
          return const ApiStatusBox();
        }

        if (!state.initialized) {
          return const WalkThroughSetup();
        }

        return _buildMainContent();
      },
    );
  }

  void _handleApiStatusChange(
    BuildContext context,
    LightswitchStatus apiState,
  ) {
    if (apiState.status == .down) return;

    final state = context.read<StatusCubit>().state;
    if (state.initialized) {
      context.read<MaximaCubit>().requestLogin();
    }
  }

  Widget _buildMainContent() {
    return DropRegion(
      formats: DragAndDropHandler.supportedFormats,
      onDropOver: _handleDropOver,
      onDropEnter: (_) => setState(() => isDragging = true),
      onDropLeave: (_) => setState(() => isDragging = false),
      onDropEnded: (_) => setState(() => isDragging = false),
      onPerformDrop: _handleDrop,
      child: Stack(
        children: [
          BlocListener<KyberStatusCubit, KyberStatusState>(
            listener: _handleKyberStatusChange,
            child: NavigationContent(
              state: widget.state,
              onMaximaLoggedIn: _onMaximaLoggedIn,
              child: widget.child,
            ),
          ),
          if (isDragging) const DragDropOverlay(),
        ],
      ),
    );
  }

  Future<void> _onMaximaLoggedIn() async {
    await AppInitializationService.startServices(context);
  }

  Future<DropOperation> _handleDropOver(DropOverEvent event) async {
    if (event.session.allowedOperations.contains(DropOperation.copy) &&
        event.session.allowedOperations.length == 1) {
      return DropOperation.none;
    }

    if (!event.session.items.every(
      (file) => DragAndDropHandler.supportedFormats.any(
        (format) => file.canProvide(format),
      ),
    )) {
      return .none;
    }

    if (event.session.allowedOperations.contains(DropOperation.copy)) {
      return .copy;
    }

    return .none;
  }

  Future<void> _handleDrop(PerformDropEvent event) async {
    if (event.session.allowedOperations.contains(DropOperation.copy) &&
        event.session.allowedOperations.length == 1) {
      return;
    }

    isDragging = false;
    setState(() {});
    DragAndDropHandler.handleDragAndDrop(event.session.items);
  }

  Future<void> _handleKyberStatusChange(
    BuildContext context,
    KyberStatusState state,
  ) async {
    final viewCubit = context.read<IngameViewCubit>();
    final l10n = AppLocalizations.of(context)!;

    if (state is KyberStatusInitial && viewCubit.state.server != null) {
      viewCubit.unloadServer();
      final currentRoute = router
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation
          .split('?')
          .first;

      if (currentRoute == '/ingame') {
        router.go('/home');
      }
    } else if (state is KyberStatusPlaying &&
        state.server != null &&
        viewCubit.state.server?.id != state.server?.id) {
      if (viewCubit.state.server != null &&
          viewCubit.state.server?.id != state.server?.id) {
        viewCubit.unloadServer();
      }

      if (state.server == null) {
        NotificationService.error(
          message: l10n.serverNotFound,
        );
        return;
      }

      if (!state.joined) {
        return;
      }

      await viewCubit.loadServer(state.server!);
      router.push('/ingame');
    }
  }
}