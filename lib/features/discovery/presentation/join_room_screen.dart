import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/discovery/domain/room.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final Map<String, DateTime> _lastSeen = {}; // Track when each room was last seen
  StreamSubscription? _discoverySub;
  Timer? _cleanupTimer; // Periodic timer to prune stale rooms
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
          _lastSeen[room.id] = DateTime.now();
        });
      } catch (e) {
        debugPrint('Failed to parse room: $e');
      }
    });

    // Prune stale rooms every 3 seconds — removes rooms not seen for 6+ seconds.
    // This prevents users from trying to join hosts that have gone offline.
    _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final staleIds = _lastSeen.entries
          .where((e) => now.difference(e.value).inSeconds >= 6)
          .map((e) => e.key)
          .toList();

      if (staleIds.isNotEmpty) {
        setState(() {
          for (final id in staleIds) {
            _discoveredRooms.remove(id);
            _lastSeen.remove(id);
          }
        });
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
    _cleanupTimer?.cancel();
    ref.read(udpDiscoveryProvider).stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _discoveredRooms.values.toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Party', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isConnecting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('Connecting to host...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .fade(duration: 800.ms),
                ],
              ),
            )
          : rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        ),
                        child: Icon(Icons.radar, size: 50, color: Theme.of(context).colorScheme.primary),
                      ).animate(onPlay: (c) => c.repeat())
                       .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.5, 1.5), duration: 1500.ms)
                       .fade(end: 0),
                      const SizedBox(height: 32),
                      const Text('Scanning local network...', style: TextStyle(fontSize: 18, color: Colors.grey))
                          .animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.wifi, color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('Host: ${room.hostName} • ${room.gameType}'),
                        trailing: ElevatedButton(
                          onPressed: () => _joinRoom(room),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('JOIN', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ).animate().fade(delay: (index * 100).ms).slideY(begin: 0.2, curve: Curves.easeOutBack);
                  },
                ),
    );
  }
}
