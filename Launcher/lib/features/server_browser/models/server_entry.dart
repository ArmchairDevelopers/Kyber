import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';

sealed class ServerEntry {
  Server get serverInfo;
  int get totalPlayerCount;
}

class SingleServer extends ServerEntry {
  SingleServer({required this.server});

  final Server server;

  @override
  Server get serverInfo => server;

  @override
  int get totalPlayerCount => server.playerCount;
}

class GroupedServer extends ServerEntry {
  GroupedServer({required this.group});

  final ServerGroup group;

  @override
  Server get serverInfo => group.serverInfo;

  @override
  int get totalPlayerCount => group.totalPlayerCount;
}
