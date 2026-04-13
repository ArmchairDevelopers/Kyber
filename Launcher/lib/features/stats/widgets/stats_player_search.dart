import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/features/stats/providers/stats_cubit.dart';
import 'package:kyber_launcher/features/stats/providers/stats_search_cubit.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_input.dart';
import 'package:kyber_launcher/shared/ui/elements/list/kyber_list.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';

final filterDropdownKey = GlobalKey();

class StatsPlayerSearch extends StatefulWidget {
  const StatsPlayerSearch({
    super.key,
  });

  @override
  State<StatefulWidget> createState() => StatsPlayerSearchState();
}

class StatsPlayerSearchState extends State<StatsPlayerSearch> {
  final _tooltipController = OverlayPortalController();
  final textController = TextEditingController();

  final _link = LayerLink();

  double? _buttonWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocListener<StatsSearchCubit, SearchState>(
      listener: (context, state) {
        if (state is! SearchLoaded &&
            state is! SearchLoading &&
            state is! SearchError) {
          if (_tooltipController.isShowing) {
            _tooltipController.hide();
            return;
          }
        } else {
          if (!_tooltipController.isShowing) {
            _buttonWidth = filterDropdownKey.currentContext?.size?.width;
            _tooltipController.show();
          }
        }
      },
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _tooltipController,
          overlayChildBuilder: (BuildContext context) {
            return SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_tooltipController.isShowing) {
                        _tooltipController.hide();
                      }
                    },
                  ),
                  Positioned(
                    width: _buttonWidth,
                    child: CompositedTransformFollower(
                      link: _link,
                      targetAnchor: Alignment.bottomLeft,
                      showWhenUnlinked: false,
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: MenuWidget(
                          onClick: (user) {
                            _tooltipController.hide();
                            context.read<StatsCubit>().loadUser(
                              username: user.username,
                              personaId: user.personaId,
                            );
                            textController.clear();
                          },
                          width: _buttonWidth,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          child: SizedBox(
            child: KyberInput(
              suffix: const Icon(
                mt.Icons.search,
                color: kInactiveColor,
                size: 19,
              ),
              placeholder: l10n.searchPlaceholder,
              controller: textController,
              onChanged: (value) =>
                  context.read<StatsSearchCubit>().search(value),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuWidget extends StatelessWidget {
  const MenuWidget({
    required this.onClick,
    super.key,
    this.width,
  });

  final double? width;
  final void Function(EAUser value) onClick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: BackgroundBlur(
        borderRadius: BorderRadius.circular(2),
        blurColorOpacity: 0.6,
        blurIntensity: 8,
        child: Container(
          width: width ?? 200,
          height: 300,
          decoration: ShapeDecoration(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 32,
                offset: Offset(0, 20),
                spreadRadius: -8,
              ),
            ],
          ),
          child: BlocBuilder<StatsSearchCubit, SearchState>(
            builder: (context, state) {
              if (state is SearchLoading) {
                return const Center(
                  child: ProgressRing(),
                );
              }

              if (state is SearchError) {
                return Center(
                  child: Text(
                    state.error,
                    style: TextStyle(
                      fontFamily: currentFont,
                      fontSize: 18,
                      color: kWhiteColor,
                    ),
                  ),
                );
              }

              if (state is! SearchLoaded) {
                return const SizedBox();
              }

              if (state.result.isEmpty) {
                return Center(
                  child: Text(
                    l10n.noPlayersFound.toUpperCase(),
                    style: TextStyle(
                      fontFamily: currentFont,
                      fontSize: 18,
                      color: kWhiteColor,
                    ),
                  ),
                );
              }

              return KyberList(
                activeIndex: -1,
                itemPadding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: state.result.length,
                onSelectionChanged: (value) {
                  final user = state.result.elementAt(value);
                  onClick(user);
                  //controller.hide();
                  //context.read<StatsCubit>().loadUser(username: user.username, personaId: user.personaId);
                },
                itemBuilder: (context, index) {
                  final mod = state.result[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 15,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SvgPicture.network(
                          'https://flagicons.lipis.dev/flags/4x3/${mod.region.toLowerCase()}.svg',
                          height: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mod.username,
                          style: TextStyle(
                            fontFamily: currentFont,
                            fontSize: 18,
                            height: 1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        //Text(
                        //  mod.region,
                        //  style: const TextStyle(
                        //    fontFamily: FontFamily.battlefrontUI,
                        //    fontSize: 15,
                        //    color: kWhiteColor,
                        //    height: 1,
                        //  ),
                        //),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}