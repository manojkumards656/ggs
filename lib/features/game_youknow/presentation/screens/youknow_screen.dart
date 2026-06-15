import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/providers/network_providers.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../host/providers/lobby_provider.dart';
import '../../domain/models/youknow_card.dart';
import '../../domain/models/youknow_state.dart';
import '../../domain/providers/youknow_provider.dart';
import '../widgets/youknow_card_widget.dart';
import '../widgets/wild_color_dialog.dart';

class YouKnowScreen extends ConsumerStatefulWidget {
  final bool isNetworked;
  final bool isHost;

  const YouKnowScreen({
    super.key,
    this.isNetworked = false,
    this.isHost = false,
  });

  @override
  ConsumerState<YouKnowScreen> createState() => _YouKnowScreenState();
}

class _YouKnowScreenState extends ConsumerState<YouKnowScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _tcpSub;
  
  // Local Pass & Play config controllers
  final List<TextEditingController> _playerNames = [];
  
  // Turn direction rotation controller
  late final AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupGame();
    });
  }

  @override
  void dispose() {
    _tcpSub?.cancel();
    _rotationController.dispose();
    for (final controller in _playerNames) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setupGame() {
    if (widget.isNetworked) {
      if (widget.isHost) {
        // Fetch players from Lobby
        final lobbyPlayers = ref.read(lobbyProvider);
        final playersList = lobbyPlayers.map((p) => {
          'id': p.id,
          'name': p.name,
        }).toList();

        // Init Game on Host
        ref.read(youknowStateProvider.notifier).initGame(playersList, isNetworked: true);
        _broadcastState();

        // Listen for client commands
        final tcpServer = ref.read(tcpServerProvider);
        _tcpSub = tcpServer.messageStream.listen((msg) {
          _handleHostMessage(msg);
        });
      } else {
        // Client listens for host updates
        final tcpClient = ref.read(tcpClientProvider);
        _tcpSub = tcpClient.messageStream.listen((msg) {
          _handleClientMessage(msg);
        });
      }
    } else {
      // Pass & Play mode initialization
      final currentUsername = ref.read(usernameProvider);
      _playerNames.clear();
      _playerNames.add(TextEditingController(text: currentUsername.isNotEmpty ? currentUsername : 'Player 1'));
      _playerNames.add(TextEditingController(text: 'Player 2'));
    }
  }

  // ── Network Message Handling ──

  void _handleHostMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    final type = msg['type'];
    final notifier = ref.read(youknowStateProvider.notifier);

    switch (type) {
      case 'youknow_play':
        final colorName = msg['chosenWildColor'] as String?;
        final chosenColor = colorName != null 
            ? YouKnowColor.values.firstWhere((e) => e.name == colorName)
            : null;
        notifier.playCard(msg['playerId'], msg['cardId'], chosenWildColor: chosenColor);
        _broadcastState();
        break;

      case 'youknow_draw':
        notifier.drawCard(msg['playerId']);
        _broadcastState();
        break;

      case 'youknow_pass':
        notifier.passTurn(msg['playerId']);
        _broadcastState();
        break;

      case 'youknow_declare':
        notifier.declareYouKnow(msg['playerId']);
        _broadcastState();
        break;

      case 'youknow_catch':
        notifier.catchPlayer(msg['catcherId']);
        _broadcastState();
        break;
    }
  }

  void _handleClientMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    if (msg['type'] == 'youknow_state') {
      final newState = YouKnowState.fromJson(msg['state']);
      ref.read(youknowStateProvider.notifier).setState(newState);
    }
  }

  void _broadcastState() {
    if (widget.isNetworked && widget.isHost) {
      final state = ref.read(youknowStateProvider);
      ref.read(tcpServerProvider).broadcastMessage({
        'type': 'youknow_state',
        'state': state.toJson(),
      });
    }
  }

  // Send action to server (client side)
  void _sendClientAction(Map<String, dynamic> action) {
    ref.read(tcpClientProvider).sendMessage(action);
  }

  // ── Player Actions Wrapper (Handles Host vs Client vs Pass&Play routing) ──

  void _playCard(String playerId, String cardId, YouKnowCard card) async {
    // If wild, prompt color dialog
    YouKnowColor? selectedColor;
    if (card.isWild) {
      selectedColor = await showDialog<YouKnowColor>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const WildColorDialog(),
      );
      if (selectedColor == null) return; // cancelled selection
    }

    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(youknowStateProvider.notifier).playCard(playerId, cardId, chosenWildColor: selectedColor);
        _broadcastState();
      } else {
        _sendClientAction({
          'type': 'youknow_play',
          'playerId': playerId,
          'cardId': cardId,
          'chosenWildColor': selectedColor?.name,
        });
      }
    } else {
      ref.read(youknowStateProvider.notifier).playCard(playerId, cardId, chosenWildColor: selectedColor);
    }
  }

  void _drawCard(String playerId) {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(youknowStateProvider.notifier).drawCard(playerId);
        _broadcastState();
      } else {
        _sendClientAction({
          'type': 'youknow_draw',
          'playerId': playerId,
        });
      }
    } else {
      ref.read(youknowStateProvider.notifier).drawCard(playerId);
    }
  }

  void _passTurn(String playerId) {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(youknowStateProvider.notifier).passTurn(playerId);
        _broadcastState();
      } else {
        _sendClientAction({
          'type': 'youknow_pass',
          'playerId': playerId,
        });
      }
    } else {
      ref.read(youknowStateProvider.notifier).passTurn(playerId);
    }
  }

  void _declareYouKnow(String playerId) {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(youknowStateProvider.notifier).declareYouKnow(playerId);
        _broadcastState();
      } else {
        _sendClientAction({
          'type': 'youknow_declare',
          'playerId': playerId,
        });
      }
    } else {
      ref.read(youknowStateProvider.notifier).declareYouKnow(playerId);
    }
  }

  void _catchPlayer(String catcherId) {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(youknowStateProvider.notifier).catchPlayer(catcherId);
        _broadcastState();
      } else {
        _sendClientAction({
          'type': 'youknow_catch',
          'catcherId': catcherId,
        });
      }
    } else {
      ref.read(youknowStateProvider.notifier).catchPlayer(catcherId);
    }
  }

  void _resetGame() {
    if (widget.isNetworked) {
      if (widget.isHost) {
        _setupGame();
      }
    } else {
      final names = _playerNames.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
      if (names.length < 2) return;
      ref.read(youknowStateProvider.notifier).initGame(
        names.map((n) => {'name': n}).toList(),
        isNetworked: false,
      );
    }
  }

  // ── Render Helpers ──

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(youknowStateProvider);

    // If game has not started yet in Pass & Play, show the lobby config
    if (!widget.isNetworked && state.status == YouKnowStatus.lobby) {
      return _buildLocalLobbyScreen();
    }

    // Pass & Play screen concealment screen
    if (!widget.isNetworked && state.status == YouKnowStatus.revealingTurn) {
      return _buildPassAndPlayRevealScreen(state);
    }

    // Determine the local player object
    final myUsername = ref.watch(usernameProvider);
    final YouKnowPlayer myPlayer;
    if (widget.isNetworked) {
      myPlayer = state.players.firstWhere(
        (p) => p.name == myUsername,
        orElse: () => state.players.isNotEmpty ? state.players[0] : const YouKnowPlayer(id: '', name: ''),
      );
    } else {
      // In Pass & Play, the active player is the one whose hand we show
      myPlayer = state.players.isNotEmpty ? state.currentPlayer : const YouKnowPlayer(id: '', name: '');
    }

    final isMyTurn = state.players.isNotEmpty && state.currentPlayer.id == myPlayer.id;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D0C1D), Color(0xFF1B1A35), Color(0xFF111026)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar & Action Log Banner
              _buildTopBar(state),
              
              // Opponents View
              _buildOpponentsPanel(state, myPlayer.id),

              const Spacer(),

              // Center Board: Draw pile + Discard pile + direction indicator
              if (state.players.isNotEmpty)
                _buildCenterBoard(state, myPlayer.id, isMyTurn),

              const Spacer(),

              // Quick Actions Bar (Shout, Catch, Pass)
              if (state.players.isNotEmpty)
                _buildQuickActionsBar(state, myPlayer.id, isMyTurn),

              const SizedBox(height: 12),

              // Player Hand
              if (state.players.isNotEmpty)
                _buildPlayerHand(state, myPlayer, isMyTurn),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── 1. Pass & Play Configuration Lobby ──
  Widget _buildLocalLobbyScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('YouKnow Setup', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                'Add Players (2 - 4)',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _playerNames.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _playerNames[index],
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Player ${index + 1}',
                                labelStyle: const TextStyle(color: Colors.white70),
                                filled: true,
                                fillColor: Colors.white10,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if (_playerNames.length > 2)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () {
                                setState(() {
                                  _playerNames[index].dispose();
                                  _playerNames.removeAt(index);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_playerNames.length < 4)
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _playerNames.add(TextEditingController(text: 'Player ${_playerNames.length + 1}'));
                    });
                  },
                  icon: const Icon(Icons.add, color: Colors.cyanAccent),
                  label: const Text('Add Player', style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.cyanAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    final names = _playerNames.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                    if (names.length < 2) return;
                    ref.read(youknowStateProvider.notifier).initGame(
                      names.map((n) => {'name': n}).toList(),
                      isNetworked: false,
                    );
                  },
                  child: Text(
                    'DEAL CARDS',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 2. Pass & Play Reveal concealment screen ──
  Widget _buildPassAndPlayRevealScreen(YouKnowState state) {
    final name = state.currentPlayer.name;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C1B),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_android_rounded, size: 100, color: Colors.amber)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .slideY(begin: -0.1, end: 0.1, duration: 1500.ms, curve: Curves.easeInOut)
                  .rotate(begin: -0.05, end: 0.05),
              const SizedBox(height: 40),
              Text(
                'Pass the phone to',
                style: GoogleFonts.outfit(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                name.toUpperCase(),
                style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
              ).animate().scale(curve: Curves.elasticOut, duration: 800.ms),
              const SizedBox(height: 24),
              Text(
                'Tap the button below when you are ready to reveal your hand privately.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white30),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    ref.read(youknowStateProvider.notifier).revealHand();
                  },
                  child: Text(
                    'REVEAL MY HAND',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ).animate().shimmer(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  // ── 3. Top bar and Action log ──
  Widget _buildTopBar(YouKnowState state) {
    final activeColor = state.activeWildColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const Spacer(),
              Text(
                'YouKnow',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              // Reset / Re-deal (only for pass and play, or host)
              if (!widget.isNetworked || widget.isHost)
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _resetGame,
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Action banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.lastActionMessage,
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.white70),
                  ),
                ),
                if (activeColor != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: activeColor.colorValue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MATCH: ${activeColor.displayName.toUpperCase()}',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ).animate().scale().fade(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Opponents Panel ──
  Widget _buildOpponentsPanel(YouKnowState state, String myPlayerId) {
    // Filter out our own player
    final opponents = state.players.where((p) => p.id != myPlayerId).toList();

    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: opponents.length,
        itemBuilder: (context, index) {
          final p = opponents[index];
          final isPlayerTurn = state.players[state.currentPlayerIndex].id == p.id;
          final isVulnerable = state.vulnerablePlayerId == p.id;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isPlayerTurn
                  ? const Color(0xFF1E88E5).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPlayerTurn 
                    ? const Color(0xFF1E88E5) 
                    : (isVulnerable ? Colors.amber : Colors.white10),
                width: isPlayerTurn || isVulnerable ? 2 : 1,
              ),
              boxShadow: [
                if (isPlayerTurn)
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
                    blurRadius: 8,
                  ),
                if (isVulnerable)
                  const BoxShadow(
                    color: Colors.amberAccent,
                    blurRadius: 10,
                  )
              ],
            ),
            child: Row(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: isPlayerTurn ? FontWeight.bold : FontWeight.normal,
                        color: isPlayerTurn ? Colors.white : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.layers_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${p.cards.length} cards',
                          style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isVulnerable) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.warning, color: Colors.amber, size: 24)
                      .animate(onPlay: (controller) => controller.repeat())
                      .shake(duration: 800.ms),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 5. Center Board ──
  Widget _buildCenterBoard(YouKnowState state, String myPlayerId, bool isMyTurn) {
    final topCard = state.discardPile.isNotEmpty ? state.topDiscardCard : null;
    final int deckSize = state.deck.length;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Direction Spinner
          RotationTransition(
            turns: state.isClockwise ? _rotationController : ReverseAnimation(_rotationController),
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.15),
                  width: 6,
                  style: BorderStyle.solid,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 110,
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.cyanAccent.withValues(alpha: 0.6), size: 20),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 110,
                    child: Icon(Icons.arrow_back_rounded, color: Colors.cyanAccent.withValues(alpha: 0.6), size: 20),
                  ),
                ],
              ),
            ),
          ),
          // Deck and Discard
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Draw Pile
              Column(
                children: [
                  YouKnowCardWidget(
                    card: const YouKnowCard(id: 'back', color: YouKnowColor.wild, value: YouKnowValue.wild),
                    faceUp: false,
                    isPlayable: isMyTurn && !_hasPlayableCards(state, myPlayerId),
                    width: 95,
                    height: 140,
                    onTap: isMyTurn ? () => _drawCard(myPlayerId) : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'DRAW ($deckSize)',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              // Discard Pile
              Column(
                children: [
                  if (topCard != null)
                    YouKnowCardWidget(
                      card: topCard,
                      faceUp: true,
                      isPlayable: false,
                      width: 95,
                      height: 140,
                    )
                  else
                    Container(
                      width: 95,
                      height: 140,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    'DISCARD',
                    style: GoogleFonts.outfit(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper to check if a player has any valid play in their hand
  bool _hasPlayableCards(YouKnowState state, String playerId) {
    final playerIndex = state.players.indexWhere((p) => p.id == playerId);
    if (playerIndex == -1) return false;
    final player = state.players[playerIndex];
    return player.cards.any((c) => c.isPlayableOn(state.topDiscardCard, state.activeWildColor));
  }

  // ── 6. Quick Actions Bar ──
  Widget _buildQuickActionsBar(YouKnowState state, String myPlayerId, bool isMyTurn) {
    final player = state.players.firstWhere((p) => p.id == myPlayerId, orElse: () => state.players[0]);
    final handSize = player.cards.length;

    // Vulnerable status check
    final vulnerableId = state.vulnerablePlayerId;
    final bool canCatch = vulnerableId != null && vulnerableId != myPlayerId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // "YOUKNOW!" Shout Button (Flashes when we have 2 cards and it's our turn)
          if (isMyTurn && handSize == 2 && !player.hasDeclaredYouKnow)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _declareYouKnow(myPlayerId),
              icon: const Icon(Icons.volume_up, size: 20),
              label: Text(
                'SHOUT YOUKNOW!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(
                  begin: 1.0,
                  end: 1.08,
                  duration: 600.ms,
                )
          else if (player.hasDeclaredYouKnow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'YOUKNOW DECLARED',
                    style: GoogleFonts.outfit(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),

          // "CATCH" Button (if someone forgot to shout and we can call them out)
          if (canCatch)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _catchPlayer(myPlayerId),
              icon: const Icon(Icons.gavel, size: 20),
              label: Text(
                'CATCH OPPONENT!',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ).animate(onPlay: (controller) => controller.repeat()).shake(duration: 800.ms),

          // "PASS TURN" Button (if we drew a card and want to pass)
          // To implement pass, we allow it if they have no playable cards but have already drawn (dealt with in provider logic)
          // Here, we can display a pass button if it's my turn and I've drawn a card.
          // For safety, we show it if they want to explicitly pass after drawing.
          if (isMyTurn)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _passTurn(myPlayerId),
              icon: const Icon(Icons.chevron_right, color: Colors.white70),
              label: Text(
                'PASS',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  // ── 7. Player Hand ──
  Widget _buildPlayerHand(YouKnowState state, YouKnowPlayer player, bool isMyTurn) {
    final cards = player.cards;

    if (state.status == YouKnowStatus.gameOver) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GAME OVER',
              style: GoogleFonts.outfit(fontSize: 18, color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.winnerName} won the game!',
              style: GoogleFonts.outfit(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
          child: Text(
            isMyTurn ? 'YOUR HAND' : '${player.name.toUpperCase()}\'S HAND (VIEWING ONLY)',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMyTurn ? Colors.cyanAccent : Colors.white30,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 160,
          child: cards.isEmpty
              ? Center(
                  child: Text(
                    'No cards left!',
                    style: GoogleFonts.outfit(color: Colors.white24, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    final bool isCardPlayable = isMyTurn && card.isPlayableOn(state.topDiscardCard, state.activeWildColor);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8),
                      child: Center(
                        child: YouKnowCardWidget(
                          card: card,
                          faceUp: true,
                          isPlayable: isCardPlayable,
                          width: 90,
                          height: 135,
                          onTap: isCardPlayable ? () => _playCard(player.id, card.id, card) : null,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
