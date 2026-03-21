import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';

class PartyOverlay extends StatelessWidget {
  const PartyOverlay({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        BlocSelector<SessionCubit, SessionState, PendingInvite?>(
          selector: (state) => switch (state) {
            PartyInitial(:final pendingInvite) => pendingInvite,
            InParty(:final pendingInvite) => pendingInvite,
          },
          builder: (context, invite) {
            return _InviteBanner(invite: invite);
          },
        ),
        BlocSelector<SessionCubit, SessionState, JoinGameInfo?>(
          selector: (state) => switch (state) {
            InParty(:final joinGameInfo) => joinGameInfo,
            _ => null,
          },
          builder: (context, info) {
            return _JoinGameBanner(info: info);
          },
        ),
      ],
    );
  }
}

class _InviteBanner extends StatefulWidget {
  const _InviteBanner({required this.invite});

  final PendingInvite? invite;

  @override
  State<_InviteBanner> createState() => _InviteBannerState();
}

class _InviteBannerState extends State<_InviteBanner>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  AnimationController? _progressController;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    if (widget.invite != null) {
      _controller.forward();
      _startProgress(widget.invite!);
    }
  }

  @override
  void didUpdateWidget(_InviteBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.invite != null && oldWidget.invite == null) {
      _loading = false;
      _controller.forward();
      _startProgress(widget.invite!);
    } else if (widget.invite == null && oldWidget.invite != null) {
      _controller.reverse();
      _progressController?.stop();
    }
  }

  void _startProgress(PendingInvite invite) {
    _progressController?.dispose();

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      invite.expiresAt.toInt() * 1000,
    );
    final now = DateTime.now();
    final remaining = expiresAt.difference(now);

    if (remaining.isNegative) {
      _clear();
      return;
    }

    _progressController = AnimationController(
      vsync: this,
      duration: remaining,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _clear();
        }
      });
    _progressController!.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _progressController?.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final invite = widget.invite;
    if (_loading || invite == null) return;

    setState(() => _loading = true);

    try {
      await context.read<SessionCubit>().acceptInvite(invite.partyId);
      if (mounted) {
        NotificationService.success(
          message: "Joined ${invite.inviter.name}'s party",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        NotificationService.error(message: 'Failed to join party');
      }
    }
  }

  Future<void> _clear() async {
    setState(() => _loading = false);
    context.read<SessionCubit>().clearInvite();
  }

  Future<void> _decline() async {
    final invite = widget.invite;
    if (_loading || invite == null) return;

    setState(() => _loading = true);

    try {
      await context.read<SessionCubit>().declineInvite(invite.partyId);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        NotificationService.error(message: 'Failed to decline invite');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 75,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildBanner(),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final invite = widget.invite;
    if (invite == null) return const SizedBox.shrink();

    return BackgroundBlur(
      borderRadius: const .horizontal(
        left: .circular(kDefaultInnerBorderRadius),
      ),
      blurColorOpacity: 0.6,
      blurIntensity: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340, minWidth: 300),
        decoration: BoxDecoration(
          border: const Border(
            left: BorderSide(color: decoColor, width: 2),
            top: BorderSide(color: decoColor, width: 2),
            bottom: BorderSide(color: decoColor, width: 2),
          ),
          borderRadius: .horizontal(
            left: const .circular(kDefaultInnerBorderRadius),
          ),
        ),
        child: Stack(
          clipBehavior: .antiAliasWithSaveLayer,
          children: [
            Padding(
              padding: const .symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: .min,
                children: [
                  MaximaAvatar(pd: invite.inviter.id, height: 36, width: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
                      mainAxisSize: .min,
                      children: [
                        Text(
                          invite.inviter.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 14,
                            color: kWhiteColor,
                            height: 1,
                          ),
                          overflow: .ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Party Invite'.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 11,
                            color: kButtonBorder,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BannerAction(
                    icon: FluentIcons.cancel,
                    color: Colors.red.light,
                    onPressed: _loading ? null : _decline,
                  ),
                  const SizedBox(width: 6),
                  _BannerAction(
                    icon: mt.Icons.check,
                    color: Colors.green.light,
                    onPressed: _loading ? null : _accept,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _progressController ?? kAlwaysDismissedAnimation,
                builder: (context, _) {
                  final value = _progressController?.value ?? 0;
                  return FractionallySizedBox(
                    alignment: .centerLeft,
                    widthFactor: (1.0 - value).clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: kActiveColor,
                      child: const SizedBox(height: 3),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinGameBanner extends StatefulWidget {
  const _JoinGameBanner({required this.info});

  final JoinGameInfo? info;

  @override
  State<_JoinGameBanner> createState() => _JoinGameBannerState();
}

class _JoinGameBannerState extends State<_JoinGameBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: .zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    if (widget.info != null) _controller.forward();
  }

  @override
  void didUpdateWidget(_JoinGameBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.info != null && oldWidget.info == null) {
      _controller.forward();
    } else if (widget.info == null && oldWidget.info != null) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _buildBanner(),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final info = widget.info;
    if (info == null) return const SizedBox.shrink();

    return BackgroundBlur(
      borderRadius: const .horizontal(
        left: .circular(kDefaultInnerBorderRadius),
      ),
      blurColorOpacity: 0.6,
      blurIntensity: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300, minWidth: 260),
        decoration: BoxDecoration(
          border: const Border(
            left: BorderSide(color: decoColor, width: 2),
            top: BorderSide(color: decoColor, width: 2),
            bottom: BorderSide(color: decoColor, width: 2),
          ),
          borderRadius: .horizontal(
            left: const .circular(kDefaultInnerBorderRadius),
          ),
        ),
        child: Padding(
          padding: const .symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: .min,
            children: [
              Icon(FluentIcons.game, size: 24, color: kActiveColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  children: [
                    Text(
                      info.serverName.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: FontFamily.battlefrontUI,
                        fontSize: 13,
                        color: kWhiteColor,
                        height: 1,
                      ),
                      overflow: .ellipsis,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'JOINING GAME',
                      style: TextStyle(
                        fontFamily: FontFamily.battlefrontUI,
                        fontSize: 11,
                        color: kButtonBorder,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _BannerAction(
                icon: mt.Icons.open_in_full,
                color: kActiveColor,
                onPressed: () {
                  context.read<SessionCubit>().showJoinGameDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerAction extends StatefulWidget {
  const _BannerAction({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  State<_BannerAction> createState() => _BannerActionState();
}

class _BannerActionState extends State<_BannerAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovered && !disabled ? widget.color : decoColor,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            widget.icon,
            size: 16,
            color: disabled
                ? kInactiveColor
                : _hovered
                ? widget.color
                : kWhiteColor,
          ),
        ),
      ),
    );
  }
}
