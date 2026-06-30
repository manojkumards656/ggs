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

/// Main screen for Indian Rummy — forced **landscape** for maximum card space.
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

  // ─────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Lock to landscape for spacious card layout
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (widget.isNetworked) _setupNetwork();
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    // Restore orientation & system UI
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────
  // Networking
  // ─────────────────────────────────────────────────────────

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
        final s = RummyGameState.fromJson(msg['state'] as Map<String, dynamic>);
        ref.read(rummyProvider.notifier).syncState(s);
        if (!_gameStarted) setState(() => _gameStarted = true);
        break;
      case 'rummy_draw_stock':
        if (widget.isHost) { ref.read(rummyProvider.notifier).drawFromStock(); _broadcastState(); }
        break;
      case 'rummy_draw_discard':
        if (widget.isHost) { ref.read(rummyProvider.notifier).drawFromDiscard(); _broadcastState(); }
        break;
      case 'rummy_discard':
        if (widget.isHost) { ref.read(rummyProvider.notifier).discardCard(msg['index'] as int); _broadcastState(); }
        break;
      case 'rummy_move':
        if (widget.isHost) { ref.read(rummyProvider.notifier).moveCard(msg['from'] as int, msg['to'] as int); _broadcastState(); }
        break;
      case 'rummy_sort_suit':
        if (widget.isHost) { ref.read(rummyProvider.notifier).sortBySuit(); _broadcastState(); }
        break;
      case 'rummy_sort_rank':
        if (widget.isHost) { ref.read(rummyProvider.notifier).sortByRank(); _broadcastState(); }
        break;
      case 'rummy_declare':
        if (widget.isHost) { ref.read(rummyProvider.notifier).declareWin(); _broadcastState(); }
        break;
      case 'rummy_swap':
        if (widget.isHost) { ref.read(rummyProvider.notifier).swapCards(msg['from'] as int, msg['to'] as int); _broadcastState(); }
        break;
    }
  }

  void _broadcastState() {
    if (!widget.isHost) return;
    ref.read(tcpServerProvider).broadcastMessage({
      'type': 'rummy_state_sync',
      'state': ref.read(rummyProvider).toJson(),
    });
  }

  void _sendToHost(Map<String, dynamic> msg) {
    if (widget.isHost) return;
    ref.read(tcpClientProvider).sendMessage(msg);
  }

  void _leaveGame() {
    if (widget.isNetworked) resetNetworkProviders(ref);
    ref.read(rummyProvider.notifier).resetGame();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ─────────────────────────────────────────────────────────
  // Game actions
  // ─────────────────────────────────────────────────────────

  void _startGame() {
    final username = ref.read(usernameProvider);
    final p1 = widget.isNetworked ? (username.isEmpty ? 'Host' : username) : 'Player 1';
    final p2 = widget.isNetworked ? 'Opponent' : 'Player 2';
    ref.read(rummyProvider.notifier).startGame(player1Name: p1, player2Name: p2);
    setState(() => _gameStarted = true);
    if (widget.isNetworked && widget.isHost) _broadcastState();
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
    final gs = ref.read(rummyProvider);

    if (gs.canDiscard) {
      if (gs.selectedCardIndex == index) {
        // Double-tap → discard
        _doDiscard(index);
      } else if (gs.selectedCardIndex != null) {
        // Swap
        _doSwap(gs.selectedCardIndex!, index);
      } else {
        ref.read(rummyProvider.notifier).selectCard(index);
      }
    } else {
      ref.read(rummyProvider.notifier).selectCard(index);
    }
  }

  void _doDiscard(int index) {
    HapticFeedback.mediumImpact();
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_discard', 'index': index});
    } else {
      ref.read(rummyProvider.notifier).discardCard(index);
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _doSwap(int from, int to) {
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_swap', 'from': from, 'to': to});
    } else {
      ref.read(rummyProvider.notifier).swapCards(from, to);
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onReorder(int from, int to) {
    HapticFeedback.lightImpact();
    if (widget.isNetworked && !widget.isHost) {
      _sendToHost({'type': 'rummy_move', 'from': from, 'to': to});
    } else {
      ref.read(rummyProvider.notifier).moveCard(from, to);
      if (widget.isNetworked) _broadcastState();
    }
  }

  void _onDragDiscard(int index) {
    final gs = ref.read(rummyProvider);
    if (!gs.canDiscard) return;
    _doDiscard(index);
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

  void _onDismissPass() => ref.read(rummyProvider.notifier).dismissPassScreen();

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(rummyProvider);

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
              : gs.showPassScreen && !widget.isNetworked
                  ? _buildPassScreen(gs)
                  : gs.gamePhase == RummyPhase.gameOver
                      ? _buildGameOverScreen(gs)
                      : _buildGameScreen(gs),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Start screen (landscape)
  // ─────────────────────────────────────────────────────────

  Widget _buildStartScreen() {
    return Row(
      children: [
        // Left: back button
        Padding(
          padding: const EdgeInsets.all(8),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
            onPressed: () => _showExitDialog(),
          ),
        ),
        // Center: logo and start
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8008), Color(0xFFFFC837)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF8008).withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.style, size: 40, color: Colors.white),
                ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                const SizedBox(width: 32),
                // Title + button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Indian Rummy',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ).animate().fade(delay: 200.ms).slideX(begin: 0.2),
                    const SizedBox(height: 4),
                    Text(
                      '13 Cards  •  2 Players  •  Drag & Drop',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
                        letterSpacing: 1.5,
                      ),
                    ).animate().fade(delay: 350.ms),
                    const SizedBox(height: 20),
                    _GlowButton(
                      label: 'DEAL CARDS',
                      icon: Icons.play_arrow_rounded,
                      gradient: const [Color(0xFFFF8008), Color(0xFFFFC837)],
                      onTap: _startGame,
                    ).animate().fade(delay: 500.ms).scale(
                      begin: const Offset(0.85, 0.85),
                      curve: Curves.easeOut,
                    ),
                  ],
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

  Widget _buildPassScreen(RummyGameState gs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 56,
            color: const Color(0xFF00F2FE).withValues(alpha: 0.8),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(begin: -10, end: 10, duration: 800.ms),
          const SizedBox(height: 16),
          Text(
            'Pass to ${gs.currentPlayerName}',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white),
          ).animate().fade(),
          const SizedBox(height: 6),
          Text(
            "Don't peek at their cards!",
            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
          ),
          const SizedBox(height: 28),
          _GlowButton(
            label: "I'M READY",
            icon: Icons.visibility_rounded,
            gradient: const [Color(0xFF4FACFE), Color(0xFF00F2FE)],
            onTap: _onDismissPass,
          ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Main game screen — LANDSCAPE layout
  // ─────────────────────────────────────────────────────────

  Widget _buildGameScreen(RummyGameState gs) {
    final isMyTurn = !widget.isNetworked ||
        (widget.isHost && gs.currentPlayer == 0) ||
        (!widget.isHost && gs.currentPlayer == 1);

    final screenHeight = MediaQuery.sizeOf(context).height;

    // Dynamically calculate card sizes based on landscape height
    final playerCardWidth = (screenHeight * 0.16).clamp(42.0, 75.0);
    final tableCardWidth = (screenHeight * 0.14).clamp(36.0, 68.0);
    final opponentCardWidth = (screenHeight * 0.065).clamp(18.0, 36.0);

    return Column(
      children: [
        // ── Top bar: header + status ──
        _buildTopBar(gs, isMyTurn),

        // ── Opponent hand centered at top ──
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${gs.opponentPlayerName}: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              OpponentHandWidget(
                cardCount: gs.opponentHand.length,
                cardWidth: opponentCardWidth,
              ),
              const SizedBox(width: 10),
              Text(
                '(${gs.opponentHand.length} cards)',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),

        // ── Center Table Area (perfectly centered) ──
        Expanded(
          child: Center(
            child: GameTableWidget(
              stockPile: gs.stockPile,
              discardPile: gs.discardPile,
              wildJokerCard: gs.wildJokerCard,
              canDraw: gs.canDraw && isMyTurn,
              canDiscard: gs.canDiscard && isMyTurn,
              onDrawFromStock: _onDrawStock,
              onDrawFromDiscard: _onDrawDiscard,
              onCardDiscarded: isMyTurn ? _onDragDiscard : null,
              cardWidth: tableCardWidth,
            ),
          ),
        ),

        // ── Bottom area: Player hand in center + actions on the right ──
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              // Left placeholder to balance the action panel on the right and center the hand
              const SizedBox(width: 72),
              
              // Centered hand
              Expanded(
                child: PlayerHandWidget(
                  hand: gs.currentHand,
                  selectedIndex: gs.selectedCardIndex,
                  wildJokerCard: gs.wildJokerCard,
                  isInteractive: isMyTurn,
                  onCardTap: isMyTurn ? _onCardTap : null,
                  onReorder: isMyTurn ? _onReorder : null,
                  cardWidth: playerCardWidth,
                ),
              ),

              // Action buttons column on the right
              SizedBox(
                width: 72,
                child: _buildActionPanel(gs, isMyTurn),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar(RummyGameState gs, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E36).withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
            onPressed: _showExitDialog,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          // Title
          Text(
            'Indian Rummy',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(width: 12),
          // Status message
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.04),
              ),
              child: Row(
                children: [
                  Icon(
                    gs.turnPhase == TurnPhase.draw
                        ? Icons.download_rounded
                        : Icons.upload_rounded,
                    size: 12,
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      gs.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Card count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFF00F2FE).withValues(alpha: 0.08),
            ),
            child: Text(
              '${gs.currentHand.length} cards',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF00F2FE),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Turn indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isMyTurn
                  ? const Color(0xFF00F2FE).withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: isMyTurn
                    ? const Color(0xFF00F2FE).withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              isMyTurn ? 'Your Turn' : 'Waiting…',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isMyTurn ? const Color(0xFF00F2FE) : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildActionPanel(RummyGameState gs, bool isMyTurn) {
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CompactActionButton(
            icon: Icons.sort,
            label: 'Suit',
            onTap: isMyTurn ? _onSortBySuit : null,
          ),
          const SizedBox(height: 8),
          _CompactActionButton(
            icon: Icons.format_list_numbered,
            label: 'Rank',
            onTap: isMyTurn ? _onSortByRank : null,
          ),
          const SizedBox(height: 12),
          _CompactActionButton(
            icon: Icons.emoji_events_rounded,
            label: 'Declare',
            isAccent: true,
            onTap: isMyTurn && gs.currentHand.length == 13 ? _onDeclare : null,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Game over screen
  // ─────────────────────────────────────────────────────────

  Widget _buildGameOverScreen(RummyGameState gs) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Trophy
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.emoji_events, size: 48, color: Colors.white),
          ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(width: 32),
          // Message + buttons
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gs.message,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
              ).animate().fade(delay: 300.ms).slideX(begin: 0.15),
              const SizedBox(height: 24),
              Row(
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
                  const SizedBox(width: 12),
                  _GlowButton(
                    label: 'EXIT',
                    icon: Icons.home_rounded,
                    gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
                    onTap: _leaveGame,
                  ),
                ],
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // Dialogs
  // ─────────────────────────────────────────────────────────

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave Game?', style: TextStyle(color: Colors.white)),
        content: const Text('Your progress will be lost.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('STAY', style: TextStyle(color: Color(0xFF00F2FE))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(ctx); _leaveGame(); },
            child: const Text('LEAVE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared UI components
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: gradient),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isAccent;

  const _CompactActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.35,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isAccent && enabled
                ? const Color(0xFFFF8008).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            border: Border.all(
              color: isAccent && enabled
                  ? const Color(0xFFFF8008).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isAccent && enabled
                    ? const Color(0xFFFFC837)
                    : Colors.white70,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isAccent && enabled
                      ? const Color(0xFFFFC837)
                      : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
