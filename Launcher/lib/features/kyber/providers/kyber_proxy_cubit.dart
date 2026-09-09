import 'dart:async';

import 'package:async/async.dart';
import 'package:collection/collection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kyber/kyber.dart';
import 'package:kyber_launcher/core/services/app_settings.dart';
import 'package:kyber_launcher/injection_container.dart';
import 'package:logging/logging.dart';
import 'package:pool/pool.dart';
import 'package:web_socket_channel/io.dart';

const _kPingTimeout = Duration(seconds: 2);
const _kConnectTimeout = Duration(seconds: 10);
const _kSamples = 10;
const _kMaxConcurrentHosts = 2;

class KyberProxyCubit extends Cubit<KyberProxyState> {
  KyberProxyCubit() : super(KyberProxyState(proxies: [])) {
    loadProxies();
  }

  final _logger = Logger('proxy_cubit');

  Future<void>? _ready;
  bool _loading = true;

  bool get isLoading => _loading;

  Future<void> ensureReady() => _ready ?? Future<void>.value();

  void selectProxy(String proxyId) {
    Preferences.general.proxy = proxyId;
    emit(state.copyWith(selectedProxy: proxyId));
  }

  Future<void> loadProxies() {
    return _ready = _loadProxies().whenComplete(() => _loading = false);
  }

  Future<void> _loadProxies() async {
    try {
      final resp = await sl.get<KyberGRPCService>().proxyClient.getList(
        Empty(),
      );
      final proxyList = List<ProxyInfo>.from(resp.proxies);

      if (proxyList.isEmpty) {
        _logger.warning('No proxies returned');
        emit(state.copyWith(proxies: [], selectedProxy: ''));
        return;
      }

      final pool = Pool(_kMaxConcurrentHosts);

      final results = await Future.wait(
        proxyList.map(
          (p) async => pool.withResource(() async {
            try {
              final ping = await _measurePing(p.ip);
              return (info: p, ping: ping);
            } catch (e, s) {
              _logger.warning('Ping failed for ${p.ip}', e, s);
              return (info: p, ping: null);
            }
          }),
        ),
      );
      await pool.close();

      final ok = results.where((r) => r.ping != null).toList();
      if (ok.isEmpty) {
        _logger.severe('All proxy pings failed');
        return;
      }

      if (ok.length < results.length) {
        _logger.warning(
          'Failed to connect to ${results.length - ok.length} proxies.',
        );
      }

      final proxies = ok
          .where((a) => a.ping != null)
          .toList()
          .sorted((a, b) => a.ping!.compareTo(b.ping!));
      final best = proxies.first;
      final autoInfo = ProxyInfo(
        name: 'Auto',
        ip: best.info.ip,
        flag: '',
        id: 'auto',
      );

      final entries =
          proxies.map((r) => KyberProxy(ping: r.ping!, proxy: r.info)).toList()
            ..insert(0, KyberProxy(ping: best.ping!, proxy: autoInfo));

      final validIds = {
        ...proxyList.map((e) => e.id),
        'auto',
      };

      final selected = _validatedSelection(validIds, Preferences.general.proxy);
      emit(state.copyWith(proxies: entries, selectedProxy: selected));

      if (Preferences.general.proxy.isEmpty) {
        Preferences.general.proxy = 'auto';
        emit(state.copyWith(selectedProxy: 'auto'));
      }
    } catch (e, s) {
      _logger.severe('Failed to load proxies', e, s);
      emit(state.copyWith(proxies: [], selectedProxy: ''));
    }
  }

  Future<int?> _measurePing(String host) async {
    IOWebSocketChannel? channel;
    StreamQueue? queue;

    try {
      channel = IOWebSocketChannel.connect(Uri.parse('wss://$host/ping'));
      await channel.ready.timeout(_kConnectTimeout);

      queue = StreamQueue(channel.stream.asBroadcastStream());

      channel.sink.add('PING');
      await queue.next.timeout(_kPingTimeout);

      final samples = <int>[];
      final sw = Stopwatch();

      for (var i = 0; i < _kSamples; i++) {
        sw
          ..reset()
          ..start();
        channel.sink.add('PING');

        await queue.next.timeout(_kPingTimeout);

        sw.stop();
        samples.add(sw.elapsedMilliseconds);
      }

      samples.sort();

      return samples[samples.length >> 1];
    } catch (e) {
      _logger.warning('Ping failed for $host: $e');
      return null;
    } finally {
      try {
        await queue?.cancel();
      } catch (_) {}
      try {
        await channel?.sink.close().timeout(_kPingTimeout);
      } catch (_) {}
    }
  }

  String _validatedSelection(Iterable<String> validIds, String current) {
    if (current.isEmpty) return '';

    final ok = validIds.any((id) => id == current);
    if (!ok) {
      _logger.warning(
        'Selected proxy "$current" not available. Clearing selection.',
      );
      Preferences.general.proxy = '';
      return '';
    }

    return current;
  }
}

class KyberProxy {
  KyberProxy({required this.ping, required this.proxy});

  int ping;
  ProxyInfo proxy;
}

class KyberProxyState {
  KyberProxyState({this.proxies = const [], this.selectedProxy = ''});

  List<KyberProxy> proxies;
  String selectedProxy;

  KyberProxyState copyWith({List<KyberProxy>? proxies, String? selectedProxy}) {
    return KyberProxyState(
      proxies: proxies ?? this.proxies,
      selectedProxy: selectedProxy ?? this.selectedProxy,
    );
  }
}
