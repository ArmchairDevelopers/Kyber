import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/features/server_browser/models/server_list_state.dart';
import 'package:kyber_launcher/features/server_browser/providers/server_list_cubit.dart';
import 'package:kyber_launcher/features/server_browser/widgets/table_server_list.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/shared/ui/ui.dart';

class ServerListWidget extends StatefulWidget {
  const ServerListWidget({super.key});

  @override
  State<ServerListWidget> createState() => _ServerListState();
}

class _ServerListState extends State<ServerListWidget> {
  Timer? _refreshTimer;

  @override
  void initState() {
    Timer.run(context.read<ServerListCubit>().checkUpdate);
    super.initState();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServerListCubit, ServerListState>(
      builder: (context, state) {
        if (state is ServerListLoading) {
          return const Column(
            children: [
              Expanded(child: Center(child: ProgressBar())),
            ],
          );
        }

        if (state is ServerListLoaded) {
          return const RepaintBoundary(child: TableServerList());
        }

        if (state is ServerListError) {
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: CustomBorder(
              clipper: KyberEventsCustomBorderClipper(),
              painter: KyberEventsCustomBorderPainter(),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.message,
                    style: FluentTheme.of(context).typography.subtitle
                        ?.copyWith(fontFamily: FontFamily.battlefrontUI),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox();
      },
    );
  }
}
