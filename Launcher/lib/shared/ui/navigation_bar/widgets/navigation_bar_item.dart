import 'package:fluent_ui/fluent_ui.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/navigation_bar/navigation_bar_list.dart';

class NavigationBarItem extends StatelessWidget {
  const NavigationBarItem({
    required this.item,
    required this.onHover,
    required this.onTap,
    required this.hover,
    required this.active,
    super.key,
    this.child,
  });

  final Widget? child;
  final NavigationBarEntry item;
  final ValueChanged<bool> onHover;
  final void Function() onTap;
  final bool active;
  final bool hover;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 50,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: (_) => onHover(true),
          onExit: (_) => onHover(false),
          child: Container(
            color: active ? const Color.fromRGBO(67, 73, 76, 0.3) : null,
            child: Center(
              child: Row(
                mainAxisAlignment: .center,
                children: [
                  ?child,
                  Text(
                    item.title.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: FontFamily.battlefrontUI,
                      fontSize: 21,
                      color: hover
                          ? kActiveColor
                          : active
                          ? kWhiteColor
                          : kInactiveColor,
                      shadows: hover
                          ? [
                              Shadow(
                                color: kActiveColor.withOpacity(.6),
                                blurRadius: 255,
                              ),
                            ]
                          : null,
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
