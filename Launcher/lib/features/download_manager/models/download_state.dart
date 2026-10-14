import 'package:background_downloader/background_downloader.dart';
import 'package:collection/collection.dart';
import 'package:kyber_launcher/features/download_manager/services/download_orchestrator.dart';

sealed class DownloadState {
  const DownloadState();
}

class DownloadInitial extends DownloadState {
  const DownloadInitial();
}

class DownloadLoaded extends DownloadState {
  const DownloadLoaded({
    required this.tasks,
    this.progressUpdate,
    this.extractionProgressUpdate,
  });

  final ProgressUpdate? extractionProgressUpdate;
  final List<TaskRecord> tasks;
  final TaskProgressUpdate? progressUpdate;

  TaskRecord? get currentDownload => tasks.firstWhereOrNull(
    (e) => e.status == TaskStatus.running,
  );

  List<TaskRecord> get activeTasks => tasks
      .where(
        (e) => e.status.isNotFinalState && e.status != TaskStatus.paused,
      )
      .toList();

  List<TaskRecord> get pausedTasks => tasks
      .where(
        (e) => e.status == TaskStatus.paused,
      )
      .toList();

  DownloadLoaded copyWith({
    List<TaskRecord>? tasks,
    TaskProgressUpdate? progressUpdate,
    ProgressUpdate? extractionProgressUpdate,
  }) {
    return DownloadLoaded(
      tasks: tasks ?? this.tasks,
      progressUpdate: progressUpdate ?? this.progressUpdate,
      extractionProgressUpdate:
          extractionProgressUpdate ?? this.extractionProgressUpdate,
    );
  }
}
