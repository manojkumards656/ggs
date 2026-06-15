import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'tcp_framing.dart';

/// Manages a single TCP client connection to a game host.
///
/// Why raw TCP over WebSocket: No HTTP server exists on the host device.
/// Raw Dart `Socket` avoids the HTTP upgrade handshake overhead (~50-100ms)
/// and gives us direct control over socket options like TCP_NODELAY.
class TcpClientManager {
  Socket? _socket;
  StreamSubscription? _socketSubscription;

  /// Guard flag and future to prevent connect/disconnect race conditions.
  /// If disconnect() is already in progress, new callers get the same future.
  bool _disconnecting = false;
  Future<void>? _disconnectFuture;

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
    // Clean up any existing connection first.
    // Await any in-progress disconnect to avoid racing with it.
    await disconnect();

    _socket = await Socket.connect(
      hostIp,
      port,
      timeout: const Duration(seconds: 5),
    );
    _socket!.setOption(SocketOption.tcpNoDelay, true);

    // Store the subscription so we can cancel it cleanly in disconnect()
    // without relying on socket.destroy() to implicitly end the stream.
    //
    // Uses LengthPrefixedFrameDecoder instead of utf8.decoder + LineSplitter
    // to correctly handle TCP stream semantics (partial reads, coalesced writes).
    _socketSubscription = _socket!
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

    final payloadBytes = encodeFrame(message);

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
  ///
  /// Uses a [_disconnecting] guard so that concurrent calls (e.g. from
  /// onError/onDone callbacks racing with an explicit disconnect) share
  /// the same future instead of double-closing resources.
  Future<void> disconnect() {
    if (_disconnecting) return _disconnectFuture!;
    _disconnecting = true;
    _disconnectFuture = _performDisconnect();
    return _disconnectFuture!;
  }

  Future<void> _performDisconnect() async {
    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
      await _socket?.close();
      _socket?.destroy();
      _socket = null;
    } finally {
      _disconnecting = false;
      _disconnectFuture = null;
    }
  }

  /// Full cleanup — call when the manager is no longer needed.
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
