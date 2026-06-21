import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'tcp_framing.dart';

/// Manages a TCP server for the host device, handling multiple client connections.
///
/// Why raw ServerSocket over a web server framework: Zero dependency overhead.
/// Dart's ServerSocket is extremely lightweight and handles persistent
/// connections natively without needing HTTP abstractions.
class TcpServerManager {
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  // Track subscriptions per client so we can cancel them cleanly
  final Map<Socket, StreamSubscription> _clientSubscriptions = {};

  // Broadcast controller so multiple listeners can subscribe
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// The port the server is bound to, or null if not running.
  int? get serverPort => _serverSocket?.port;

  /// Whether the server is currently running.
  bool get isRunning => _serverSocket != null;

  /// Starts the TCP server on any available port (or specified port).
  /// Returns the port the server bound to.
  ///
  /// Sets TCP_NODELAY on each accepted client socket to eliminate
  /// Nagle's algorithm buffering delay (up to 200ms per small message).
  Future<int> startServer({int port = 0}) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);

    _serverSocket?.listen((Socket client) {
      client.setOption(SocketOption.tcpNoDelay, true);
      _clients.add(client);

      // Store the subscription so we can cancel it individually
      // Uses LengthPrefixedFrameDecoder instead of utf8.decoder + LineSplitter
      // to correctly handle TCP stream semantics (partial reads, coalesced writes).
      final sub = client
          .cast<List<int>>()
          .transform(const LengthPrefixedFrameDecoder())
          .listen(
        (String data) {
          try {
            final Map<String, dynamic> jsonMsg = jsonDecode(data);
            if (!_messageController.isClosed) {
              _messageController.add(jsonMsg);
            }
          } catch (e) {
            print('Error parsing client message: $e');
          }
        },
        onError: (error) {
          print('Client error: $error');
          if (!_messageController.isClosed) {
            _messageController.add({'type': 'client_disconnected'});
          }
          _removeClient(client);
        },
        onDone: () {
          print('Client disconnected.');
          if (!_messageController.isClosed) {
            _messageController.add({'type': 'client_disconnected'});
          }
          _removeClient(client);
        },
      );

      _clientSubscriptions[client] = sub;
    });

    return _serverSocket!.port;
  }

  /// Safely removes a client and cancels its subscription.
  void _removeClient(Socket client) {
    _clientSubscriptions[client]?.cancel();
    _clientSubscriptions.remove(client);
    _clients.remove(client);
    try {
      client.close();
    } catch (_) {}
  }

  /// Sends a JSON message to all connected clients.
  ///
  /// Uses List.from() to iterate over a snapshot of the client list,
  /// avoiding ConcurrentModificationException if a client disconnects
  /// mid-broadcast (the onError/onDone callbacks modify _clients).
  /// H3 note: _removeClient() in the catch block is safe because we iterate
  /// over the snapshot copy, not the live _clients list.
  void broadcastMessage(Map<String, dynamic> message) {
    final payloadBytes = encodeFrame(message);

    for (final client in List.from(_clients)) {
      try {
        client.add(payloadBytes);
      } catch (e) {
        print('Error broadcasting to client: $e');
        _removeClient(client);
      }
    }
  }

  /// Stop the server and disconnect all clients.
  ///
  /// Cancels all subscriptions BEFORE destroying sockets to prevent
  /// events firing on closed controllers.
  Future<void> stopServer() async {
    // Cancel all client subscriptions first
    for (final sub in _clientSubscriptions.values) {
      await sub.cancel();
    }
    _clientSubscriptions.clear();

    for (final client in _clients) {
      client.destroy();
    }
    _clients.clear();

    await _serverSocket?.close();
    _serverSocket = null;
  }

  /// Full cleanup — call when the manager is no longer needed.
  ///
  /// Awaits [stopServer] to ensure all client subscriptions are cancelled
  /// before closing the message controller.
  Future<void> dispose() async {
    await stopServer();
    _messageController.close();
  }
}
