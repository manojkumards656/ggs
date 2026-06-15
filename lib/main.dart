import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/core/theme/app_theme.dart';
import 'package:pocket_party/core/game_registry.dart';
import 'package:pocket_party/features/host/presentation/host_lobby_screen.dart';
import 'package:pocket_party/features/discovery/presentation/join_room_screen.dart';
import 'package:pocket_party/features/settings/presentation/settings_screen.dart';
import 'package:pocket_party/core/providers/preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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

  void _openGameDialog(BuildContext context, WidgetRef ref, GameDefinition game) {
    final username = ref.read(usernameProvider);

    if (username.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ).then((_) {
        if (!context.mounted) return;
        if (ref.read(usernameProvider).isNotEmpty) {
          _openGameDialog(context, ref, game);
        }
      });
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate().fade().slideY(begin: 1),
                const SizedBox(height: 24),
                Text(
                  'Play ${game.displayName}',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
                const SizedBox(height: 8),
                Text('Playing as: $username', style: const TextStyle(color: Colors.grey))
                    .animate().fade(delay: 200.ms),
                const SizedBox(height: 40),
                
                // ── Network buttons: only if the game supports it ──
                if (game.supportsNetwork) ...[
                  _buildActionButton(
                    context: context,
                    icon: Icons.add,
                    label: 'HOST A GAME',
                    gradient: const LinearGradient(colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)]),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HostLobbyScreen(
                            hostName: username,
                            hostId: const Uuid().v4(),
                            gameName: game.displayName,
                          ),
                        ),
                      );
                    },
                  ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(height: 16),
                  
                  _buildActionButton(
                    context: context,
                    icon: Icons.search,
                    label: 'JOIN A GAME',
                    isOutline: true,
                    onTap: () {
                      Navigator.pop(context);
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
                  ).animate().fade(delay: 400.ms).slideY(begin: 0.2),
                  const SizedBox(height: 16),
                ],

                // ── Single-phone button: only if the game supports it ──
                if (game.supportsSinglePhone)
                  _buildActionButton(
                    context: context,
                    icon: Icons.phone_android,
                    label: 'PLAY ON SINGLE PHONE',
                    gradient: const LinearGradient(colors: [Color(0xFF43E97B), Color(0xFF38F9D7)]),
                    onTap: () {
                      Navigator.pop(context);
                      // Registry-based routing — no switch statement needed
                      final screen = game.singlePhoneScreenBuilder!();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => screen),
                      );
                    },
                  ).animate().fade(delay: game.supportsNetwork ? 500.ms : 300.ms).slideY(begin: 0.2),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    LinearGradient? gradient,
    bool isOutline = false,
    required VoidCallback onTap,
  }) {
    if (isOutline) {
      return SizedBox(
        width: double.infinity,
        height: 60,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Theme.of(context).colorScheme.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient?.colors.first.withValues(alpha: 0.4) ?? Colors.transparent,
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
          ).animate().fade().scale(),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text(
                  'Select a Game',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
                ).animate().fade(duration: 500.ms).slideX(begin: -0.2),
                const SizedBox(height: 8),
                Text(
                  'What are we playing today?',
                  style: TextStyle(fontSize: 16, color: Colors.white.withValues(alpha: 0.6)),
                ).animate().fade(delay: 200.ms).slideX(begin: -0.2),
                const SizedBox(height: 40),

                // ── Registry-driven game grid ──
                // The entire grid is generated from gameRegistry.
                // Adding/removing a game here requires ZERO changes to this file.
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: gameRegistry.length,
                    itemBuilder: (context, index) {
                      final game = gameRegistry[index];
                      final delay = (100 + index * 100).ms;

                      Widget card = _GameCard(
                        title: game.displayName,
                        icon: game.icon,
                        gradient: game.gradient,
                        isComingSoon: game.isComingSoon,
                        onTap: game.isComingSoon
                            ? () {}
                            : () => _openGameDialog(context, ref, game),
                      );

                      // Add shimmer to the first card (Draw & Guess featured)
                      if (index == 0) {
                        card = card
                            .animate(onPlay: (controller) => controller.repeat())
                            .shimmer(duration: 3000.ms, color: Colors.white.withValues(alpha: 0.1));
                      }

                      return card.animate().fade(delay: delay).scale();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.icon,
    required this.gradient,
    this.isComingSoon = false,
    required this.onTap,
  });

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isComingSoon ? null : (_) => _controller.forward(),
      onTapUp: widget.isComingSoon ? null : (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: widget.isComingSoon ? null : () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, size: 56, color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isComingSoon)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
