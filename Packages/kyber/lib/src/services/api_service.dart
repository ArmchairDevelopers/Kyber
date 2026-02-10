import 'package:grpc/grpc.dart';
import 'package:kyber/gen/Proto/kyber_api.pbgrpc.dart';
import 'package:uuid/uuid.dart';

const _kServicePort = 443;

class KyberGRPCService {
  factory KyberGRPCService.fromDefaults() => KyberGRPCService(
        'api-rpc.prod.kyber.gg',
        _kServicePort,
        httpHostname: 'api.stage.kyber.gg',
      );

  KyberGRPCService(this.host, this.port, {required this.httpHostname, bool isInsecure = false}) {
    _channel = ClientChannel(
      host,
      port: port,
      options: isInsecure ? const ChannelOptions(credentials: ChannelCredentials.insecure()) : const ChannelOptions(),
    );

    _setChannels();
  }

  factory KyberGRPCService.local() => KyberGRPCService(
        '0.0.0.0',
        9027,
        isInsecure: true,
        httpHostname: 'localhost',
      );

  factory KyberGRPCService.fromEnv(String env) => KyberGRPCService(
        'api-rpc.$env.kyber.gg',
        _kServicePort,
        httpHostname: 'api.$env.kyber.gg',
      );

  final String httpHostname;

  void _setChannels() {
    final id = const Uuid().v4();
    final callOptions = CallOptions(
      metadata: {
        'x-session-id': id,
        'x-kv2-dsid': '53ff61a4-b751-40f6-a0c8-31d362f29936',
        'authorization': _token ?? '',
      },
    );

    authClient = AuthenticationClient(_channel, options: callOptions);
    statsClient = StatisticsClient(_channel, options: callOptions);
    clientServerClient = ClientServerClient(_channel, options: callOptions);
    serverBrowserClient = ServerBrowserClient(_channel, options: callOptions);
    serverManagementClient = ServerManagementClient(_channel, options: callOptions);
    proxyClient = ProxyClient(_channel, options: callOptions);
    launcherClient = LauncherClient(_channel, options: callOptions);
    reportServiceClient = ReportServiceClient(_channel, options: callOptions);
    partyServiceClient = PartyClient(_channel, options: callOptions);
  }

  late ClientChannel _channel;
  late ServerBrowserClient serverBrowserClient;
  late AuthenticationClient authClient;
  late StatisticsClient statsClient;
  late ClientServerClient clientServerClient;
  late ServerManagementClient serverManagementClient;
  late ProxyClient proxyClient;
  late LauncherClient launcherClient;
  late ReportServiceClient reportServiceClient;
  late PartyClient partyServiceClient;

  final String host;
  final int port;

  String? _token;

  set token(String? value) {
    _token = value;
    _setChannels();
  }

  String? get token => _token;

  Future<LoginResponse> login(String token) async {
    final response = await authClient.login(LoginRequest(token: token));
    _token = response.token;

    _setChannels();

    return response;
  }

  Future<String> getAuthToken(String token, {bool force = false}) async {
    if (_token != null && !force) {
      return _token!;
    }

    final response = await authClient.login(LoginRequest(token: token));
    _token = response.token;

    return _token!;
  }

  void dispose() {
    _channel.shutdown();
  }
}
