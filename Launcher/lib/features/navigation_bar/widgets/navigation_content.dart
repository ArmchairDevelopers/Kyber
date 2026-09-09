import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_cubit.dart';
import 'package:kyber_launcher/features/maxima/providers/maxima_rtm_cubit.dart';
import 'package:kyber_launcher/features/maxima/screens/maxima_login.dart';
import 'package:kyber_launcher/features/navigation_bar/providers/status_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/action_bar.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/title_bar.dart'
    as kl;
import 'package:kyber_launcher/shared/ui/navigation_bar/navigation_bar_list.dart';
import 'package:window_manager/window_manager.dart';

class NavigationContent extends StatelessWidget {
  const NavigationContent({
    required this.child,
    required this.state,
    required this.onMaximaLoggedIn,
    super.key,
  });

  final Widget child;
  final GoRouterState state;
  final VoidCallback onMaximaLoggedIn;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      key: const Key('navigation_view'),
      titleBar: const SizedBox(
        height: 34,
        child: Row(
          children: [
            Expanded(
              child: DragToMoveArea(
                child: Padding(padding: .only(left: 16), child: kl.TitleBar()),
              ),
            ),
            ActionBar(),
          ],
        ),
      ),
      content: BlocConsumer<MaximaCubit, MaximaState>(
        listener: (context, maximaState) async {
          if (maximaState.loggedIn &&
              !context.read<MaximaRtmCubit>().isRtmConnected()) {
            onMaximaLoggedIn();
          }
        },
        builder: (context, maximaState) {
          if (!maximaState.loggedIn) {
            return const MaximaLogin();
          }

          return BlocBuilder<StatusCubit, ApplicationStatus>(
            builder: (_, state) => Stack(
              children: [
                Positioned.fill(
                  top: 70,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
                Positioned.fill(
                  key: const ValueKey('navigation_bar_list'),
                  top: 5,
                  bottom: null,
                  child: NavigationBarList(
                    route: this.state.uri.toString(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
