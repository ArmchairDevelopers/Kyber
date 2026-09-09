import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber_launcher/features/download_manager/models/download_request.dart';
import 'package:kyber_launcher/features/download_manager/models/download_state.dart';
import 'package:kyber_launcher/features/download_manager/repositories/download_repository.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';
import 'package:kyber_launcher/injection_container.dart';

class DownloadCubit extends Cubit<DownloadState> {
  DownloadCubit({
    DownloadOrchestrator? orchestrator,
    DownloadRepository? repository,
  }) : _orchestrator = orchestrator,
       _repository = repository ?? const DownloadRepository(),
       super(const DownloadInitial()) {
    _initialize();
  }

  final DownloadOrchestrator? _orchestrator;
  final DownloadRepository _repository;
  StreamSubscription<TaskProgressUpdate>? _progressSubscription;
  StreamSubscription<TaskStatusUpdate>? _statusSubscription;
  StreamSubscription<ProgressUpdate>? _extractionProgressSubscription;

  final _callbackTasks = <String, TaskRecord>{};

  Future<void> _initialize() async {
    await sl.isReady<DownloadOrchestrator>();
    final orchestrator = _orchestrator ?? sl.get<DownloadOrchestrator>();

    _progressSubscription = orchestrator.progressUpdates.listen(
      _onProgressUpdate,
    );
    _statusSubscription = orchestrator.statusUpdates.listen(
      _onStatusUpdate,
    );
    _extractionProgressSubscription = orchestrator.extractionProgressUpdates
        .listen(_onExtractionProgressUpdate);

    await _loadTasks();
  }

  void _onStatusUpdate(TaskStatusUpdate update) {
    if (update.task is CallbackTask) {
      if (update.status.isFinalState) {
        _callbackTasks.remove(update.task.taskId);
      } else {
        _callbackTasks[update.task.taskId] = TaskRecord(
          update.task,
          update.status,
          0,
          -1,
        );
      }
    }
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await _repository.getActiveTasks();

    tasks.addAll(_callbackTasks.values);

    tasks.sort((a, b) {
      if (a.status == TaskStatus.running) {
        return -1;
      } else if (b.status == TaskStatus.running) {
        return 1;
      }
      return b.task.priority.compareTo(a.task.priority);
    });

    if (state is DownloadLoaded) {
      final state = this.state as DownloadLoaded;
      return emit(state.copyWith(tasks: tasks));
    }

    emit(DownloadLoaded(tasks: tasks));
  }

  void _onProgressUpdate(TaskProgressUpdate update) {
    if (update.task is CallbackTask) {
      _callbackTasks[update.task.taskId] = TaskRecord(
        update.task,
        TaskStatus.running,
        update.progress,
        update.expectedFileSize,
      );
    }

    if (state is DownloadLoaded) {
      final currentState = state as DownloadLoaded;
      emit(currentState.copyWith(progressUpdate: update));
    }
  }

  void _onExtractionProgressUpdate(ProgressUpdate update) {
    if (state is! DownloadLoaded) return;
    emit(
      DownloadLoaded(
        tasks: (state as DownloadLoaded).tasks,
        progressUpdate: (state as DownloadLoaded).progressUpdate,
        extractionProgressUpdate: update,
      ),
    );
  }

  Future<void> enqueueDownload(DownloadRequest request) async {
    await sl.isReady<DownloadOrchestrator>();
    final orchestrator = _orchestrator ?? sl.get<DownloadOrchestrator>();
    await orchestrator.enqueueDownload(request);
  }

  Future<void> pauseDownload(String taskId) async {
    await sl.isReady<DownloadOrchestrator>();
    final orchestrator = _orchestrator ?? sl.get<DownloadOrchestrator>();
    await orchestrator.pauseDownload(taskId);
  }

  Future<void> resumeDownload(String taskId) async {
    await sl.isReady<DownloadOrchestrator>();
    final orchestrator = _orchestrator ?? sl.get<DownloadOrchestrator>();
    await orchestrator.resumeDownload(taskId);
  }

  Future<void> cancelDownload(String taskId) async {
    await sl.isReady<DownloadOrchestrator>();
    final orchestrator = _orchestrator ?? sl.get<DownloadOrchestrator>();
    await orchestrator.cancelDownload(taskId);
  }

  @override
  Future<void> close() {
    _progressSubscription?.cancel();
    _statusSubscription?.cancel();
    _extractionProgressSubscription?.cancel();
    return super.close();
  }
}
