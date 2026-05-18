import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/tcp_client_manager.dart';
import '../network/tcp_server_manager.dart';
import '../network/udp_discovery_service.dart';

final tcpClientProvider = Provider<TcpClientManager>((ref) {
  final manager = TcpClientManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final tcpServerProvider = Provider<TcpServerManager>((ref) {
  final manager = TcpServerManager();
  ref.onDispose(() => manager.dispose());
  return manager;
});

final udpDiscoveryProvider = Provider<UdpDiscoveryService>((ref) {
  final service = UdpDiscoveryService();
  ref.onDispose(() => service.dispose());
  return service;
});
