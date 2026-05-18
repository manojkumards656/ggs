import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/theme/app_theme.dart';
import 'package:pocket_party/features/host/presentation/host_lobby_screen.dart';
import 'package:pocket_party/features/discovery/presentation/join_room_screen.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(
    const ProviderScope(
      child: PocketPartyApp(),
    ),
  );
}

class PocketPartyApp extends StatelessWidget {
  const PocketPartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pocket Party',
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _nameController = TextEditingController();

  void _navigateToHost() {
    if (_nameController.text.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HostLobbyScreen(
          hostName: _nameController.text.trim(),
          hostId: const Uuid().v4(),
        ),
      ),
    );
  }

  void _navigateToJoin() {
    if (_nameController.text.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => JoinRoomScreen(
          playerName: _nameController.text.trim(),
          playerId: const Uuid().v4(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Party', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Enter your name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                onPressed: _nameController.text.trim().isEmpty ? null : _navigateToHost,
                icon: const Icon(Icons.add),
                label: const Text('HOST A GAME'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _nameController.text.trim().isEmpty ? null : _navigateToJoin,
                icon: const Icon(Icons.search),
                label: const Text('JOIN A GAME'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
