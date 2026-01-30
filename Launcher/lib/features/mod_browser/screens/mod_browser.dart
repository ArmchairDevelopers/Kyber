import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_browser_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/providers/mod_search_cubit.dart';
import 'package:kyber_launcher/features/mod_browser/widgets/nmb_mod_tile.dart';
import 'package:kyber_launcher/features/nexusmods/dialogs/nexusmods_login.dart';
import 'package:kyber_launcher/features/nexusmods/services/nexusmods_service.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/gen/l10n/app_localizations.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/shared/ui/buttons/button.dart';
import 'package:kyber_launcher/shared/ui/dialog/kyber_dialog.dart';
import 'package:nexus_gql/nexus_gql.dart';

class CategorizedModList extends StatefulWidget {
  const CategorizedModList({super.key});

  @override
  State<CategorizedModList> createState() => _CategorizedModListState();
}

class _CategorizedModListState extends State<CategorizedModList> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final currentFont = isEn ? FontFamily.battlefrontUI : 'BattlefrontGlobal';

    return FutureBuilder(
      future: sl.isReady<NexusModsService>(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error!.toString()));
        }

        if (!snapshot.hasData) {
          return const Center(child: ProgressRing());
        }

        if (sl.get<NexusModsService>().apiToken == null) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 20,
            children: [
              Text(l10n.signInNexusPrompt),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KyberButton(
                    text: l10n.login,
                    onPressed: () async {
                      await showKyberDialog(
                        context: context,
                        builder: (_) => const NexusmodsLogin(),
                        routeSettings: const RouteSettings(
                          name: 'nexusmods_login',
                        ),
                      );
                      context.read<ModBrowserCubit>().loadPage();
                      setState(() => null);
                    },
                  ),
                ],
              ),
            ],
          );
        }

        return BlocBuilder<ModSearchCubit, SearchState>(
          builder: (context, searchState) {
            if (searchState is SearchLoading) {
              return const Center(child: ProgressRing());
            }

            if (searchState is SearchLoaded) {
              if (searchState.results.isEmpty) {
                return Center(
                  child: Text(
                    l10n.noModsFound.toUpperCase(),
                    style: TextStyle(
                      fontFamily: currentFont,
                      fontSize: 17,
                    ),
                  ),
                );
              }

              return GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 375,
                  childAspectRatio: 16 / 9,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                ),
                padding: const .symmetric(
                  vertical: 20,
                  horizontal: 20,
                ),
                itemBuilder: (context, index) {
                  final mod = searchState.results[index];
                  return NMBModTile(
                    key: Key(mod.id),
                    mod: .new(
                      name: mod.name,
                      downloads: mod.downloads,
                      id: mod.id,
                      modId: mod.modId,
                      summary: mod.summary,
                      uid: mod.uid,
                      uploader: .new(
                        name: mod.uploader.name,
                        avatar: mod.uploader.avatar,
                        //recognizedAuthor: mod.uploader.recognizedAuthor,
                        // TODO: Handle recognizedAuthor field properly
                        // recognizedAuthor: false,
                      ),
                      author: mod.author,
                      fileSize: mod.fileSize,
                      pictureUrl: mod.pictureUrl,
                      thumbnailUrl: mod.thumbnailUrl,
                    ),
                  );
                },
                itemCount: searchState.results.length,
              );
            }

            if (searchState is SearchError) {
              return Center(child: Text(searchState.error));
            }

            return BlocBuilder<ModBrowserCubit, ModBrowserState>(
              builder: (context, state) {
                if (state is ModBrowserLoading) {
                  return const Center(child: ProgressRing());
                }

                if (state is ModBrowserError) {
                  return Center(child: Text(state.error));
                }

                state as ModBrowserLoaded;

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 375,
                    childAspectRatio: 16 / 9,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 20,
                  ),
                  itemBuilder: (context, index) {
                    final mod = state.mods[index];
                    return NMBModTile(
                      key: Key(mod.id),
                      mod: mod,
                    );
                  },
                  itemCount: state.mods.length,
                );
              },
            );
          },
        );
      },
    );
  }
}