import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/discovery/domain/room.dart';
import 'client_lobby_screen.dart';

class JoinRoomScreen extends ConsumerStatefulWidget {
  final String playerName;
  final String playerId;

  const JoinRoomScreen({
    super.key,
    required this.playerName,
    required this.playerId,
  });

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final Map<String, Room> _discoveredRooms = {};
  StreamSubscription? _discoverySub;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscovery();
    });
  }

  void _startDiscovery() async {
    final discovery = ref.read(udpDiscoveryProvider);
    await discovery.startListening();
    
    _discoverySub = discovery.discoveryStream.listen((msg) {
      if (!mounted) return;
      try {
        final room = Room.fromJson(msg);
        setState(() {
          _discoveredRooms[room.id] = room;
        });
      } catch (e) {
        debugPrint('Failed to parse room: $e');
      }
    });
  }

  Future<void> _joinRoom(Room room) async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);

    try {
      final tcpClient = ref.read(tcpClientProvider);
      final discovery = ref.read(udpDiscoveryProvider);
      
      // Stop discovery listening
      discovery.stopListening();
      _discoverySub?.cancel();

      // Connect to Host
      await tcpClient.connect(room.hostIp, room.tcpPort);
      
      // Send join request
      tcpClient.sendMessage({
        'type': 'join',
        'player': {
          'id': widget.playerId,
          'name': widget.playerName,
          'isHost': false,
        }
      });
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ClientLobbyScreen(room: room),
        ),
      );
    } catch (e) {
      debugPrint('Failed to connect: $e');
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join room: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _discoverySub?.cancel();
    ref.read(udpDiscoveryProvider).stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _discoveredRooms.values.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
      ),
      body: _isConnecting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Connecting...'),
                ],
              ),
            )
          : rooms.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Scanning network for games...'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.wifi),
                        ),
                        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Host: ${room.hostName} | Game: ${room.gameType}'),
                        trailing: ElevatedButton(
                          onPressed: () => _joinRoom(room),
                          child: const Text('JOIN'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
