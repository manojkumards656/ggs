import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/discovery/domain/room.dart';
import 'package:pocket_party/features/host/domain/player.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import 'package:pocket_party/features/game_draw/presentation/game_screen.dart';
import 'package:pocket_party/features/game_chess/presentation/chess_board_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ClientLobbyScreen extends ConsumerStatefulWidget {
  final Room room;

  const ClientLobbyScreen({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<ClientLobbyScreen> createState() => _ClientLobbyScreenState();
}

class _ClientLobbyScreenState extends ConsumerState<ClientLobbyScreen> {
  StreamSubscription? _messageSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenToHost();
    });
  }

  void _listenToHost() {
    final tcpClient = ref.read(tcpClientProvider);
    _messageSub = tcpClient.messageStream.listen((msg) {
      if (!mounted) return;
      
      final type = msg['type'];
      
      if (type == 'lobby_update') {
        final playersList = msg['players'] as List;
        final players = playersList.map((p) => Player.fromJson(p)).toList();
        
        // Update lobby provider
        ref.read(lobbyProvider.notifier).setPlayers(players);
      } else if (type == 'game_started') {
        if (widget.room.gameType == 'Chess') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChessBoardScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const GameScreen(isHost: false)),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(lobbyProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: const Text('Waiting for Host to start the game...',
                style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic, color: Colors.grey))
                .animate(onPlay: (c) => c.repeat(reverse: true)).fade(),
          ),
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
        ],
      ),
    );
  }
}
