import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Handles UDP broadcast-based room discovery on LAN.
///
/// Two modes:
/// - Broadcasting (host): Sends room info to 255.255.255.255 at adaptive intervals
/// - Listening (client): Receives broadcasts and emits discovered rooms
///
/// Why UDP broadcast over mDNS/Bonjour: Simpler, zero platform-specific
/// configuration, sub-second discovery on any LAN/hotspot.
class UdpDiscoveryService {
  static const int _discoveryPort = 44444;

  /// Adaptive broadcast timing: fast initially for quick discovery,
  /// then slows down to save battery during steady-state hosting.
  static const Duration _fastInterval = Duration(milliseconds: 500);
  static const Duration _steadyInterval = Duration(seconds: 5);
  static const Duration _fastPhaseDuration = Duration(seconds: 5);

  RawDatagramSocket? _broadcastSocket;
  RawDatagramSocket? _listenSocket;
  Timer? _broadcastTimer;
  Timer? _phaseTransitionTimer;
  StreamSubscription? _listenSubscription;

  // Broadcast controller to emit discovered rooms
  final _discoveryController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get discoveryStream => _discoveryController.stream;

  /// Starts broadcasting the host's room info to the local network.
  ///
  /// Uses adaptive intervals: broadcasts every 500ms for the first 5 seconds
  /// (so nearby clients discover the room almost instantly), then slows to
  /// every 5 seconds (60% less radio wake-ups → significant battery savings
  /// during 30-90 minute game sessions).
  Future<void> startBroadcasting(Map<String, dynamic> roomInfo) async {
    stopBroadcasting();

    _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _broadcastSocket?.broadcastEnabled = true;

    final payloadString = jsonEncode(roomInfo);
    final payloadBytes = utf8.encode(payloadString);
    final broadcastAddr = InternetAddress('255.255.255.255');

    void sendBroadcast() {
      try {
        _broadcastSocket?.send(payloadBytes, broadcastAddr, _discoveryPort);
      } catch (e) {
        print('Error broadcasting discovery: $e');
      }
    }

    // Fast phase: broadcast every 500ms for the first 5 seconds
    sendBroadcast(); // Send immediately on start
    _broadcastTimer = Timer.periodic(_fastInterval, (_) => sendBroadcast());

    // After 5 seconds, switch to steady-state interval.
    // Uses a cancellable Timer instead of Future.delayed so that
    // stopBroadcasting() can prevent the phase transition from firing.
    _phaseTransitionTimer = Timer(_fastPhaseDuration, () {
      if (_broadcastTimer != null && _broadcastSocket != null) {
        _broadcastTimer?.cancel();
        _broadcastTimer = Timer.periodic(_steadyInterval, (_) => sendBroadcast());
      }
      _phaseTransitionTimer = null;
    });
  }

  /// Stops broadcasting room info.
  void stopBroadcasting() {
    _phaseTransitionTimer?.cancel();
    _phaseTransitionTimer = null;
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastSocket?.close();
    _broadcastSocket = null;
  }

  /// Starts listening for broadcast messages from hosts on the network.
  Future<void> startListening() async {
    stopListening();

    _listenSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
    _listenSocket?.broadcastEnabled = true;

    // Store the subscription so stopListening() can cancel it cleanly
    _listenSubscription = _listenSocket?.listen((RawSocketEvent event) {
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
              if (!_discoveryController.isClosed) {
                _discoveryController.add(jsonMsg);
              }
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
    _listenSubscription?.cancel();
    _listenSubscription = null;
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
