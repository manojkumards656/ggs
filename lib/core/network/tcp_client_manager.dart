import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Manages a single TCP client connection to a game host.
///
/// Why raw TCP over WebSocket: No HTTP server exists on the host device.
/// Raw Dart `Socket` avoids the HTTP upgrade handshake overhead (~50-100ms)
/// and gives us direct control over socket options like TCP_NODELAY.
class TcpClientManager {
  Socket? _socket;
  StreamSubscription? _socketSubscription;

  // Broadcast controller so multiple listeners (UI, game logic) can subscribe
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Whether a connection is currently active.
  bool get isConnected => _socket != null;

  /// Connects to the host server via TCP.
  ///
  /// Sets TCP_NODELAY to disable Nagle's algorithm — this prevents the OS
  /// from buffering small packets (up to 200ms delay). Critical for real-time
  /// draw point and chat message delivery over LAN.
  Future<void> connect(String hostIp, int port) async {
    // Clean up any existing connection first
    await disconnect();

    _socket = await Socket.connect(hostIp, port);
    _socket!.setOption(SocketOption.tcpNoDelay, true);

    // Store the subscription so we can cancel it cleanly in disconnect()
    // without relying on socket.destroy() to implicitly end the stream.
    _socketSubscription = _socket!
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (String data) {
        try {
          final Map<String, dynamic> jsonMsg = jsonDecode(data);
          if (!_messageController.isClosed) {
            _messageController.add(jsonMsg);
          }
        } catch (e) {
          print('Error parsing server message: $e');
        }
      },
      onError: (error) {
        print('Socket error: $error');
        disconnect();
      },
      onDone: () {
        print('Disconnected from server.');
        disconnect();
      },
    );
  }

  /// Sends a JSON message to the server.
  void sendMessage(Map<String, dynamic> message) {
    if (_socket == null) {
      print('Cannot send message: Socket is not connected.');
      return;
    }

    final payloadString = jsonEncode(message);
    final payloadBytes = utf8.encode('$payloadString\n');

    try {
      _socket!.add(payloadBytes);
    } catch (e) {
      print('Error sending message to server: $e');
    }
  }

  /// Disconnects from the server, cleaning up all resources.
  ///
  /// Cancels the stream subscription BEFORE closing the socket to
  /// prevent events being added to a closed StreamController.
  Future<void> disconnect() async {
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socket?.close();
    _socket?.destroy();
    _socket = null;
  }

  /// Full cleanup — call when the manager is no longer needed.
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
