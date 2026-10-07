import 'package:fixnum/fixnum.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_collection/kyber_collection.dart';
import 'package:kyber_launcher/features/mods/constants/categories.dart';
import 'package:kyber_launcher/features/mods/extensions/frosty_collection_extension.dart';
import 'package:kyber_launcher/features/mods/services/mod_service.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:kyber_launcher/main.dart';

class ModCollectionCubit extends Cubit<ModCollectionState> {
  ModCollectionCubit()
    : super(
        ModCollectionState(
          selectedIndex: collectionBox.isEmpty ? null : 0,
        ),
      );

  void setSelectedIndex(int? index, [ModCollectionPageState? state]) =>
      emit(ModCollectionState(selectedIndex: index, pageState: state));

  void edit() => emit(
    ModCollectionState(
      selectedIndex: state.selectedIndex,
      pageState: ModCollectionPageState.edit,
    ),
  );

  void create() =>
      emit(ModCollectionState(pageState: ModCollectionPageState.create));

  void clearPageState([bool delete = false]) {
    emit(
      ModCollectionState(
        selectedIndex: collectionBox.isEmpty
            ? null
            : delete
            ? 0
            : state.selectedIndex,
      ),
    );
  }

  void clearSelectedIndex() => emit(ModCollectionState());

  ModCollectionMetaData? getCollection() => state.selectedIndex != null
      ? collectionBox.getAt(state.selectedIndex!)
      : null;
}

class ModCollectionState {
  ModCollectionState({this.selectedIndex, this.pageState});

  ModCollectionPageState? pageState;
  int? selectedIndex;
}

enum ModCollectionPageState {
  edit,
  create,
}
