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

/// Invalidates all network providers, triggering their [onDispose] callbacks
/// which clean up sockets, timers, and stream controllers.
///
/// Call this when leaving a game session (e.g. returning to the home screen)
/// to ensure network resources are released. The providers will be lazily
/// recreated on next access.
void resetNetworkProviders(WidgetRef ref) {
  ref.invalidate(tcpClientProvider);
  ref.invalidate(tcpServerProvider);
  ref.invalidate(udpDiscoveryProvider);
}

