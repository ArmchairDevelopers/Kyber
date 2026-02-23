import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/features/maxima/widgets/maxima_avatar.dart';
import 'package:kyber_launcher/features/reports/models/report_list_state.dart';
import 'package:kyber_launcher/features/reports/providers/report_list_cubit.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/elements/dropdown/kyber_dropdown_button.dart';
import 'package:kyber_launcher/shared/ui/elements/filter_dropdown.dart';
import 'package:kyber_launcher/shared/ui/elements/header/kyber_header.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tab_bar.dart';
import 'package:kyber_launcher/shared/ui/elements/list/kyber_list.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:timeago/timeago.dart' as timeago;

class Reports extends StatefulWidget {
  const Reports({super.key});

  @override
  State<Reports> createState() => _ReportsState();
}

class _ReportsState extends State<Reports> {
  PlayerReportSummary? selectedReport;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(kDefaultOuterBorderRadius),
      topRight: Radius.circular(kDefaultOuterBorderRadius),
    );

    return Row(
      crossAxisAlignment: .start,
      spacing: 15,
      children: [
        Expanded(
          flex: 20,
          child: Column(
            children: [
              SizedBox(
                height: 65,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: BackgroundBlur(
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: borderRadius,
                        border: Border.fromBorderSide(kDefaultBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: borderRadius.copyWith(
                          topLeft: const Radius.circular(
                            kDefaultOuterBorderRadius - 2,
                          ),
                          topRight: const Radius.circular(
                            kDefaultOuterBorderRadius - 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 14,
                          ),
                          child: Align(
                            child: SizedBox(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: KyberTabBar(
                                      tabs: [
                                        SizedBox(
                                          height: 17,
                                          child: Assets.icons.kblSwap.svg(
                                            color: kWhiteColor,
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) => context
                                          .read<ReportsCubit>()
                                          .loadReports(),
                                      selectedIndex: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    flex: 2,
                                    child: KyberSearchFilterDropdown(
                                      onSearchChanged: (value) => context
                                          .read<ReportsCubit>()
                                          .searchReports(value),
                                      dropdownContent: BlocProvider.value(
                                        value: context.read<ReportsCubit>(),
                                        child: BlocBuilder<ReportsCubit, ReportsState>(
                                          builder: (_, state) {
                                            final cubit = context.watch<ReportsCubit>();
                                            return SuperListView(
                                              children: [
                                                KyberFilterSection<ReportFilterStatus>(
                                                  title: 'STATUS',
                                                  selectedItems: [cubit.filter.state],
                                                  items: toSelectorItems(
                                                    ReportFilterStatus.values,
                                                    title: (e) => e.name,
                                                  ),
                                                  onChanged: (selected) {
                                                    cubit.setFilter(
                                                      cubit.filter.copyWith(
                                                        state: selected.first,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  KyberIconButton(
                                    onPressed: router.pop,
                                    iconData: mt.Icons.close,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(kDefaultOuterBorderRadius),
                  ),
                  child: BackgroundBlur(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(
                                    kDefaultOuterBorderRadius,
                                  ),
                                ),
                                border: Border(
                                  bottom: kDefaultBorder,
                                  left: kDefaultBorder,
                                  right: kDefaultBorder,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(
                                kDefaultOuterBorderRadius + 4,
                              ),
                            ),
                            child: RepaintBoundary(
                              key: const Key('server_list'),
                              child: Column(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      border: Border.symmetric(
                                        vertical: BorderSide(
                                          color: decoColor,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: KyberHeader(
                                      title: 'REPORTS',
                                      headerLength: 150,
                                      sections: [
                                        const ExpandedHeaderSection(
                                          children: [],
                                        ),
                                        const FixedWidthHeaderSection(
                                          width: 120,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'TOTAL REPORTS',
                                              textAlign: TextAlign.left,
                                            ),
                                          ],
                                        ),
                                        const FixedWidthHeaderSection(
                                          width: 120,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'LATEST REPORT',
                                              textAlign: TextAlign.left,
                                            ),
                                          ],
                                        ),
                                        const FixedWidthHeaderSection(
                                          width: 180,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'LATEST REASON',
                                              textAlign: TextAlign.left,
                                            ),
                                          ],
                                        ),
                                        FixedWidthHeaderSection(
                                          width: 120,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text('STATUS'.toUpperCase()),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  DefaultTextStyle.merge(
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                    child: Expanded(
                                      child: BlocBuilder<ReportsCubit, ReportsState>(
                                        builder: (context, state) {
                                          if (state is ReportsLoading ||
                                              state is ReportsInitial) {
                                            return const Center(
                                              child: ProgressRing(),
                                            );
                                          }

                                          if (state is ReportsError) {
                                            NotificationService.error(
                                              message: state.message,
                                            );
                                            return Center(
                                              child: Text(
                                                'Error loading reports: ${state.message}',
                                              ),
                                            );
                                          }

                                          state as ReportsLoaded;

                                          return KyberList(
                                            activeIndex: -1,
                                            stateless: true,
                                            blur: false,
                                            defaultTheme: false,
                                            colorOpacity: 0,
                                            itemPadding: EdgeInsets.zero,
                                            physics: const ScrollPhysics(),
                                            onSelectionChanged: (value) =>
                                                setState(() {
                                                  selectedReport =
                                                      state.filteredReports[value];
                                                }),
                                            itemBuilder: (context, index) {
                                              final report =
                                                  state.filteredReports[index];
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 15,
                                                            ),
                                                        child: Text(
                                                          report.targetUsername,
                                                          style: const TextStyle(
                                                            fontFamily: FontFamily
                                                                .battlefrontUI,
                                                            fontSize: 17,
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 120,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        report.totalReports
                                                            .toString(),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 120,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        timeago.format(
                                                          DateTime.fromMillisecondsSinceEpoch(
                                                            report.latestReportTime
                                                                    .toInt() *
                                                                1000,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 180,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        '${ReportReason.valueOf(report.reportsByReason.keys.first)?.name} (${report.reportsByReason[report.reportsByReason.keys.first]})',
                                                      ),
                                                    ),
                                                    Container(
                                                      width: 120,
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        report
                                                            .mostRecentStatus
                                                            .name,
                                                        style: TextStyle(
                                                          color:
                                                              report.state ==
                                                                  ReportState
                                                                      .OPEN
                                                              ? kActiveColor
                                                              : kGrayColor,
                                                          fontWeight:
                                                              report.state ==
                                                                  ReportState
                                                                      .OPEN
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                    .normal,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                            itemCount: state.filteredReports.length,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(
                                    kDefaultOuterBorderRadius,
                                  ),
                                ),
                                border: Border(bottom: kDefaultBorder),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 8,
          child: KyberCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 61,
                  child: Padding(
                    padding: EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ARMSEC - CASE FILE',
                          style: TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 21,
                            height: 1,
                          ),
                        ),
                        Text(
                          'EVIDENCE AND DATA SUMMARY',
                          style: TextStyle(
                            fontFamily: FontFamily.battlefrontUI,
                            fontSize: 14,
                            color: kWhiteColor,
                            height: 0.9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const CardSection(),
                if (selectedReport != null) ...[
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              height: 45,
                              width: 45,
                              child: Container(
                                decoration: BoxDecoration(
                                  border: kDefaultAllBorder,
                                  borderRadius: BorderRadius.circular(
                                    kDefaultInnerBorderRadius,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    kDefaultInnerBorderRadius - 2,
                                  ),
                                  child: MaximaAvatar(pd: selectedReport!.targetUserId),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedReport!.targetUsername,
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 19,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  'KYBER USER',
                                  style: const TextStyle(
                                    fontFamily: FontFamily.battlefrontUI,
                                    fontSize: 15,
                                    color: kWhiteColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            KyberButton(
                              text: 'OPEN',
                              icon: const Icon(mt.Icons.play_arrow_rounded),
                              onPressed: () => router.push(
                                '/staff/reports/${selectedReport!.targetUserId}',
                              ),
                            ),
                            //SizedBox(
                            //  width: 100,
                            //  height: 35,
                            //  child: KyberTabBar(
                            //    tabs: [
                            //      Icon(mt.Icons.storage),
                            //      Text('0 GB'),
                            //    ],
                            //    selectedIndex: -1,
                            //  ),
                            //),
                            const SizedBox(
                              width: 200,
                              child: KyberDropdownSelector(
                                items: [],
                                placeholder: 'OPTIONS',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const CardSection(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
