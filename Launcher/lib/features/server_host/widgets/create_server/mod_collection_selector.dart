import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/core/config/colors.dart';
import 'package:kyber_launcher/core/routing/app_router.dart';
import 'package:kyber_launcher/features/mod_collections/extensions/mod_collection_extension.dart';
import 'package:kyber_launcher/features/mod_collections/widgets/small_mod_card.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/features/mods/widgets/collection_list/collection_entry.dart';
import 'package:kyber_launcher/features/server_host/providers/host_collection_cubit.dart';
import 'package:kyber_launcher/features/server_host/providers/host_search_cubit.dart';
import 'package:kyber_launcher/features/settings/dialogs/chromium_download_dialog.dart';
import 'package:kyber_launcher/gen/fonts.gen.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';
import 'package:kyber_launcher/shared/ui/cards/kyber_container.dart';
import 'package:kyber_launcher/shared/ui/elements/header/kyber_header.dart';

class ModCollectionSelector extends StatefulWidget {
  const ModCollectionSelector({super.key});

  @override
  State<ModCollectionSelector> createState() => _ModCollectionSelectorState();
}

class _ModCollectionSelectorState extends State<ModCollectionSelector> {
  late List<ModCollectionMetaData> collections;

  @override
  void initState() {
    collections = collectionBox.values.toList();
    collections.insert(0, ModCollectionMetaData.noMods());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HostCollectionCubit, HostCollectionState>(
      builder: (context, state) {
        return Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KyberHeader(
                    title: 'Active Mods',
                    sections: [
                      ExpandedHeaderSection(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            state.selectedModCollection.mods.isEmpty
                                ? formatBytes(0, 0)
                                : formatBytes(
                                    state.selectedModCollection
                                        .getLocalMods()
                                        .map((e) => e?.size ?? 0)
                                        .reduce(
                                          (value, element) => value + element,
                                        ),
                                    1,
                                  ),
                          ),
                          const SizedBox(width: 5),
                        ],
                      ),
                    ],
                  ),
                  const CardSection(),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (state.selectedModCollection.localId == 'no-mods' ||
                            state.selectedModCollection.mods.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                'No mods'.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: FontFamily.battlefrontUI,
                                  color: kWhiteColor,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListenableBuilder(
                          listenable: sl.get<ModService>(),
                          builder: (_, _) => ListView.builder(
                            itemBuilder: (context, index) {
                              final mod = state.selectedModCollection
                                  .getLocalMods()[index];
                              return SmallModCard(
                                mod: mod,
                                name: mod == null
                                    ? state.selectedModCollection.mods
                                          .elementAt(index)
                                          .name
                                    : null,
                              );
                            },
                            itemCount: state.selectedModCollection.mods.length,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 2,
              height: double.infinity,
              child: ColoredBox(
                color: decoColor,
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  const KyberHeader(title: 'Collections', sections: []),
                  const CardSection(),
                  Expanded(
                    child: BlocListener<HostSearchCubit, HostSearchState>(
                      listener: (context, state) {
                        var newCollections = collectionBox.values.toList()
                          ..insert(0, ModCollectionMetaData.noMods());
                        newCollections = newCollections
                            .where(
                              (element) => element.title.toLowerCase().contains(
                                state.searchQuery.toLowerCase(),
                              ),
                            )
                            .toList();
                        setState(() {
                          collections = newCollections;
                        });
                      },
                      child: GridView.builder(
                        itemCount: collections.length + 1,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 175,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        padding: const EdgeInsets.all(10),
                        itemBuilder: (context, index) {
                          if (index == collections.length) {
                            return CreateCollectionEntry(
                              onTap: () {
                                router.go('/mods?collection=new');
                              },
                            );
                          }

                          final collection = collections.elementAt(index);
                          return CollectionEntry(
                            key: ValueKey(collection.localId),
                            modCollection: collection,
                            selected:
                                state.selectedModCollection.localId ==
                                collection.localId,
                            onTap: () {
                              context
                                  .read<HostCollectionCubit>()
                                  .selectCollection(collection);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
