import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as mt;
import 'package:grpc/grpc.dart';
import 'package:intl/intl.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/services/notification_service.dart';
import 'package:kyber_launcher/core/utils/transparent_image.dart';
import 'package:kyber_launcher/features/mod_browser/screens/mod_details.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/mod_details/mod_images.dart';
import 'package:kyber_launcher/features/reports/dialogs/report_punishment_dialog.dart';
import 'package:kyber_launcher/gen/assets.gen.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/buttons/custom_icon_button.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:kyber_launcher/shared/ui/elements/kyber_tab_bar.dart';
import 'package:kyber_launcher/shared/ui/utils/background_blur.dart';
import 'package:kyber_launcher/shared/ui/utils/button_builder.dart';
import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReportView extends StatefulWidget {
  const ReportView({required this.playerId, super.key});

  final String playerId;

  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  int? selectedImage;
  int? selectedIndex;
  int selectedPage = 0;
  String? playerName;
  List<Report> reports = [];
  List<Punishment> punishments = [];

  @override
  void initState() {
    Timer.run(() async {
      try {
        final resp = await sl
            .get<KyberGRPCService>()
            .reportServiceClient
            .getUserReports(
              GetReportRequest(
                playerId: widget.playerId,
                state: ReportState.OPEN,
              ),
            );

        setState(() {
          reports = resp.reports;
          playerName = resp.playerName;
          selectedIndex = reports.isNotEmpty ? 0 : null;
        });
      } on GrpcError catch (e) {
        sl
            .get<KyberGRPCService>()
            .reportServiceClient
            .getUserReports(
              GetReportRequest(
                playerId: widget.playerId,
                state: ReportState.CLOSED,
              ),
            )
            .then(
              (e) => setState(() {
                punishments = e.punishments.isNotEmpty ? e.punishments : [];
                reports = e.reports;
                playerName = e.playerName;
                selectedIndex = reports.isNotEmpty ? 0 : null;
              }),
            );
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    if (playerName == null) {
      return const Center(
        child: ProgressRing(),
      );
    }

    final report = reports.isNotEmpty ? reports[selectedIndex ?? 0] : null;
    if (report == null) {
      return Center(
        child: Text(l10n.noReportsAvailable),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: KyberCard(
            padding: EdgeInsets.zero,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 19,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        color: Colors.black,
                        height: 100,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    stops: const [0.3, 1],
                                    colors: [
                                      Colors.transparent.withOpacity(.2),
                                      Colors.black,
                                    ],
                                  ).createShader(
                                    Rect.fromLTRB(
                                      0,
                                      0,
                                      rect.width,
                                      rect.height,
                                    ),
                                  );
                                },
                                blendMode: .dstIn,
                                child: Assets.images.kyberNoImage.image(
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    stops: const [0.3, 1],
                                    colors: [
                                      Colors.transparent.withOpacity(.2),
                                      Colors.black,
                                    ],
                                  ).createShader(
                                    Rect.fromLTRB(
                                      0,
                                      0,
                                      rect.width,
                                      rect.height,
                                    ),
                                  );
                                },
                                blendMode: .dstIn,
                                child: CachedNetworkImage(
                                  imageUrl: '',
                                  fit: .cover,
                                  fadeInDuration: kDefaultDuration,
                                  errorWidget: (context, url, error) =>
                                      Image.memory(kTransparentImage),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Padding(
                                padding: const .all(15),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: .center,
                                        crossAxisAlignment: .start,
                                        children: [
                                          AutoSizeText(
                                            report.reportedPlayerName,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontFamily: currentFont,
                                              height: 1,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          RichText(
                                            text: TextSpan(
                                              style: TextStyle(
                                                color: kGrayColor,
                                                fontFamily: currentFont,
                                                fontSize: 15,
                                              ),
                                              children: [
                                                TextSpan(
                                                  text: l10n.reportedBy,
                                                ),
                                                TextSpan(
                                                  text: report.reporterName,
                                                  style: TextStyle(
                                                    color: kWhiteColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: currentFont,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                TextSpan(text: l10n.forLabel),
                                                TextSpan(
                                                  text: report.reason.name,
                                                  style: TextStyle(
                                                    color: kWhiteColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: currentFont,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                TextSpan(text: l10n.onLabel),
                                                TextSpan(
                                                  text: DateFormat.yMd().add_jm().format(
                                                    DateTime.fromMillisecondsSinceEpoch(
                                                      report.createdAt.toInt() * 1000,
                                                    ).toLocal(),
                                                  ),
                                                  style: TextStyle(
                                                    color: kWhiteColor,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: currentFont,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const ContainerSeparator(),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: .start,
                          children: [
                            if (report.s3EvidenceIds.isNotEmpty) ...[
                              Expanded(
                                child: SuperListView.builder(
                                  itemCount: report.s3EvidenceIds.length,
                                  padding: const .symmetric(
                                    vertical: 15,
                                    horizontal: 15,
                                  ),
                                  itemBuilder: (context, index) {
                                    final item = report.s3EvidenceIds[index];

                                    final baseUrl =
                                        'https://report-evidence.${sl.get<KyberGRPCService>().host.contains('prod') ? 'prod' : 'stage'}.kyber.gg';

                                    return Column(
                                      crossAxisAlignment: .stretch,
                                      children: [
                                        if (index != 0)
                                          Padding(
                                            padding: const .symmetric(
                                              vertical: 10,
                                            ),
                                            child: CustomPaint(
                                              painter: DashedLinePainter(),
                                              child: const SizedBox(height: 2),
                                            ),
                                          ),
                                        AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: ButtonBuilder(
                                            onClick: () {
                                              setState(
                                                () => selectedImage = index,
                                              );
                                            },
                                            builder: (context, hovered) {
                                              return AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 150,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: hovered
                                                        ? kActiveColor
                                                        : decoColor,
                                                    width: 2,
                                                  ),
                                                  borderRadius: .circular(6),
                                                ),
                                                child: ClipRRect(
                                                  borderRadius: .circular(4),
                                                  child: CachedNetworkImage(
                                                    imageUrl: '$baseUrl/$item',
                                                    fit: .cover,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const ContainerSeparatorH(),
                            ],
                            Expanded(
                              flex: 2,
                              child: Builder(
                                builder: (context) {
                                  if (selectedImage != null) {
                                    final item =
                                        report.s3EvidenceIds[selectedImage!];

                                    final baseUrl =
                                        'https://report-evidence.${sl.get<KyberGRPCService>().host.contains('prod') ? 'prod' : 'stage'}.kyber.gg';

                                    return Padding(
                                      padding: const .all(15),
                                      child: Column(
                                        spacing: 15,
                                        children: [
                                          Row(
                                            spacing: 15,
                                            children: [
                                              KyberIconButton(
                                                iconData:
                                                    mt.Icons.arrow_back_rounded,
                                                onPressed: () => setState(
                                                  () => selectedImage = null,
                                                ),
                                              ),
                                              KyberIconButton(
                                                iconData:
                                                    mt.Icons.open_in_browser,
                                                onPressed: () =>
                                                    launchUrlString(
                                                      '$baseUrl/$item',
                                                    ),
                                              ),
                                            ],
                                          ),
                                          InteractiveViewer(
                                            minScale: 0.5,
                                            maxScale: 5.0,
                                            child: CachedNetworkImage(
                                              imageUrl: '$baseUrl/$item',
                                              fit: .fitWidth,
                                              placeholder: (context, url) =>
                                                  const Center(
                                                    child: ProgressRing(),
                                                  ),
                                              fadeOutDuration: .zero,
                                              fadeInDuration: .zero,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: .start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: InfoLabel(
                                            label: l10n.descriptionLabel,
                                            child: Text(
                                              report.description,
                                              style: TextStyle(
                                                color: kWhiteColor,
                                                fontFamily: currentFont,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const CardSection(),
                                        Padding(
                                          padding: const .all(15),
                                          child: InfoLabel(
                                            label: l10n.evidenceCountLabel(report.evidenceLinks.length),
                                            child: ListView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount:
                                                  report.evidenceLinks.length,
                                              itemBuilder: (context, index) {
                                                final evidence =
                                                    report.evidenceLinks[index];
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: MouseRegion(
                                                    cursor: SystemMouseCursors
                                                        .click,
                                                    child: GestureDetector(
                                                      onTap: () =>
                                                          launchUrlString(
                                                            evidence,
                                                          ),
                                                      child: Text(
                                                        evidence,
                                                        style: TextStyle(
                                                          color: kActiveColor,
                                                          fontFamily: currentFont,
                                                          fontSize: 16,
                                                          decoration:
                                                              TextDecoration
                                                                  .underline,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: 375,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kDefaultOuterBorderRadius),
              border: Border.all(
                color: decoColor,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                kDefaultOuterBorderRadius - 2,
              ),
              child: BackgroundBlur(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 70,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14.5,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.reportViewTitle,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontFamily: currentFont,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    l10n.viewReportsAndEvidence,
                                    style: TextStyle(
                                      color: kWhiteColor,
                                      fontFamily: currentFont,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              height: 32,
                              width: 32,
                              child: KyberTabBar(
                                onChanged: (index) =>
                                    Navigator.of(context).pop(),
                                selectedIndex: -1,
                                tabs: const [
                                  Icon(mt.Icons.close),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      height: 2,
                      color: decoColor,
                    ),
                    Container(
                      height: 110,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: KyberTabBar(
                                    tabs: [
                                      Text(l10n.reportsTab),
                                      Text(l10n.punishmentsTab),
                                    ],
                                    onChanged: (value) => setState(
                                      () => selectedPage = value,
                                    ),
                                    selectedIndex: selectedPage,
                                  ),
                                ),
                                const SizedBox(width: 20),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            child: Row(
                              spacing: 5,
                              children: [
                                KyberIconButton(
                                  initialColor: kButtonBorder,
                                  iconData: mt.Icons.delete_forever,
                                  onPressed: () {
                                    final request = RejectReportRequest(
                                      reportId: report.id,
                                    );
                                    sl
                                        .get<KyberGRPCService>()
                                        .reportServiceClient
                                        .rejectReport(request)
                                        .then((_) {
                                          setState(() {
                                            reports.removeAt(selectedIndex!);
                                            selectedImage = null;
                                            selectedIndex = reports.isNotEmpty
                                                ? 0
                                                : null;
                                          });
                                          NotificationService.info(
                                            message: l10n.reportRejected,
                                          );
                                        });
                                  },
                                ),
                                IntrinsicWidth(
                                  child: KyberButton(
                                    text: l10n.takeAction,
                                    onPressed: () {
                                      showKyberDialog(
                                        context: context,
                                        builder: (context) =>
                                            ReportPunishmentDialog(
                                              target: ServerPlayer(
                                                name: report.reportedPlayerName,
                                                id: report.reportedPlayerId,
                                              ),
                                              initialReason: report.reason,
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selectedPage == 0)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const ContainerSeparator(),
                              ColoredBox(
                                color: Colors.black.withOpacity(.4),
                                child: SuperListView.separated(
                                  itemBuilder: (context, index) {
                                    if (index == reports.length) {
                                      return const SizedBox.shrink();
                                    }

                                    final report = reports[index];
                                    return ButtonBuilder(
                                      onClick: () {
                                        setState(() {
                                          selectedImage = null;
                                          selectedIndex = index;
                                        });
                                      },
                                      builder: (context, hovered) {
                                        return AbsorbPointer(
                                          child: AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 150,
                                            ),
                                            style: TextStyle(
                                              fontFamily: currentFont,
                                              color:
                                                  hovered ||
                                                      index == selectedIndex
                                                  ? kActiveColor
                                                  : kWhiteColor,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 12,
                                                  ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    FluentIcons.shield_alert,
                                                    color: kWhiteColor,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: AutoSizeText(
                                                      l10n.reportedByPlayer(report.reportedPlayerName),
                                                      maxLines: 1,
                                                      minFontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  separatorBuilder: (context, index) =>
                                      const ContainerSeparator(),
                                  padding: EdgeInsets.zero,
                                  itemCount: reports.length + 1,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (selectedPage == 1)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const ContainerSeparator(),
                              ColoredBox(
                                color: Colors.black.withOpacity(.4),
                                child: SuperListView.separated(
                                  itemBuilder: (context, index) {
                                    if (index == punishments.length) {
                                      return const SizedBox.shrink();
                                    }

                                    final punishment = punishments[index];
                                    return AbsorbPointer(
                                      child: AnimatedDefaultTextStyle(
                                        duration: const Duration(
                                          milliseconds: 150,
                                        ),
                                        style: TextStyle(
                                          fontFamily: currentFont,
                                          color: kWhiteColor,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              String expiresText;

                                              final expiresAt =
                                                  DateTime.fromMillisecondsSinceEpoch(
                                                    punishment.expiresAt
                                                        .toInt(),
                                                  ).toLocal();
                                              final issuedAt =
                                                  DateTime.fromMillisecondsSinceEpoch(
                                                    punishment.issuedAt.toInt(),
                                                  ).toLocal();

                                              if (punishment.expiresAt > 0) {
                                                expiresText = l10n.daysDuration(expiresAt.difference(issuedAt).inDays);
                                              } else {
                                                expiresText = l10n.permanent;
                                              }

                                              return Column(
                                                spacing: 5,
                                                crossAxisAlignment: .start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        FluentIcons
                                                            .shield_alert,
                                                        color: kWhiteColor,
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: AutoSizeText(
                                                          l10n.bannedByModerator(punishment.moderator.name),
                                                          maxLines: 1,
                                                          minFontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    l10n.durationLabel(expiresText),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    l10n.issuedLabel(DateFormat.yMd().add_jm().format(issuedAt)),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  separatorBuilder: (context, index) =>
                                      const ContainerSeparator(),
                                  padding: EdgeInsets.zero,
                                  itemCount: punishments.length + 1,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}