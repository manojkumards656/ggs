import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/core/game_registry.dart';
import 'package:pocket_party/features/discovery/domain/room.dart';
import 'package:pocket_party/features/host/domain/player.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import 'package:pocket_party/features/host/providers/game_loop_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

class HostLobbyScreen extends ConsumerStatefulWidget {
  final String hostName;
  final String hostId;
  final String gameName;

  const HostLobbyScreen({
    super.key,
    required this.hostName,
    required this.hostId,
    required this.gameName,
  });

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
  final String roomId = const Uuid().v4();
  int? _serverPort;
  bool _isServerRunning = false;
  StreamSubscription? _tcpMessageSub;

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

    final hostPlayer = Player(
      id: widget.hostId,
      name: widget.hostName,
      isHost: true,
    );
    ref.read(lobbyProvider.notifier).addPlayer(hostPlayer);

    try {
      _serverPort = await tcpServer.startServer();
      setState(() {
        _isServerRunning = true;
      });

      _tcpMessageSub = tcpServer.messageStream.listen((msg) {
        if (!mounted) return;
        if (msg['type'] == 'join') {
          final playerMsg = msg['player'] as Map<String, dynamic>;
          final player = Player.fromJson(playerMsg);
          ref.read(lobbyProvider.notifier).addPlayer(player);
          
          final updatedLobby = ref.read(lobbyProvider).map((p) => p.toJson()).toList();
          tcpServer.broadcastMessage({
            'type': 'lobby_update',
            'players': updatedLobby,
          });
        }
      });

      final room = Room(
        id: roomId,
        name: "${widget.hostName}'s Room",
        hostName: widget.hostName,
        gameType: widget.gameName,
        playersCount: 1, 
        maxPlayers: 8,
        tcpPort: _serverPort!,
        hostIp: '', 
      );
      
      await discovery.startBroadcasting(room.toJson());
    } catch (e) {
      debugPrint('Error starting server: $e');
    }
  }

  void _startGame() {
    final tcpServer = ref.read(tcpServerProvider);
    final discovery = ref.read(udpDiscoveryProvider);
    
    discovery.stopBroadcasting();

    final players = ref.read(lobbyProvider);
    if (players.isEmpty) return;
    
    final drawerId = players.first.id;
    final word = 'apple'; 
    
    ref.read(gameLoopProvider.notifier).startGame(drawerId, word);
    
    tcpServer.broadcastMessage({
      'type': 'game_started',
    });
    
    // Registry-based routing — no switch statement needed.
    // The game declares its own screen builder in game_registry.dart.
    final game = findGameByName(widget.gameName);
    if (game?.networkScreenBuilder != null) {
      final screen = game!.networkScreenBuilder!(isHost: true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    } else {
      // Defensive fallback — shouldn't happen if registry is set up correctly
      debugPrint('No network screen builder found for: ${widget.gameName}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.gameName} does not support network mode')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tcpMessageSub?.cancel();
    ref.read(udpDiscoveryProvider).stopBroadcasting();
    ref.read(tcpServerProvider).stopServer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(lobbyProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Host Lobby', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isServerRunning)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: const Text('Broadcasting...', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                    .animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: players.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final p = players[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: p.isHost ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: p.isHost ? Theme.of(context).colorScheme.primary : Colors.grey.shade800,
                              child: Icon(p.isHost ? Icons.star : Icons.person, size: 32, color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(p.isHost ? 'Host' : 'Ready', style: TextStyle(color: p.isHost ? Theme.of(context).colorScheme.primary : Colors.greenAccent)),
                          ],
                        ),
                      ).animate().scale(curve: Curves.easeOutBack).fade();
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: players.isNotEmpty ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: const Text('START GAME'),
              ),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
          ),
        ],
      ),
    );
  }
}
