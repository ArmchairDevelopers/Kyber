import 'dart:async';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart' hide FluentDialogRoute, TitleBar;
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/title_bar.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/window_buttons.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';

const kDefaultContentDialogConstraints = BoxConstraints(
  maxWidth: 368,
  maxHeight: 756,
);

Path getPath(Size size, double value) {
  final path_0 = Path();
  path_0.moveTo(0, size.height * 0.05);
  path_0.lineTo(size.width * 0.5, (size.height * 0.05) * (1 - value));
  path_0.lineTo(size.width * 1, size.height * 0.05);
  path_0.lineTo(size.width * 1, size.height * 0.95);
  path_0.lineTo(size.width * 0.5, size.height * (0.95 + (0.05 * value)));
  path_0.lineTo(0, size.height * 0.95);
  path_0.lineTo(0, size.height * 0.05);
  return path_0;
}

class _KyberDialogShapeClipper extends CustomClipper<Path> {
  _KyberDialogShapeClipper({required this.animation})
    : super(reclip: animation);
  Animation<double> animation;

  @override
  Path getClip(Size size) {
    return getPath(size, animation.value);
  }

  @override
  bool shouldReclip(covariant CustomClipper oldClipper) {
    return true;
  }
}

class _KyberDialogShapeBorderPainter extends CustomPainter {
  _KyberDialogShapeBorderPainter({required this.animation})
    : super(repaint: animation);
  Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final paintStroke0 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = kGrayColor;

    canvas.drawPath(getPath(size, animation.value), paintStroke0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class KyberContentDialog extends StatefulWidget {
  /// Creates a content dialog.
  const KyberContentDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.style,
    this.contentPadding,
    this.constraints = kDefaultContentDialogConstraints,
  });

  /// The title of the dialog. Usually, a [Text] widget
  final Widget? title;

  /// The content of the dialog. Usually, a [Text] widget
  final Widget? content;

  /// The actions of the dialog. Usually, a List of [Button]s
  final List<Widget>? actions;

  final EdgeInsets? contentPadding;

  /// The style used by this dialog. If non-null, it's merged with
  /// [FluentThemeData.dialogTheme]
  final ContentDialogThemeData? style;

  /// The constraints of the dialog. It defaults to `BoxConstraints(maxWidth: 368)`
  final BoxConstraints constraints;

  @override
  State<KyberContentDialog> createState() => _KyberContentDialogState();
}

class _KyberContentDialogState extends State<KyberContentDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 175),
    );
    _animation = Tween(begin: 0.toDouble(), end: 1.toDouble()).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    Future.delayed(
      const Duration(milliseconds: 50),
      () => _animationController.forward(),
    );
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasFluentTheme(context));
    var style = ContentDialogThemeData.standard(
      FluentTheme.of(
        context,
      ),
    ).merge(FluentTheme.of(context).dialogTheme.merge(widget.style));
    style = style.merge(
      const ContentDialogThemeData(barrierColor: Colors.transparent),
    );
    return DisableAcrylic(
      child: Align(
        alignment: AlignmentDirectional.center,
        child: Container(
          constraints: widget.constraints,
          child: ClipPath(
            clipper: _KyberDialogShapeClipper(animation: _animation),
            child: ClipRRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(.2),
                      ),
                      alignment: Alignment.center,
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: Padding(
                            padding:
                                widget.contentPadding ??
                                const EdgeInsets.all(
                                  20,
                                ).copyWith(top: 50, bottom: 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.title != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: DefaultTextStyle.merge(
                                      style: style.titleStyle,
                                      child: DefaultTextStyle.merge(
                                        style: const TextStyle(
                                          fontFamily: FontFamily.aurebesh,
                                          color: decoColor,
                                          height: 1,
                                          fontSize: 12,
                                        ),
                                        child: Center(child: widget.title),
                                      ),
                                    ),
                                  ),
                                if (widget.title != null)
                                  Padding(
                                    padding: style.titlePadding ?? .zero,
                                    child: DefaultTextStyle.merge(
                                      style: style.titleStyle,
                                      child: DefaultTextStyle.merge(
                                        style: const TextStyle(
                                          height: 1,
                                        ),
                                        child: Center(child: widget.title),
                                      ),
                                    ),
                                  ),
                                if (widget.content != null)
                                  Expanded(
                                    child: Padding(
                                      padding: style.bodyPadding ?? .zero,
                                      child: widget.content,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.actions != null)
                          Container(
                            padding: const EdgeInsets.all(
                              20,
                            ).copyWith(bottom: 60, top: 10),
                            child: ButtonTheme.merge(
                              data:
                                  style.actionThemeData ??
                                  const ButtonThemeData(),
                              child: () {
                                if (widget.actions!.length == 1) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerEnd,
                                        child: widget.actions!.first,
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: widget.actions!.map((e) {
                                    return Padding(
                                      padding: const EdgeInsetsDirectional.only(
                                        end: 20,
                                      ),
                                      child: e,
                                    );
                                  }).toList(),
                                );
                              }(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _KyberDialogShapeBorderPainter(
                          animation: _animation,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showKyberDialog<T extends Object?>({
  required BuildContext context,
  required WidgetBuilder builder,
  RouteTransitionsBuilder transitionBuilder =
      FluentDialogRoute._defaultTransitionBuilder,
  Duration? transitionDuration,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  String? barrierLabel,
  Color? barrierColor = const Color(0x8A000000),
  bool barrierDismissible = true,
  bool dismissWithEsc = true,
}) {
  assert(debugCheckHasFluentLocalizations(context));

  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(
      context,
      rootNavigator: useRootNavigator,
    ).context,
  );

  return Navigator.of(
    context,
    rootNavigator: useRootNavigator,
  ).push<T>(
    FluentDialogRoute<T>(
      context: context,
      builder: builder,
      barrierColor: barrierColor,
      barrierDismissible: barrierDismissible,
      barrierLabel: FluentLocalizations.of(context).modalBarrierDismissLabel,
      dismissWithEsc: dismissWithEsc,
      settings: routeSettings,
      transitionBuilder: transitionBuilder,
      transitionDuration:
          transitionDuration ??
          FluentTheme.maybeOf(context)?.fastAnimationDuration ??
          const Duration(milliseconds: 300),
      themes: themes,
    ),
  );
}

class FluentDialogRoute<T> extends RawDialogRoute<T> {
  FluentDialogRoute({
    required WidgetBuilder builder,
    required BuildContext context,
    CapturedThemes? themes,
    super.barrierDismissible,
    super.barrierColor = const Color(0x8A000000),
    String? barrierLabel,
    super.transitionDuration,
    super.transitionBuilder = _defaultTransitionBuilder,
    super.settings,
    bool dismissWithEsc = true,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) {
           final pageChild = Builder(builder: builder);
           final dialog = themes?.wrap(pageChild) ?? pageChild;
           return SafeArea(
             child: BackgroundBlur(
               blurColor: Colors.transparent,
               blurColorOpacity: 0,
               blurIntensity: 0,
               child: Actions(
                 actions: {
                   if (dismissWithEsc) DismissIntent: _DismissAction(context),
                 },
                 child: FocusScope(
                   autofocus: true,
                   child: Stack(
                     children: [
                       dialog,
                       const SizedBox(
                         height: 35,
                         child: Row(
                           children: [
                             Expanded(
                               child: Padding(
                                 padding: EdgeInsets.only(left: 16),
                                 child: TitleBar(),
                               ),
                             ),
                             WindowButtons(),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
               ),
             ),
           );
         },
         barrierLabel:
             barrierLabel ??
             FluentLocalizations.of(context).modalBarrierDismissLabel,
       );

  @override
  bool get opaque => false;

  static Widget _defaultTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: 6 * animation.value,
        sigmaY: 6 * animation.value,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        ),
        child: child,
      ),
    );
  }
}

class _DismissAction extends DismissAction {
  _DismissAction(this.context);

  final BuildContext context;

  @override
  void invoke(covariant DismissIntent intent) {
    Navigator.of(context).pop();
  }
}
