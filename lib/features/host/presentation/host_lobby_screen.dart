import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/discovery/domain/room.dart';
import 'package:pocket_party/features/host/domain/player.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import 'package:pocket_party/features/host/providers/game_loop_provider.dart';
import 'package:pocket_party/features/game_draw/presentation/game_screen.dart';
import 'package:uuid/uuid.dart';

class HostLobbyScreen extends ConsumerStatefulWidget {
  final String hostName;
  final String hostId;

  const HostLobbyScreen({
    super.key,
    required this.hostName,
    required this.hostId,
  });

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
  final String roomId = const Uuid().v4();
  int? _serverPort;
  bool _isServerRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServer();
    });
  }

  Future<void> _initServer() async {
    final tcpServer = ref.read(tcpServerProvider);
    final discovery = ref.read(udpDiscoveryProvider);

    // 1. Add host to lobby
    final hostPlayer = Player(
      id: widget.hostId,
      name: widget.hostName,
      isHost: true,
    );
    ref.read(lobbyProvider.notifier).addPlayer(hostPlayer);

    try {
      // 2. Start TCP Server on random port
      _serverPort = await tcpServer.startServer();
      setState(() {
        _isServerRunning = true;
      });

      // 3. Listen to incoming messages
      tcpServer.messageStream.listen((msg) {
        if (msg['type'] == 'join') {
          final playerMsg = msg['player'] as Map<String, dynamic>;
          final player = Player.fromJson(playerMsg);
          ref.read(lobbyProvider.notifier).addPlayer(player);
          
          // Broadcast updated lobby to all clients
          final updatedLobby = ref.read(lobbyProvider).map((p) => p.toJson()).toList();
          tcpServer.broadcastMessage({
            'type': 'lobby_update',
            'players': updatedLobby,
          });
        }
      });

      // 4. Start UDP Discovery Broadcasting
      final room = Room(
        id: roomId,
        name: "${widget.hostName}'s Room",
        hostName: widget.hostName,
        gameType: 'Draw & Guess',
        playersCount: 1, // Start with host
        maxPlayers: 8,
        tcpPort: _serverPort!,
        hostIp: '', // Added later by client when they receive it
      );
      
      await discovery.startBroadcasting(room.toJson());
    } catch (e) {
      debugPrint('Error starting server: $e');
    }
  }

  void _startGame() {
    final tcpServer = ref.read(tcpServerProvider);
    final discovery = ref.read(udpDiscoveryProvider);
    
    // Stop broadcasting since game is starting
    discovery.stopBroadcasting();

    // Trigger game start logic in provider
    // First player in lobby is drawer for round 1
    final players = ref.read(lobbyProvider);
    if (players.isEmpty) return;
    
    final drawerId = players.first.id;
    final word = 'apple'; // TODO: random word selection
    
    ref.read(gameLoopProvider.notifier).startGame(drawerId, word);
    
    // Broadcast to clients
    tcpServer.broadcastMessage({
      'type': 'game_started',
    });
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GameScreen(isHost: true)),
    );
  }

  @override
  void dispose() {
    // Note: Do not dispose network managers here if we still need them in GameScreen
    // Only stop discovery broadcasting
    ref.read(udpDiscoveryProvider).stopBroadcasting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(lobbyProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Lobby'),
        actions: [
          if (_isServerRunning)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('Broadcasting...', style: TextStyle(color: Colors.greenAccent)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: players.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final p = players[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(p.isHost ? Icons.star : Icons.person),
                        ),
                        title: Text(p.name, style: const TextStyle(fontSize: 18)),
                        subtitle: Text(p.isHost ? 'Host' : 'Ready'),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: players.isNotEmpty ? _startGame : null, // Can start solo for testing
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                child: const Text('START GAME'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
