import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TcpClientManager {
  Socket? _socket;
  
  // Stream controller to emit incoming messages from the host
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Connects to the host server via TCP.
  Future<void> connect(String hostIp, int port) async {
    _socket = await Socket.connect(hostIp, port);
    
    // Listen to the server stream, splitting by newline for JSON lines
    _socket!.cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (String data) {
        try {
          final Map<String, dynamic> jsonMsg = jsonDecode(data);
          _messageController.add(jsonMsg);
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
    // Append newline delimiter as per protocol
    final payloadBytes = utf8.encode('$payloadString\n');
    
    try {
      _socket!.add(payloadBytes);
    } catch (e) {
      print('Error sending message to server: $e');
    }
  }

  /// Disconnects from the server.
  Future<void> disconnect() async {
    await _socket?.close();
    _socket?.destroy();
    _socket = null;
  }
  
  void dispose() {
    disconnect();
    _messageController.close();
  }
}
