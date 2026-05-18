import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/theme/app_theme.dart';
import 'package:pocket_party/features/host/presentation/host_lobby_screen.dart';
import 'package:pocket_party/features/discovery/presentation/join_room_screen.dart';
import 'package:pocket_party/features/settings/presentation/settings_screen.dart';
import 'package:pocket_party/core/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pocket_party/features/game_chess/presentation/chess_board_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const PocketPartyApp(),
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _openGameDialog(BuildContext context, WidgetRef ref, String gameName) {
    final username = ref.read(usernameProvider);
    
    if (username.isEmpty) {
      // Must set name first
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ).then((_) {
        // After returning from settings, check if they set a name
        if (!context.mounted) return;
        if (ref.read(usernameProvider).isNotEmpty) {
          _openGameDialog(context, ref, gameName);
        }
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Play $gameName',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Playing as: $username', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HostLobbyScreen(
                          hostName: username,
                          hostId: const Uuid().v4(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('HOST A GAME'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JoinRoomScreen(
                          playerName: username,
                          playerId: const Uuid().v4(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('JOIN A GAME'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (gameName == 'Chess') ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChessBoardScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.phone_android),
                    label: const Text('PLAY ON SINGLE PHONE'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Party', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a Game',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _GameCard(
                    title: 'Draw & Guess',
                    icon: Icons.brush,
                    color: Colors.blueAccent,
                    onTap: () => _openGameDialog(context, ref, 'Draw & Guess'),
                  ),
                  _GameCard(
                    title: 'Chess',
                    icon: Icons.grid_on, // Or another suitable icon
                    color: Colors.brown.shade800,
                    isComingSoon: false,
                    onTap: () => _openGameDialog(context, ref, 'Chess'),
                  ),
                  _GameCard(
                    title: 'Trivia',
                    icon: Icons.quiz,
                    color: Colors.grey.shade800,
                    isComingSoon: true,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.icon,
    required this.color,
    this.isComingSoon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isComingSoon ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (isComingSoon)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
