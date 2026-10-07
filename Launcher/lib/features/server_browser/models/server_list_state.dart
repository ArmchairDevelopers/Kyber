import 'package:kyber_launcher/features/server_browser/models/server_entry.dart';
import 'package:kyber_launcher/features/server_browser/models/server_filter.dart';

class ServerListState {
  const ServerListState({
    this.pages = 1,
    this.page = 1,
  });

  final int? page;
  final int? pages;
}

class ServerListInitial extends ServerListState {
  const ServerListInitial();
}

class ServerListLoading extends ServerListState {
  const ServerListLoading({this.page, this.pages, this.filter});

  final ServerFilter? filter;
  final int? page;
  final int? pages;
}

class ServerListLoaded extends ServerListState {
  const ServerListLoaded({
    required this.servers,
    required this.page,
    required this.pages,
    required this.filter,
  });

  final ServerFilter filter;

  final List<ServerEntry> servers;
  final int page;
  final int pages;
}

class ServerListError extends ServerListState {
  const ServerListError(this.message);

  final String message;
}
