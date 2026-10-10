import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/core/core.dart';
import 'package:kyber_launcher/core/services/hotkey_manager.dart';
import 'package:kyber_launcher/core/services/voip_service.dart';
import 'package:kyber_launcher/features/maxima/models/maxima_game_instance.dart';
import 'package:kyber_launcher/features/session/providers/session_cubit.dart';
import 'package:kyber_launcher/gen/rust/api/maxima.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';

class MaximaInstanceService {
  final Set<MaximaGameInstance> _instances = {};
  final _logger = Logger('instance_service');

  Set<MaximaGameInstance> get instances => _instances;

  Future<void> removeInstance(MaximaGameInstance instance) async {
    await instance.closeStream();
    _instances.removeWhere((e) => e.pid == instance.pid);
    if (sl.isRegistered<MaximaGameInstance>(instance: instance)) {
      sl.unregister<MaximaGameInstance>(instance: instance);
      final context = navigatorKey.currentContext!;
      final stateCubit = context.read<SessionCubit>();
      if (stateCubit.gameJoined) {
        stateCubit.leaveGame();
      }
    }

    _logger.info('Instance ${instance.pid} stopped');

    if (_instances.isEmpty) {
      HotKeyService.unregisterIngameHotKey();
      sl.get<VoipService>().clearDevices();
    }
  }

  void addInstance(MaximaGameInstance instance) {
    if (_instances.any((e) => e.pid == instance.pid)) {
      _logger.warning('Instance ${instance.pid} already exists');
      return;
    }

    _instances.add(instance);
    _logger.info('Instance ${instance.pid} added');
    HotKeyService.registerIngameHotKey();
    lsxGetEventStream(pid: instance.pid).listen(
      (event) => instance.addEvent(event),
      onDone: () => removeInstance(instance),
      onError: (e) => removeInstance(instance),
      cancelOnError: true,
    );
  }
}
