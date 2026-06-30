import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/core/providers/preferences_provider.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';
import 'package:pocket_party/features/game_rummy/domain/providers/rummy_provider.dart';
import 'package:pocket_party/features/game_rummy/presentation/widgets/game_table_widget.dart';
import 'package:pocket_party/features/game_rummy/presentation/widgets/player_hand_widget.dart';

/// Main screen for Indian Rummy.
///
/// Supports both single-phone (pass-and-play) and LAN network modes.
class RummyScreen extends ConsumerStatefulWidget {
  final bool isNetworked;
  final bool isHost;

  const RummyScreen({
    super.key,
    this.isNetworked = false,
    this.isHost = false,
  });

  @override
  ConsumerState<RummyScreen> createState() => _RummyScreenState();
}

class _RummyScreenState extends ConsumerState<RummyScreen> {
  StreamSubscription<Map<String, dynamic>>? _networkSub;
  bool _gameStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isNetworked) {
      _setupNetwork();
    }
  }

  void _setupNetwork() {
    if (widget.isHost) {
      _networkSub = ref.read(tcpServerProvider).messageStream.listen(_onNetworkMessage);
    } else {
      _networkSub = ref.read(tcpClientProvider).messageStream.listen(_onNetworkMessage);
    }
  }

  void _onNetworkMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['type']) {
      case 'rummy_state_sync':
        final newState = RummyGameState.fromJson(msg['state'] as Map<String, dynamic>);
        ref.read(rummyProvider.notifier).syncState(newState);
        if (!_gameStarted) setState(() => _gameStarted = true);
        break;
      case 'rummy_draw_stock':
        if (widget.isHost) {
          ref.read(rummyProvider.notifier).drawFromStock();
          _broadcastState();
        }
        break;
      case 'rummy_draw_discard':
        if (widget.isHost) {
          ref.read(rummyProvider.notifier).drawFromDiscard();
          _broadcastState();
        }
        break;
      case 'rummy_discard':
        if (widget.isHost) {
          final index = msg['index'] as int;
          ref.read(rummyProvider.notifier).discardCard(index);
          _broadcastState();
        }
        break;
      case 'rummy_sort_suit':
        if (widget.isHost) {
          ref.read(rummyProvider.notifier).sortBySuit();
          _broadcastState();
        }
        break;
      case 'rummy_sort_rank':
        if (widget.isHost) {
          ref.read(rummyProvider.notifier).sortByRank();
          _broadcastState();
        }
        break;
      case 'rummy_declare':
        if (widget.isHost) {
          ref.read(rummyProvider.notifier).declareWin();
          _broadcastState();
        }
        break;
      case 'rummy_swap':
        if (widget.isHost) {
          ref.read(rummyProvider.notifier).swapCards(
            msg['from'] as int,
            msg['to'] as int,
          );
          _broadcastState();
        }
        break;
    }
  }

  void _broadcastState() {
    if (!widget.isHost) return;
    final state = ref.read(rummyProvider);
    ref.read(tcpServerProvider).broadcastMessage({
      'type': 'rummy_state_sync',
      'state': state.toJson(),
    });
  }

  void _sendToHost(Map<String, dynamic> msg) {
    if (widget.isHost) return;
    ref.read(tcpClientProvider).sendMessage(msg);
  }

  void _leaveGame() {
    if (widget.isNetworked) {
      resetNetworkProviders(ref);
    }
    ref.read(rummyProvider.notifier).resetGame();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────

  void _startGame() {
    final username = ref.read(usernameProvider);
    final p1Name = widget.isNetworked ? (username.isEmpty ? 'Host' : username) : 'Player 1';
    final p2Name = widget.isNetworked ? 'Opponent' : 'Player 2';

    ref.read(rummyProvider.notifier).startGame(
      player1Name: p1Name,
      player2Name: p2Name,
    );
    setState(() => _gameStarted = true);

    if (widget.isNetworked && widget.isHost) {
      _broadcastState();
    }
  }

  void _onDrawStock() {
    HapticFeedback.lightImpact();
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_draw_stock'});
    } else {
      ref.read(rummyProvider.notifier).drawFromStock();
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onDrawDiscard() {
    HapticFeedback.lightImpact();
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_draw_discard'});
    } else {
      ref.read(rummyProvider.notifier).drawFromDiscard();
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onCardTap(int index) {
    HapticFeedback.selectionClick();
    final gameState = ref.read(rummyProvider);

    if (gameState.canDiscard) {
      // In discard phase — first tap selects, second tap on same card discards
      if (gameState.selectedCardIndex == index) {
        // Discard selected card
        HapticFeedback.mediumImpact();
        if (widget.isNetworked && !widget.isHost) {
          _sendToHost({'type': 'rummy_discard', 'index': index});
        } else {
          ref.read(rummyProvider.notifier).discardCard(index);
          if (widget.isNetworked) _broadcastState();
        }
      } else if (gameState.selectedCardIndex != null) {
        // Swap cards
        if (widget.isNetworked && !widget.isHost) {
          _sendToHost({
            'type': 'rummy_swap',
            'from': gameState.selectedCardIndex,
            'to': index,
          });
        } else {
          ref.read(rummyProvider.notifier).swapCards(
            gameState.selectedCardIndex!,
            index,
          );
          if (widget.isNetworked) _broadcastState();
        }
      } else {
        ref.read(rummyProvider.notifier).selectCard(index);
      }
    } else {
      // In draw phase — just allow selecting/swapping for arrangement
      ref.read(rummyProvider.notifier).selectCard(index);
    }
  }

  void _onSortBySuit() {
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_sort_suit'});
    } else {
      ref.read(rummyProvider.notifier).sortBySuit();
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onSortByRank() {
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_sort_rank'});
    } else {
      ref.read(rummyProvider.notifier).sortByRank();
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onDeclare() {
    HapticFeedback.heavyImpact();
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_declare'});
    } else {
      ref.read(rummyProvider.notifier).declareWin();
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onDismissPass() {
    ref.read(rummyProvider.notifier).dismissPassScreen();
  }

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(rummyProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: SafeArea(
          child: !_gameStarted
              ? _buildStartScreen()
              : gameState.showPassScreen && !widget.isNetworked
                  ? _buildPassScreen(gameState)
                  : gameState.gamePhase == RummyPhase.gameOver
                      ? _buildGameOverScreen(gameState)
                      : _buildGameScreen(gameState),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Start screen
  // ─────────────────────────────────────────────────────────

  Widget _buildStartScreen() {
    return Column(
      children: [
        _buildAppBar('Indian Rummy'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8008).withValues(alpha: 0.31),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.style, size: 48, color: Colors.white),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(height: 24),
                const Text(
                  'Indian Rummy',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ).animate().fade(delay: 200.ms).slideY(begin: 0.3),
                const SizedBox(height: 8),
                Text(
                  '13 Cards • 2 Players',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.59),
                    letterSpacing: 2,
                  ),
                ).animate().fade(delay: 400.ms),
                const SizedBox(height: 48),
                // Start button
                _GlowButton(
                  label: 'DEAL CARDS',
                  icon: Icons.play_arrow_rounded,
                  gradient: const [Color(0xFFFF8008), Color(0xFFFFC837)],
                  onTap: _startGame,
                ).animate().fade(delay: 600.ms).scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.easeOut,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Pass-the-phone screen
  // ─────────────────────────────────────────────────────────

  Widget _buildPassScreen(RummyGameState gameState) {
    return Column(
      children: [
        _buildAppBar('Indian Rummy'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 64,
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.78),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveX(begin: -10, end: 10, duration: 800.ms),
                const SizedBox(height: 24),
                Text(
                  'Pass to ${gameState.currentPlayerName}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ).animate().fade(),
                const SizedBox(height: 8),
                Text(
                  "Don't peek at their cards!",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.59),
                  ),
                ),
                const SizedBox(height: 40),
                _GlowButton(
                  label: "I'M READY",
                  icon: Icons.visibility_rounded,
                  gradient: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                  onTap: _onDismissPass,
                ).animate().fade(delay: 300.ms).slideY(begin: 0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Main game screen
  // ─────────────────────────────────────────────────────────

  Widget _buildGameScreen(RummyGameState gameState) {
    // Determine which hand to show (in network mode, show the local player's hand)
    final isMyTurn = !widget.isNetworked || 
        (widget.isHost && gameState.currentPlayer == 0) ||
        (!widget.isHost && gameState.currentPlayer == 1);

    return Column(
      children: [
        // ── Header ──
        _buildGameHeader(gameState, isMyTurn),

        // ── Opponent hand (face-down) ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: OpponentHandWidget(
            cardCount: gameState.opponentHand.length,
            cardWidth: 28,
          ),
        ),

        // ── Status message ──
        _buildStatusBar(gameState),

        // ── Table (stock + discard + wild joker) ──
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GameTableWidget(
                stockPile: gameState.stockPile,
                discardPile: gameState.discardPile,
                wildJokerCard: gameState.wildJokerCard,
                canDraw: gameState.canDraw && isMyTurn,
                onDrawFromStock: _onDrawStock,
                onDrawFromDiscard: _onDrawDiscard,
                cardWidth: 56,
              ),
            ),
          ),
        ),

        // ── Player's hand ──
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: PlayerHandWidget(
            hand: gameState.currentHand,
            selectedIndex: gameState.selectedCardIndex,
            wildJokerCard: gameState.wildJokerCard,
            isInteractive: isMyTurn,
            onCardTap: isMyTurn ? _onCardTap : null,
            cardWidth: 52,
          ),
        ),

        // ── Action bar ──
        _buildActionBar(gameState, isMyTurn),
      ],
    );
  }

  Widget _buildGameHeader(RummyGameState gameState, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: () => _showExitDialog(),
          ),
          const Spacer(),
          Text(
            'Indian Rummy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const Spacer(),
          // Turn indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isMyTurn
                  ? const Color(0xFF00F2FE).withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: isMyTurn
                    ? const Color(0xFF00F2FE).withValues(alpha: 0.39)
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Text(
              isMyTurn ? 'Your Turn' : 'Waiting...',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isMyTurn ? const Color(0xFF00F2FE) : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(RummyGameState gameState) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF1E1E36).withValues(alpha: 0.71),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Icon(
            gameState.turnPhase == TurnPhase.draw
                ? Icons.download_rounded
                : Icons.upload_rounded,
            size: 14,
            color: const Color(0xFF00F2FE).withValues(alpha: 0.71),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              gameState.message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.78),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Card count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF00F2FE).withValues(alpha: 0.10),
            ),
            child: Text(
              '${gameState.currentHand.length} cards',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF00F2FE),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(RummyGameState gameState, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E36).withValues(alpha: 0.78),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.sort,
              label: 'Suit',
              onTap: isMyTurn ? _onSortBySuit : null,
            ),
            _ActionButton(
              icon: Icons.format_list_numbered,
              label: 'Rank',
              onTap: isMyTurn ? _onSortByRank : null,
            ),
            _ActionButton(
              icon: Icons.emoji_events_rounded,
              label: 'Declare',
              isAccent: true,
              onTap: isMyTurn && gameState.canDiscard ? null : null,
              // Enable declare only when player has 13 cards
              forceEnable:
                  isMyTurn && gameState.currentHand.length == 13,
              onForceTap: _onDeclare,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Game over screen
  // ─────────────────────────────────────────────────────────

  Widget _buildGameOverScreen(RummyGameState gameState) {
    return Column(
      children: [
        _buildAppBar('Game Over'),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trophy
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.39),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 56,
                    color: Colors.white,
                  ),
                ).animate().scale(
                  duration: 800.ms,
                  curve: Curves.elasticOut,
                ),
                const SizedBox(height: 24),
                Text(
                  gameState.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GlowButton(
                      label: 'PLAY AGAIN',
                      icon: Icons.replay_rounded,
                      gradient: const [Color(0xFFFF8008), Color(0xFFFFC837)],
                      onTap: () {
                        setState(() => _gameStarted = false);
                        ref.read(rummyProvider.notifier).resetGame();
                      },
                    ),
                    const SizedBox(width: 16),
                    _GlowButton(
                      label: 'EXIT',
                      icon: Icons.home_rounded,
                      gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                      onTap: _leaveGame,
                    ),
                  ],
                ).animate().fade(delay: 500.ms).slideY(begin: 0.3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // Shared widgets
  // ─────────────────────────────────────────────────────────

  Widget _buildAppBar(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: () => _showExitDialog(),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // balance
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Game?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your progress will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('STAY', style: TextStyle(color: Color(0xFF00F2FE))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _leaveGame();
            },
            child: const Text('LEAVE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reusable UI components
// ─────────────────────────────────────────────────────────────

class _GlowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  const _GlowButton({
    required this.label,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.31),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isAccent;
  final bool forceEnable;
  final VoidCallback? onForceTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isAccent = false,
    this.forceEnable = false,
    this.onForceTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || forceEnable;
    final effectiveTap = forceEnable ? onForceTap : onTap;

    return GestureDetector(
      onTap: enabled ? effectiveTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isAccent && enabled
                ? const Color(0xFFFF8008).withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: isAccent && enabled
                  ? const Color(0xFFFF8008).withValues(alpha: 0.39)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isAccent && enabled
                    ? const Color(0xFFFFC837)
                    : Colors.white70,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isAccent && enabled
                      ? const Color(0xFFFFC837)
                      : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
