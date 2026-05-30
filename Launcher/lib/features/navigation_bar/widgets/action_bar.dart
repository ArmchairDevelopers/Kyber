import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_navigation_bar_widget.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/window_buttons.dart';

class ActionBar extends StatelessWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: .end,
      crossAxisAlignment: .start,
      children: [
        RepaintBoundary(
          child: MaximaNavigationBarWidget(),
        ),
        WindowButtons(),
      ],
    );
  }
}
