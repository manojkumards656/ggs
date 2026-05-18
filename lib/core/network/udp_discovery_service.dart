import 'dart:async';
import 'dart:convert';
import 'dart:io';

class UdpDiscoveryService {
  static const int _discoveryPort = 44444;
  
  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  
  // Stream controller to emit discovered rooms
  final _discoveryController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get discoveryStream => _discoveryController.stream;

  /// Starts broadcasting the host's room info to the local network.
  Future<void> startBroadcasting(Map<String, dynamic> roomInfo) async {
    _broadcastSocket?.close();
    
    // Bind to any IPv4 address to send broadcasts
    _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _broadcastSocket?.broadcastEnabled = true;

    final payloadString = jsonEncode(roomInfo);
    final payloadBytes = utf8.encode(payloadString);
    
    // Broadcast every 2 seconds
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      try {
        _broadcastSocket?.send(payloadBytes, InternetAddress('255.255.255.255'), _discoveryPort);
      } catch (e) {
        print('Error broadcasting discovery: $e');
      }
    });
  }

  /// Stops broadcasting room info.
  void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  /// Starts listening for broadcast messages from hosts on the network.
  Future<void> startListening() async {
    _listenSocket?.close();
    
    // Bind to the specific discovery port
    _listenSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
    _listenSocket?.broadcastEnabled = true;

    _listenSocket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        final Datagram? datagram = _listenSocket?.receive();
        if (datagram != null) {
          try {
            final String message = utf8.decode(datagram.data);
            final Map<String, dynamic> jsonMsg = jsonDecode(message);
            
            // Validate it's a discovery message
            if (jsonMsg['type'] == 'discovery') {
              // Inject the sender's IP so clients know where to connect via TCP
              jsonMsg['hostIp'] = datagram.address.address;
              _discoveryController.add(jsonMsg);
            }
          } catch (e) {
            print('Error parsing discovery payload: $e');
          }
        }
      }
    });
  }

  /// Stops listening for broadcasts.
  void stopListening() {
    _listenSocket?.close();
    _listenSocket = null;
  }

  /// Cleans up all sockets and streams.
  void dispose() {
    stopBroadcasting();
    stopListening();
    _discoveryController.close();
  }
}
