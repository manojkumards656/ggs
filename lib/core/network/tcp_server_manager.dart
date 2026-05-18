import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TcpServerManager {
  ServerSocket? _serverSocket;
  final List<Socket> _clients = [];
  
  // Stream controller to emit incoming messages from any client
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Starts the TCP server on any available port (or specified port).
  /// Returns the port the server bound to.
  Future<int> startServer({int port = 0}) async {
    _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    
    _serverSocket?.listen((Socket client) {
      _clients.add(client);
      
      // Listen to the client stream, splitting by newline for JSON lines
      client.cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (String data) {
          try {
            final Map<String, dynamic> jsonMsg = jsonDecode(data);
            _messageController.add(jsonMsg);
          } catch (e) {
            print('Error parsing client message: $e');
          }
        },
        onError: (error) {
          print('Client error: $error');
          _clients.remove(client);
          client.close();
        },
        onDone: () {
          print('Client disconnected.');
          _clients.remove(client);
          client.close();
        },
      );
    });

    return _serverSocket!.port;
  }

  /// Sends a JSON message to all connected clients.
  void broadcastMessage(Map<String, dynamic> message) {
    final payloadString = jsonEncode(message);
    // Append newline delimiter as per protocol
    final payloadBytes = utf8.encode('$payloadString\n');
    
    for (final client in _clients) {
      try {
        client.add(payloadBytes);
      } catch (e) {
        print('Error broadcasting to client: $e');
      }
    }
  }

  /// Stop the server and disconnect all clients.
  Future<void> stopServer() async {
    for (final client in _clients) {
      client.destroy();
    }
    _clients.clear();
    await _serverSocket?.close();
    _serverSocket = null;
  }
  
  void dispose() {
    stopServer();
    _messageController.close();
  }
}
