import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/providers/download_manager_cubit.dart';
import 'package:kyber_launcher/features/navigation_bar/widgets/social_bar.dart';
import 'package:kyber_launcher/shared/ui/navigation_bar/navigation_bar_seperator.dart';
import 'package:kyber_launcher/shared/ui/navigation_bar/widgets/navigation_bar_item.dart';
import 'package:kyber_launcher/shared/ui/navigation_bar/widgets/navigation_bar_sub_item.dart';
import 'package:kyber_launcher/shared/ui/navigation_bar/widgets/navigation_download_info.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';

class NavigationBarList extends StatefulWidget {
  const NavigationBarList({required this.route, super.key});

  final String route;

  @override
  State<NavigationBarList> createState() => _NavigationBarListState();
}

class NavigationBarEntry {
  NavigationBarEntry(this.title, this.route);

  String title;
  String route;
}

class _NavigationBarListState extends State<NavigationBarList> {
  late StreamSubscription<String> navigationStream;

  int _activeItem = 0;
  bool _hovering = false;
  bool _showPositioned = false;
  int? _hoveringIndex;

  List<NavigationBarEntry> getItems() => [
    NavigationBarEntry('HOME', 'home'),
    NavigationBarEntry('HOST', 'server_host'),
    NavigationBarEntry('STATS', 'stats'),
    NavigationBarEntry('MODS', 'mods'),
    //NavigationBarEntry('SETTINGS', 'settings'),
  ];

  @override
  void didUpdateWidget(covariant NavigationBarList oldWidget) {
    if (oldWidget.route != widget.route) {
      final items = getItems();
      final index = items.indexWhere(
        (element) =>
            element.route == widget.route.split('/').last.split('?').first,
      );

      if (index != -1) {
        setState(() {
          _activeItem = index;
        });
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 20, right: 20, top: 10),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        child: Builder(
          builder: (context) {
            if (RegExp('/').allMatches(widget.route).length > 1) {
              final routes = widget.route.split('/').skip(1);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  BackgroundBlur(
                    key: const ValueKey('subNavBarList'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 41,
                          width: 1.5,
                          color: kWhiteColor,
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          scrollDirection: Axis.horizontal,
                          separatorBuilder: (context, index) =>
                              Transform.rotate(
                                angle: 18 * 3.14 / 180,
                                child: UnconstrainedBox(
                                  child: Container(
                                    height: 20,
                                    width: 2,
                                    color: kGrayColor,
                                  ),
                                ),
                              ),
                          itemBuilder: (context, index) => NavigationBarSubItem(
                            isLast: index == routes.length - 1,
                            route: routes.elementAt(index),
                            index: index,
                            fullRoute: "/${routes.take(index + 1).join("/")}",
                          ),
                          itemCount: routes.length,
                        ),
                        Container(
                          height: 41,
                          width: 1.5,
                          color: kWhiteColor,
                        ),
                      ],
                    ),
                  ),
                  RepaintBoundary(
                    child: BlocBuilder<DownloadCubit, DownloadState>(
                      //buildWhen: (previous, current) => previous.currentDownload != current.currentDownload,
                      builder: (context, state) {
                        final currentDownload = state is DownloadLoaded
                            ? state.currentDownload
                            : null;

                        if (currentDownload == null) {
                          return const SizedBox.shrink();
                        }

                        return GestureDetector(
                          onTap: () {
                            router.goNamed('downloads');
                          },
                          child: const NavigationDownloadInfo(),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            final items = getItems();

            return BackgroundBlur(
              child: Row(
                children: [
                  ListView.separated(
                    key: const ValueKey('navBarList'),
                    shrinkWrap: true,
                    itemCount: items.length + 2,
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.zero,
                    separatorBuilder: (context, index) {
                      final active =
                          index == _activeItem || index == _activeItem + 1;
                      final hover =
                          _hoveringIndex == index - 1 || _hoveringIndex == index;
                      return NavigationBarSeperator(
                        active: active,
                        hover: _hovering && hover,
                        showPositioned: active && _showPositioned,
                      );
                    },
                    itemBuilder: (context, index) {
                      if (index == 0 || index == items.length + 1) {
                        return const SizedBox.shrink();
                      }

                      index = index - 1;
                      final item = items[index];
                      final active = _hovering && _hoveringIndex == index;
                      final child = NavigationBarItem(
                        item: item,
                        onTap: () async {
                          if (widget.route == '/${item.route}') {
                            return;
                          }

                          router.go('/${item.route}');

                          // hack to make the positioned animation work
                          setState(() => _showPositioned = false);
                          await Future.delayed(
                            const Duration(milliseconds: 5),
                          );
                          setState(() {
                            _activeItem = index;
                            _showPositioned = true;
                          });
                        },
                        onHover: (value) => setState(() {
                          _hovering = value;
                          _hoveringIndex = value ? index : null;
                        }),
                        active: _activeItem == index,
                        hover: active,
                      );

                      return child;
                    },
                  ),
                  const Expanded(
                    child: SocialBar(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
