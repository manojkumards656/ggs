import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/discovery/domain/room.dart';
import 'package:pocket_party/features/host/domain/player.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import 'package:pocket_party/features/game_draw/presentation/game_screen.dart';

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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GameScreen(isHost: false)),
        );
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
        title: Text(widget.room.name),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Waiting for Host to start the game...',
                style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
          ),
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
        ],
      ),
    );
  }
}
