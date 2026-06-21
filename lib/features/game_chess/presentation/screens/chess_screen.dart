import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/core/providers/preferences_provider.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import '../../domain/models/chess_state.dart';
import '../../domain/providers/chess_provider.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/chess_clock_widget.dart';
import '../widgets/chess_piece_painter.dart';

class ChessScreen extends ConsumerStatefulWidget {
  final bool isNetworked;
  final bool isHost;

  const ChessScreen({
    super.key,
    this.isNetworked = false,
    this.isHost = false,
  });

  @override
  ConsumerState<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends ConsumerState<ChessScreen> {
  StreamSubscription? _networkSub;
  Timer? _timer;

  // Local settings for game setup
  bool _gameStarted = false;
  int _selectedMinutes = 5;
  int _selectedIncrement = 0;
  bool _autoRotate = true;
  bool _showCoordinates = true;
  
  // Network rematch flags
  bool _rematchRequestedByOpponent = false;
  bool _waitingForRematchApproval = false;
  bool _waitingForUndoApproval = false;

  @override
  void initState() {
    super.initState();
    if (widget.isNetworked) {
      _setupNetworkListeners();
      if (!widget.isHost) {
        // Client waits for 'chess_init' message from Host
        setState(() {
          _gameStarted = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _networkSub?.cancel();
    super.dispose();
  }

  void _setupNetworkListeners() {
    if (widget.isHost) {
      _networkSub = ref.read(tcpServerProvider).messageStream.listen(_handleHostMessage);
    } else {
      _networkSub = ref.read(tcpClientProvider).messageStream.listen(_handleClientMessage);
    }
  }

  // Timer startup (battery efficient: ticks once per second)
  void _startClockTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      ref.read(chessProvider.notifier).tickClock();
      
      // Authoritative host broadcasts state on timer updates too, to keep times in sync
      if (widget.isNetworked && widget.isHost) {
        _broadcastGameState();
      }
    });
  }

  /// ──── Network Message Handlers ────

  void _handleHostMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['type']) {
      case 'make_move':
        final from = msg['from'] as String;
        final to = msg['to'] as String;
        final promotion = msg['promotion'] as String?;
        
        final success = ref.read(chessProvider.notifier).executeMove(from, to, promotion);
        if (success) {
          _broadcastGameState();
        }
        break;
      case 'resign':
        final resigningColor = msg['color'] as String;
        ref.read(chessProvider.notifier).resign(resigningColor);
        _broadcastGameState();
        break;
      case 'draw_offer':
        _showDrawOfferDialog();
        break;
      case 'draw_respond':
        final accepted = msg['accepted'] as bool;
        if (accepted) {
          ref.read(chessProvider.notifier).declareDraw('Draw by Agreement');
          _broadcastGameState();
        } else {
          _showToast('Draw offer declined');
        }
        break;
      case 'rematch_request':
        setState(() {
          _rematchRequestedByOpponent = true;
        });
        _showToast('Opponent wants a rematch!');
        break;
      case 'rematch_accept':
        _restartGame();
        break;
      case 'undo_request':
        _showUndoRequestDialog();
        break;
      case 'undo_respond':
        final accepted = msg['accepted'] as bool;
        setState(() {
          _waitingForUndoApproval = false;
        });
        if (accepted) {
          final undone = ref.read(chessProvider.notifier).undoMove();
          if (undone) {
            _showToast('Move Undone');
            _broadcastGameState();
          }
        } else {
          _showToast('Undo request declined');
        }
        break;
      case 'client_disconnected':
        _showToast('Opponent disconnected from the game.');
        break;
    }
  }

  void _handleClientMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['type']) {
      case 'chess_init':
        final timeLimit = msg['timeLimit'] as int;
        final increment = msg['increment'] as int;
        final whiteName = msg['whiteName'] as String;
        final blackName = msg['blackName'] as String;
        
        _selectedMinutes = timeLimit ~/ 60;
        _selectedIncrement = increment;

        ref.read(chessProvider.notifier).initGame(
          whitePlayerName: whiteName,
          blackPlayerName: blackName,
          initialTimeSeconds: timeLimit,
          incrementSeconds: increment,
        );

        setState(() {
          _gameStarted = true;
        });
        _startClockTimer();
        break;
      case 'state_sync':
        final stateJson = msg['state'] as Map<String, dynamic>;
        final newState = ChessState.fromJson(stateJson);
        ref.read(chessProvider.notifier).syncState(newState);
        
        if (!_gameStarted) {
          setState(() {
            _gameStarted = true;
          });
          _startClockTimer();
        }
        break;
      case 'draw_offer':
        _showDrawOfferDialog();
        break;
      case 'draw_respond':
        final accepted = msg['accepted'] as bool;
        if (accepted) {
          _showToast('Draw offer accepted!');
        } else {
          _showToast('Draw offer declined');
        }
        break;
      case 'rematch_request':
        setState(() {
          _rematchRequestedByOpponent = true;
        });
        _showToast('Opponent wants a rematch!');
        break;
      case 'rematch_accept':
        setState(() {
          _rematchRequestedByOpponent = false;
          _waitingForRematchApproval = false;
        });
        break;
      case 'undo_request':
        _showUndoRequestDialog();
        break;
      case 'undo_respond':
        final accepted = msg['accepted'] as bool;
        setState(() {
          _waitingForUndoApproval = false;
        });
        if (accepted) {
          _showToast('Move Undone');
        } else {
          _showToast('Undo request declined');
        }
        break;
      case 'setup_sync':
        setState(() {
          _selectedMinutes = msg['minutes'] as int;
          _selectedIncrement = msg['increment'] as int;
        });
        break;
      case 'connection_lost':
        _showConnectionFailureDialog();
        break;
    }
  }

  /// ──── Game Actions & Broadcasts ────

  void _startGameLocal() {
    final timeLimit = _selectedMinutes * 60;
    ref.read(chessProvider.notifier).initGame(
      whitePlayerName: 'White Player',
      blackPlayerName: 'Black Player',
      initialTimeSeconds: timeLimit,
      incrementSeconds: _selectedIncrement,
    );
    setState(() {
      _gameStarted = true;
    });
    _startClockTimer();
  }

  void _startGameNetworkHost() {
    final players = ref.read(lobbyProvider);
    final localName = ref.read(usernameProvider);

    // Host is White, first client is Black
    final whiteName = localName.isNotEmpty ? localName : 'White (Host)';
    String blackName = 'Black (Guest)';

    if (players.length > 1) {
      final guest = players.firstWhere((p) => !p.isHost, orElse: () => players[1]);
      blackName = guest.name;
    }

    final timeLimit = _selectedMinutes * 60;
    
    // 1. Init locally
    ref.read(chessProvider.notifier).initGame(
      whitePlayerName: whiteName,
      blackPlayerName: blackName,
      initialTimeSeconds: timeLimit,
      incrementSeconds: _selectedIncrement,
    );

    // 2. Broadcast init parameters to client
    ref.read(tcpServerProvider).broadcastMessage({
      'type': 'chess_init',
      'timeLimit': timeLimit,
      'increment': _selectedIncrement,
      'whiteName': whiteName,
      'blackName': blackName,
    });

    setState(() {
      _gameStarted = true;
    });
    
    // 3. Start local clock timer
    _startClockTimer();
    
    // 4. Initial state sync broadcast
    _broadcastGameState();
  }

  void _broadcastGameState() {
    if (!widget.isNetworked || !widget.isHost) return;
    final chessState = ref.read(chessProvider);
    ref.read(tcpServerProvider).broadcastMessage({
      'type': 'state_sync',
      'state': chessState.toJson(),
    });
  }

  void _onSquareTapped(String square) {
    final localColor = _getLocalPlayerColor();
    ref.read(chessProvider.notifier).selectSquare(square, localColor);
  }

  void _makeNetworkMove(String from, String to, [String? promotion]) {
    if (widget.isHost) {
      // Host executes directly and broadcasts
      final success = ref.read(chessProvider.notifier).executeMove(from, to, promotion);
      if (success) {
        _broadcastGameState();
      }
    } else {
      // Client sends request to host
      ref.read(tcpClientProvider).sendMessage({
        'type': 'make_move',
        'from': from,
        'to': to,
        'promotion': promotion,
      });
    }
  }

  String _getLocalPlayerColor() {
    if (!widget.isNetworked) return ''; // Local pass and play, anyone can play on their turn
    return widget.isHost ? 'w' : 'b';
  }

  bool _isLocalTurn(String activeColor) {
    if (!widget.isNetworked) return true;
    final localColor = _getLocalPlayerColor();
    return localColor == activeColor;
  }

  bool _isSpectator() {
    if (!widget.isNetworked) return false;
    
    // Spectator is anyone who is not host (White) and not the guest player at index 1 (Black)
    final players = ref.watch(lobbyProvider);
    if (players.length <= 1) return false; // Lobby details still syncing
    
    final localName = ref.watch(usernameProvider);
    final host = players.firstWhere((p) => p.isHost, orElse: () => players.first);
    final opponent = players.firstWhere((p) => !p.isHost, orElse: () => players.last);

    return localName != host.name && localName != opponent.name;
  }

  void _handleResign() {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(chessProvider.notifier).resign('w');
        _broadcastGameState();
      } else {
        ref.read(tcpClientProvider).sendMessage({
          'type': 'resign',
          'color': 'b',
        });
      }
    } else {
      final activeColor = ref.read(chessProvider).activeColor;
      ref.read(chessProvider.notifier).resign(activeColor);
    }
  }

  void _offerDraw() {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(tcpServerProvider).broadcastMessage({'type': 'draw_offer'});
      } else {
        ref.read(tcpClientProvider).sendMessage({'type': 'draw_offer'});
      }
      _showToast('Draw offer sent to opponent');
    } else {
      // Pass-and-play draw
      ref.read(chessProvider.notifier).declareDraw('Draw by Agreement');
    }
  }

  void _respondToDrawOffer(bool accept) {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(tcpServerProvider).broadcastMessage({
          'type': 'draw_respond',
          'accepted': accept,
        });
        if (accept) {
          ref.read(chessProvider.notifier).declareDraw('Draw by Agreement');
          _broadcastGameState();
        }
      } else {
        ref.read(tcpClientProvider).sendMessage({
          'type': 'draw_respond',
          'accepted': accept,
        });
      }
    }
  }

  void _requestRematch() {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(tcpServerProvider).broadcastMessage({'type': 'rematch_request'});
      } else {
        ref.read(tcpClientProvider).sendMessage({'type': 'rematch_request'});
      }
      setState(() {
        _waitingForRematchApproval = true;
      });
      _showToast('Rematch request sent');
    } else {
      _restartGame();
    }
  }

  void _acceptRematch() {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(tcpServerProvider).broadcastMessage({'type': 'rematch_accept'});
        _restartGame();
      } else {
        ref.read(tcpClientProvider).sendMessage({'type': 'rematch_accept'});
        setState(() {
          _rematchRequestedByOpponent = false;
        });
      }
    }
  }

  void _restartGame() {
    setState(() {
      _rematchRequestedByOpponent = false;
      _waitingForRematchApproval = false;
    });
    
    if (widget.isNetworked) {
      if (widget.isHost) {
        _startGameNetworkHost();
      }
    } else {
      _startGameLocal();
    }
  }

  void _leaveGame() {
    _timer?.cancel();
    _networkSub?.cancel();
    if (widget.isNetworked) {
      resetNetworkProviders(ref);
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// ──── Helper dialogs ────

  void _showConnectionFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Connection Lost'),
        content: const Text('Lost connection to the host. Please exit the game.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGame();
            },
            child: const Text('Exit Game'),
          ),
        ],
      ),
    );
  }

  void _showUndoRequestDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Undo Request'),
        content: const Text('Opponent wants to undo the last move. Do you accept?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToUndoRequest(false);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToUndoRequest(true);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _respondToUndoRequest(bool accept) {
    if (widget.isNetworked) {
      if (widget.isHost) {
        ref.read(tcpServerProvider).broadcastMessage({
          'type': 'undo_respond',
          'accepted': accept,
        });
        if (accept) {
          final undone = ref.read(chessProvider.notifier).undoMove();
          if (undone) {
            _showToast('Move Undone');
            _broadcastGameState();
          }
        }
      } else {
        ref.read(tcpClientProvider).sendMessage({
          'type': 'undo_respond',
          'accepted': accept,
        });
      }
    }
  }

  void _requestUndo() {
    if (!widget.isNetworked) {
      final undone = ref.read(chessProvider.notifier).undoMove();
      if (undone) _showToast('Move Undone');
      return;
    }

    if (_waitingForUndoApproval || _waitingForRematchApproval) return;

    setState(() {
      _waitingForUndoApproval = true;
    });

    if (widget.isHost) {
      ref.read(tcpServerProvider).broadcastMessage({'type': 'undo_request'});
    } else {
      ref.read(tcpClientProvider).sendMessage({'type': 'undo_request'});
    }
    _showToast('Undo request sent');
  }

  void _showDrawOfferDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Draw Offer'),
        content: const Text('Opponent is offering a draw. Do you accept?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToDrawOffer(false);
            },
            child: const Text('Decline'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _respondToDrawOffer(true);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// ──── UI Builders ────

  int _calculateMaterialAdvantage(List<String> myCaptures, List<String> oppCaptures) {
    const values = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9, 'k': 0};
    int myScore = myCaptures.fold(0, (sum, p) => sum + (values[p.toLowerCase()] ?? 0));
    int oppScore = oppCaptures.fold(0, (sum, p) => sum + (values[p.toLowerCase()] ?? 0));
    return myScore - oppScore;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chessProvider);
    final isSpectator = _isSpectator();

    ref.listen<ChessState>(chessProvider, (previous, current) {
      if (previous == null) return;
      if (!previous.isGameOver && current.isGameOver) {
        HapticFeedback.vibrate();
      } else if (!previous.isCheck && current.isCheck) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);
      } else if (previous.moveHistory.length < current.moveHistory.length) {
        int prevCaptures = previous.capturedWhitePieces.length + previous.capturedBlackPieces.length;
        int currCaptures = current.capturedWhitePieces.length + current.capturedBlackPieces.length;
        if (currCaptures > prevCaptures) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
        } else {
          HapticFeedback.lightImpact();
          SystemSound.play(SystemSoundType.click);
        }
      }
    });

    int whiteMaterial = _calculateMaterialAdvantage(state.capturedBlackPieces, state.capturedWhitePieces);
    int blackMaterial = -whiteMaterial;
    
    int topMaterialAdvantage = isFlipped ? whiteMaterial : blackMaterial;
    int bottomMaterialAdvantage = isFlipped ? blackMaterial : whiteMaterial;

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
          child: Column(
            children: [
              // Header/App bar
              _buildHeader(state),
              
              if (!_gameStarted)
                Expanded(child: _buildSetupPanel())
              else ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Opponent Clock (Black in normal view, White if flipped)
                      ChessClockWidget(
                        playerName: isFlipped ? state.whitePlayerName : state.blackPlayerName,
                        timeRemaining: isFlipped ? state.whiteTimeRemaining : state.blackTimeRemaining,
                        isActive: isFlipped ? (state.activeColor == 'w') : (state.activeColor == 'b'),
                        isWhite: isFlipped,
                        capturedPieces: isFlipped ? state.capturedBlackPieces : state.capturedWhitePieces,
                        materialAdvantage: topMaterialAdvantage,
                        isTimed: state.isTimed,
                        isFlipped: true, // rotated upside down for top display
                      ),

                      const SizedBox(height: 12),

                      // Main Board View
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Stack(
                            children: [
                              ChessBoardWidget(
                                boardFen: state.boardFen,
                                selectedSquare: state.selectedSquare,
                                validMoves: state.validMovesForSelected,
                                lastMoveFrom: state.lastMoveFrom,
                                lastMoveTo: state.lastMoveTo,
                                isCheck: state.isCheck,
                                isFlipped: isFlipped,
                                activeColor: state.activeColor,
                                rotateOpponentPieces: !widget.isNetworked,
                                showCoordinates: _showCoordinates,
                                onSquareTap: (square) {
                                  if (isSpectator) return;
                                  
                                  // In networked mode, client handles promotions differently
                                  final isPawn = state.selectedSquare != null &&
                                      ref.read(chessProvider.notifier).isPawn(state.selectedSquare!);
                                  final isPromoRank = square[1] == '8' || square[1] == '1';
                                  
                                  if (widget.isNetworked &&
                                      _isLocalTurn(state.activeColor) &&
                                      state.validMovesForSelected.contains(square) &&
                                      isPawn && isPromoRank) {
                                    // Trigger promotion dialog locally, then execute networks move
                                    _showPromotionSelectionDialog(square);
                                  } else {
                                    _onSquareTapped(square);
                                    
                                    // If a move was executed (turn changed), sync it if networked
                                    if (widget.isNetworked &&
                                        state.selectedSquare != null &&
                                        state.validMovesForSelected.contains(square)) {
                                      _makeNetworkMove(state.selectedSquare!, square);
                                    }
                                  }
                                },
                              ),

                              // Promotion selection overlay
                              if (state.isPromotionPending && !widget.isNetworked)
                                _buildPromotionOverlay(state),

                              // Game Over overlay
                              if (state.isGameOver) _buildGameOverOverlay(state),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Local Clock (White in normal view, Black if flipped)
                      ChessClockWidget(
                        playerName: isFlipped ? state.blackPlayerName : state.whitePlayerName,
                        timeRemaining: isFlipped ? state.blackTimeRemaining : state.whiteTimeRemaining,
                        isActive: isFlipped ? (state.activeColor == 'b') : (state.activeColor == 'w'),
                        isWhite: !isFlipped,
                        capturedPieces: isFlipped ? state.capturedWhitePieces : state.capturedBlackPieces,
                        materialAdvantage: bottomMaterialAdvantage,
                        isTimed: state.isTimed,
                        isFlipped: false,
                      ),
                    ],
                  ),
                ),
                
                // Move history panel and controls
                _buildControlBar(state, isSpectator),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Flipped board logic:
  // Flipped when local player plays black (isNetworked & !isHost)
  // OR when pass-and-play turn auto-rotation is enabled and turn is Black
  bool get isFlipped {
    if (widget.isNetworked) {
      return !widget.isHost;
    }
    final state = ref.read(chessProvider);
    return _autoRotate && state.activeColor == 'b';
  }

  Widget _buildHeader(ChessState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _showExitConfirmation,
          ),
          Text(
            widget.isNetworked
                ? (widget.isHost ? 'Chess (Host)' : 'Chess (Client)')
                : 'Chess (Local)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (_gameStarted &&
              !state.isGameOver &&
              (!widget.isNetworked ||
                  (widget.isNetworked &&
                      !_isSpectator() &&
                      state.moveHistory.isNotEmpty)))
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.white),
              onPressed: _requestUndo,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Screen for selecting time control before starting
  Widget _buildSetupPanel() {
    final players = ref.watch(lobbyProvider);
    final opponentName = widget.isNetworked && players.length > 1
        ? players.firstWhere((p) => !p.isHost).name
        : 'Opponent';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.grid_goldenratio, size: 72, color: Color(0xFF00F2FE))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(duration: 1500.ms, begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1)),
            const SizedBox(height: 16),
            const Text(
              'Game Settings',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 40),
            
            // Time control selector
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Time Control Limit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // Quick presets
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPresetChip(1, 0, '1 min (Bullet)'),
                      _buildPresetChip(3, 0, '3 min (Blitz)'),
                      _buildPresetChip(3, 2, '3+2 (Blitz)'),
                      _buildPresetChip(5, 0, '5 min (Blitz)'),
                      _buildPresetChip(10, 0, '10 min (Rapid)'),
                      _buildPresetChip(0, 0, 'Unlimited'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Custom sliders
                  if (_selectedMinutes > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Minutes: $_selectedMinutes', style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 60,
                            divisions: 59,
                            value: _selectedMinutes.toDouble(),
                            activeColor: const Color(0xFF00F2FE),
                            onChanged: (widget.isNetworked && !widget.isHost) ? null : (val) {
                              setState(() {
                                _selectedMinutes = val.toInt();
                              });
                              if (widget.isNetworked && widget.isHost) {
                                ref.read(tcpServerProvider).broadcastMessage({
                                  'type': 'setup_sync',
                                  'minutes': _selectedMinutes,
                                  'increment': _selectedIncrement,
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Increment (sec): $_selectedIncrement', style: const TextStyle(color: Colors.white)),
                        Expanded(
                          child: Slider(
                            min: 0,
                            max: 30,
                            divisions: 30,
                            value: _selectedIncrement.toDouble(),
                            activeColor: const Color(0xFF00F2FE),
                            onChanged: (widget.isNetworked && !widget.isHost) ? null : (val) {
                              setState(() {
                                _selectedIncrement = val.toInt();
                              });
                              if (widget.isNetworked && widget.isHost) {
                                ref.read(tcpServerProvider).broadcastMessage({
                                  'type': 'setup_sync',
                                  'minutes': _selectedMinutes,
                                  'increment': _selectedIncrement,
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Pass-and-play settings
            if (!widget.isNetworked)
              SwitchListTile(
                title: const Text('Auto-Rotate Board', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Flips the board upside down after each move', style: TextStyle(color: Colors.grey, fontSize: 12)),
                value: _autoRotate,
                activeTrackColor: const Color(0xFF00F2FE),
                onChanged: (val) {
                  setState(() {
                    _autoRotate = val;
                  });
                },
              ),

            SwitchListTile(
              title: const Text('Show Coordinates', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Display algebraic coordinates on the board', style: TextStyle(color: Colors.grey, fontSize: 12)),
              value: _showCoordinates,
              activeTrackColor: const Color(0xFF00F2FE),
              onChanged: (val) {
                setState(() {
                  _showCoordinates = val;
                });
              },
            ),

            const SizedBox(height: 40),
            
            // Play Button
            if (!widget.isNetworked || widget.isHost)
              SizedBox(
                width: 250,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: widget.isNetworked ? _startGameNetworkHost : _startGameLocal,
                  icon: const Icon(Icons.play_arrow, color: Colors.black),
                  label: const Text('START GAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00F2FE),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ).animate().fade().scale()
            else
              // Client is waiting
              Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00F2FE)),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for host $opponentName to start...',
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
          ],
        ),
      ),
    ).animate().fade();
  }

  Widget _buildPresetChip(int mins, int inc, String label) {
    final isSelected = _selectedMinutes == mins && _selectedIncrement == inc;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (widget.isNetworked && !widget.isHost) ? null : (val) {
        if (val) {
          setState(() {
            _selectedMinutes = mins;
            _selectedIncrement = inc;
          });
          if (widget.isNetworked && widget.isHost) {
            ref.read(tcpServerProvider).broadcastMessage({
              'type': 'setup_sync',
              'minutes': mins,
              'increment': inc,
            });
          }
        }
      },
      selectedColor: const Color(0xFF00F2FE),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
    );
  }

  /// Custom bottom control bar containing Move History & Resign/Draw options
  Widget _buildControlBar(ChessState state, bool isSpectator) {
    final String turnIndicator = state.activeColor == 'w' ? "White's Turn" : "Black's Turn";
    final bool isMyTurn = _isLocalTurn(state.activeColor) && !isSpectator;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.isGameOver ? 'Game Over' : (isSpectator ? 'Spectating' : (isMyTurn ? 'Your Turn' : "Opponent's Turn")),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isMyTurn && !state.isGameOver ? const Color(0xFF00F2FE) : Colors.white,
                ),
              ),
              Text(
                turnIndicator,
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // History Display
          if (state.moveHistory.isNotEmpty)
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (state.moveHistory.length / 2).ceil(),
                itemBuilder: (context, index) {
                  int moveNum = index + 1;
                  int wIndex = index * 2;
                  int bIndex = wIndex + 1;
                  String wMove = state.moveHistory[wIndex];
                  String bMove = bIndex < state.moveHistory.length ? state.moveHistory[bIndex] : '';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Center(
                      child: Text(
                        '$moveNum. $wMove $bMove',
                        style: const TextStyle(color: Colors.white70, fontFamily: 'monospace'),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Action Buttons: Resign, Draw, Offer Draw
          if (!state.isGameOver && !isSpectator)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showResignConfirmation,
                    icon: const Icon(Icons.flag, size: 18),
                    label: const Text('Resign'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _offerDraw,
                    icon: const Icon(Icons.handshake, size: 18),
                    label: const Text('Offer Draw'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      side: const BorderSide(color: Colors.amberAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            
          // If spectating, show indicator
          if (isSpectator)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'You are spectating this match',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Promotion selection popup widget for local pass and play
  Widget _buildPromotionOverlay(ChessState state) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Promote Pawn',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPromoOption('q', Icons.star),
                  _buildPromoOption('r', Icons.castle),
                  _buildPromoOption('b', Icons.shield),
                  _buildPromoOption('n', Icons.psychology),
                ],
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  ref.read(chessProvider.notifier).cancelPromotion();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoOption(String pieceType, IconData icon) {
    final activeColor = ref.read(chessProvider).activeColor;
    return GestureDetector(
      onTap: () {
        ref.read(chessProvider.notifier).selectPromotion(pieceType);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Center(
          child: ChessPieceWidget(
            type: pieceType,
            color: activeColor,
            size: 32,
          ),
        ),
      ),
    );
  }

  /// Helper to trigger promotion selector dialog on client/networked mode
  void _showPromotionSelectionDialog(String targetSquare) {
    final activeColor = ref.read(chessProvider).activeColor;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Promotion Piece'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['q', 'r', 'b', 'n'].map((type) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                final from = ref.read(chessProvider).selectedSquare!;
                _makeNetworkMove(from, targetSquare, type);
                ref.read(chessProvider.notifier).cancelPromotion(); // clear selection locally
              },
              child: Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Center(
                  child: ChessPieceWidget(
                    type: type,
                    color: activeColor,
                    size: 36,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(chessProvider.notifier).cancelPromotion();
            },
            child: const Text('Cancel'),
          )
        ],
      ),
    );
  }

  /// Game Over overlay widget showing the results and rematch triggers
  Widget _buildGameOverOverlay(ChessState state) {
    final winnerText = state.winnerColor == 'draw'
        ? 'Draw Game'
        : (state.winnerColor == 'w' ? '${state.whitePlayerName} Wins!' : '${state.blackPlayerName} Wins!');
    
    final reasonText = state.gameOverReason ?? 'Finished';
    
    // Display different buttons based on networked or local mode
    Widget actionButtons;
    if (widget.isNetworked) {
      if (_rematchRequestedByOpponent) {
        actionButtons = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _acceptRematch,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43E97B)),
              child: const Text('Accept Rematch', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      } else if (_waitingForRematchApproval) {
        actionButtons = const Column(
          children: [
            CircularProgressIndicator(color: Color(0xFF00F2FE)),
            SizedBox(height: 8),
            Text('Waiting for opponent approval...', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        );
      } else {
        actionButtons = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _requestRematch,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE)),
              child: const Text('Request Rematch', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      }
    } else {
      actionButtons = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _restartGame,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FE)),
            child: const Text('Play Again', style: TextStyle(color: Colors.black)),
          ),
        ],
      );
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 56)
                  .animate()
                  .fade()
                  .scale(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 16),
              Text(
                winnerText,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'By $reasonText',
                style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.6)),
              ).animate().fade(delay: 300.ms),
              const SizedBox(height: 32),
              
              actionButtons,
              
              const SizedBox(height: 12),
              TextButton(
                onPressed: _leaveGame,
                child: const Text('Leave Game', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    if (!_gameStarted || ref.read(chessProvider).isGameOver) {
      _leaveGame();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Game?'),
        content: const Text('Are you sure you want to exit? The game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGame();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Exit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResignConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign and forfeit the match?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleResign();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Resign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
