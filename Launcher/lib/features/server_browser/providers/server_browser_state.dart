part of 'server_browser_cubit.dart';

class ServerBrowserState {
  const ServerBrowserState({
    this.selectedServer,
    this.joiningServer,
  });

  final ServerEntry? selectedServer;
  final Server? joiningServer;

  ServerBrowserState copyWith({
    ServerEntry? selectedServer,
    Server? joiningServer,
  }) {
    return ServerBrowserState(
      selectedServer: selectedServer ?? this.selectedServer,
      joiningServer: joiningServer ?? this.joiningServer,
    );
  }
}
