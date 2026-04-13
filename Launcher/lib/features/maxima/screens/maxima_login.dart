import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:grpc/grpc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/patreon/services/patreon_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart';

class MaximaLogin extends StatefulWidget {
  const MaximaLogin({super.key});

  @override
  State<MaximaLogin> createState() => _MaximaLoginState();
}

class _MaximaLoginState extends State<MaximaLogin> {
  static const _boxConstraints = BoxConstraints(
    maxWidth: 700,
    minWidth: 700,
    minHeight: 100,
  );

  bool _whitelistPrompt = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        LogicalKeySet(
          .control,
          .shift,
          .alt,
        ): _toggleFrbDebugLogs,
      },
      child: Focus(
        autofocus: true,
        child: Center(
          child: ConstrainedBox(
            constraints: _boxConstraints,
            child: ClipRRect(
              borderRadius: .circular(kDefaultOuterBorderRadius),
              child: BackgroundBlur(
                child: Container(
                  constraints: _boxConstraints,
                  decoration: BoxDecoration(
                    border: kDefaultAllBorder,
                    borderRadius: .circular(
                      kDefaultOuterBorderRadius,
                    ),
                  ),
                  padding: kDefaultPadding,
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    children: [
                      _Header(),
                      BlocBuilder<MaximaCubit, MaximaState>(
                        builder: _buildContent,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFrbDebugLogs() {
    Preferences.debug.frbDebugLogs = !Preferences.debug.frbDebugLogs;
    NotificationService.info(
      message:
          '${Preferences.debug.frbDebugLogs ? 'Enabled' : 'Disabled'} debug logs',
    );
  }

  Widget _buildContent(BuildContext context, MaximaState state) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return _StatusRow(
        text: _whitelistPrompt ? l10n.loading : l10n.waitingForResponse,
      );
    }

    if (_whitelistPrompt) {
      return _WhitelistPrompt(
        displayName: state.servicePlayer?.displayName,
        onLogout: () => context.read<MaximaCubit>().logout(),
        onAddToWhitelist: () => _handleAddToWhitelist(context),
      );
    }

    final errorBlock = _buildErrorBlock(context, state);
    if (errorBlock != null) return errorBlock;

    return switch (state.status) {
      MaximaStatus.starting => _StatusRow(text: l10n.maximaStarting),
      MaximaStatus.loading => _StatusRow(text: l10n.fetchingData),
      _ => _LoginIntro(onLogin: () => _requestLogin(context)),
    };
  }

  Widget? _buildErrorBlock(BuildContext context, MaximaState state) {
    final l10n = AppLocalizations.of(context)!;
    if (state.status != MaximaStatus.error) return null;

    final error = state.error ?? l10n.genericError;

    if (error.contains('GameNotOwned')) {
      return _GameNotOwned(
        eaId: state.servicePlayer?.uniqueName,
        onLogout: () => context.read<MaximaCubit>().logout(),
      );
    }

    if (error.contains('whitelist')) {
      return _WhitelistRequired(
        eaId: state.servicePlayer?.uniqueName,
        onLogout: () => context.read<MaximaCubit>().logout(),
        onAuthorizePatreon: () => _handleAuthorizePatreon(context),
      );
    }

    return _MaximaGenericError(
      error: error,
      onCopyPath: () => _copyPath(context),
      onLogout: () => context.read<MaximaCubit>().logout(),
    );
  }

  Future<void> _requestLogin(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return context.read<MaximaCubit>().requestLogin().onError((
      error,
      stackTrace,
    ) {
      if (error is! PanicException && error! is AnyhowException) return;

      final raw = error is PanicException
          ? error.message
          : (error! as AnyhowException).message;

      final message = _mapLoginError(context, raw);

      return NotificationService.showNotification(
        title: l10n.loginFailed,
        message: message,
        severity: InfoBarSeverity.error,
      );
    });
  }

  String _mapLoginError(BuildContext context, String err) {
    final l10n = AppLocalizations.of(context)!;
    if (err.contains('unknown variant `NO_SUCH_USER`')) {
      return l10n.userDoesNotExist;
    }

    if (err.contains('InvalidPassword')) {
      return l10n.passwordIncorrect;
    }

    if (err.contains('failed to find auth code')) {
      return l10n.failedToFindAuthCode;
    }

    return err;
  }

  void _copyPath(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: Directory.current.path));
    NotificationService.success(
      message: l10n.pathCopied,
    );
  }

  Future<void> _handleAuthorizePatreon(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      setState(() => _loading = true);

      final code = await PatreonService.requestOAuthLogin();
      if (code == null) {
        NotificationService.error(
          message: l10n.noAuthCodeReceived,
        );
        return;
      }

      await PatreonService.fetchToken(code);

      if (!mounted) return;
      setState(() {
        _whitelistPrompt = true;
        _loading = false;
      });

      NotificationService.success(
        title: l10n.authorizationSuccessful,
        message: l10n.patreonAuthorizedMessage,
      );
    } catch (e, s) {
      String? message;
      if (e is GrpcError) message = e.message;
      if (e is PatreonException) message = e.message;

      Logger.root.warning('Failed to authorize Patreon', e, s);

      NotificationService.showNotification(
        title: l10n.authorizationFailed,
        message: message ?? e.toString(),
        severity: InfoBarSeverity.error,
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _handleAddToWhitelist(BuildContext context) async {
    setState(() => _loading = true);
    try {
      await PatreonService.addToWhitelist();
      await Future.delayed(const Duration(milliseconds: 200));

      await context.read<MaximaCubit>().requestLogin(skipMaximaCheck: true);
    } catch (e, s) {
      final message = switch (e) {
        GrpcError() => e.message ?? AppLocalizations.of(context)!.genericError,
        PatreonException() => e.message,
        _ => e.toString(),
      };

      Logger.root.warning('Failed to add to whitelist', e, s);
      NotificationService.error(message: message);
      context.read<MaximaCubit>().emitError(message);
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Text(
      l10n.eaLogin,
      style: FluentTheme.of(context).typography.subtitle?.copyWith(
        fontFamily: currentFont,
        fontSize: 26,
        color: kActiveColor,
        shadows: [
          Shadow(
            color: kActiveColor.withOpacity(0.25),
            offset: const Offset(0, 1),
            blurRadius: 20,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 5),
        Row(
          children: [
            const SizedBox(height: 20, width: 20, child: ProgressRing()),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontFamily: currentFont,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoginIntro extends StatelessWidget {
  const _LoginIntro({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.maximaIntroText,
          style: FluentTheme.of(context).typography.body,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            KyberButton(
              text: l10n.loginWithEa,
              onPressed: onLogin,
            ),
          ],
        ),
      ],
    );
  }
}

class _WhitelistRequired extends StatelessWidget {
  const _WhitelistRequired({
    required this.eaId,
    required this.onLogout,
    required this.onAuthorizePatreon,
  });

  final String? eaId;
  final VoidCallback onLogout;
  final Future<void> Function() onAuthorizePatreon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      children: [
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 16),
          child: Row(children: [Text(l10n.eaIdDisplay(eaId ?? ''))]),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            KyberButton(text: l10n.logout, onPressed: onLogout),
            KyberButton(
              text: l10n.authorizePatreon,
              onPressed: onAuthorizePatreon,
            ),
          ],
        ),
      ],
    );
  }
}

class _WhitelistPrompt extends StatelessWidget {
  const _WhitelistPrompt({
    required this.displayName,
    required this.onLogout,
    required this.onAddToWhitelist,
  });

  final String? displayName;
  final VoidCallback onLogout;
  final Future<void> Function() onAddToWhitelist;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          Text(
            l10n.whitelistConfirmation,
          ),
          const SizedBox(height: 10),
          Text(l10n.currentAccountDisplay(displayName ?? '')),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              KyberButton(text: l10n.logout, onPressed: onLogout),
              KyberButton(
                text: l10n.addToWhitelist,
                onPressed: onAddToWhitelist,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameNotOwned extends StatelessWidget {
  const _GameNotOwned({required this.eaId, required this.onLogout});

  final String? eaId;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 16),
          child: Row(children: [Text(l10n.eaIdDisplay(eaId ?? ''))]),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.gameNotOwnedMessage,
        ),
        const SizedBox(height: 10),
        Row(
          children: [KyberButton(text: l10n.logout, onPressed: onLogout)],
        ),
      ],
    );
  }
}

class _MaximaGenericError extends StatelessWidget {
  const _MaximaGenericError({
    required this.error,
    required this.onCopyPath,
    required this.onLogout,
  });

  final String error;
  final VoidCallback onCopyPath;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bodyStyle = FluentTheme.of(
      context,
    ).typography.body?.copyWith(fontSize: 16);

    return DefaultTextStyle.merge(
      style: bodyStyle,
      child: Column(
        children: [
          Builder(
            builder: (context) {
              switch (error) {
                case 'MaximaFailedBackgroundService':
                  return Text(
                    l10n.maximaBackgroundServiceError,
                  );
                case 'MissingMaximaFiles':
                  return Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        l10n.maximaMissingFilesError,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.antivirusExclusionInstruction,
                      ),
                      const SizedBox(height: 5),
                      KyberInput(
                        initialValue: dirname(Platform.resolvedExecutable),
                        disabled: true,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          KyberButton(text: l10n.copyPath, onPressed: onCopyPath),
                        ],
                      ),
                    ],
                  );
                default:
                  return Text(error);
              }
            },
          ),
          Row(
            children: [KyberButton(text: l10n.logout, onPressed: onLogout)],
          ),
        ],
      ),
    );
  }
}

class MaximaErrorWidget extends StatelessWidget {
  const MaximaErrorWidget({required this.state, super.key});

  final MaximaState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final error = state.error ?? '';

    if (error.contains('GameNotOwned')) {
      return _GameNotOwned(
        eaId: state.servicePlayer?.uniqueName,
        onLogout: () => context.read<MaximaCubit>().logout(),
      );
    }

    if (state.status == MaximaStatus.error && !error.contains('whitelist')) {
      return _MaximaGenericError(
        error: error.isEmpty ? l10n.genericError : error,
        onLogout: () => context.read<MaximaCubit>().logout(),
        onCopyPath: () async {
          await Clipboard.setData(ClipboardData(text: Directory.current.path));

          if (!context.mounted) return;

          NotificationService.success(
            message: l10n.pathCopied,
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}