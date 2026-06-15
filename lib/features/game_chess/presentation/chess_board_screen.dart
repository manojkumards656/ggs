import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/providers/chess_providers.dart';

class ChessBoardScreen extends ConsumerStatefulWidget {
  const ChessBoardScreen({super.key});

  @override
  ConsumerState<ChessBoardScreen> createState() => _ChessBoardScreenState();
}

class _ChessBoardScreenState extends ConsumerState<ChessBoardScreen> {
  ChessPosition? _selectedPosition;
  List<ChessPosition> _validMoves = [];

  // ── Timer state ──
  bool _timerEnabled = false;
  int _whiteMsRemaining = 0;
  int _blackMsRemaining = 0;
  int _selectedTimerMinutes = 10; // default preset
  Timer? _clockTimer;
  bool _timerStarted = false; // becomes true after white's first move

  // Stopwatch for sub-second interpolation — avoids needing 100ms callbacks
  // during the majority of the game. We only downgrade to fast ticks when
  // a player is under 20 seconds.
  final Stopwatch _stopwatch = Stopwatch();

  // ── Timer presets (minutes) ──
  static const List<int> _presets = [1, 3, 5, 10, 15, 30];

  @override
  void dispose() {
    _clockTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  Timer helpers
  // ─────────────────────────────────────────────

  void _startClock() {
    _clockTimer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();

    // Determine tick interval based on remaining time.
    // Under 20s: 100ms for tenths display. Otherwise: 1000ms (10x fewer callbacks).
    final activeMsRemaining = _getActiveMsRemaining();
    final interval = activeMsRemaining < 20000
        ? const Duration(milliseconds: 100)
        : const Duration(seconds: 1);



    _clockTimer = Timer.periodic(interval, (_) {
      if (!mounted) {
        _clockTimer?.cancel();
        _stopwatch.stop();
        return;
      }
      if (!_timerEnabled || !_timerStarted) return;

      final gameState = ref.read(chessGameStateProvider);
      if (gameState.isGameOver) {
        _clockTimer?.cancel();
        _stopwatch.stop();
        return;
      }

      final elapsed = _stopwatch.elapsedMilliseconds;
      _stopwatch.reset();
      _stopwatch.start();

      setState(() {
        if (gameState.currentTurn == ChessPieceColor.white) {
          _whiteMsRemaining -= elapsed;
          if (_whiteMsRemaining <= 0) {
            _whiteMsRemaining = 0;
            _clockTimer?.cancel();
            _stopwatch.stop();
            _handleTimeout(ChessPieceColor.white);
          }
        } else {
          _blackMsRemaining -= elapsed;
          if (_blackMsRemaining <= 0) {
            _blackMsRemaining = 0;
            _clockTimer?.cancel();
            _stopwatch.stop();
            _handleTimeout(ChessPieceColor.black);
          }
        }
      });

      // Dynamically switch to fast ticks when approaching low time
      // (moved outside setState to avoid recursive call inside setState callback)
      final currentMs = _getActiveMsRemaining();
      if (currentMs < 20000 && interval.inMilliseconds > 100) {
        _startClock(); // Restart with faster interval
      }
    });
  }

  int _getActiveMsRemaining() {
    final gameState = ref.read(chessGameStateProvider);
    return gameState.currentTurn == ChessPieceColor.white
        ? _whiteMsRemaining
        : _blackMsRemaining;
  }

  void _handleTimeout(ChessPieceColor loser) {
    final winner = loser == ChessPieceColor.white ? 'Black' : 'White';
    // Force game over by showing a dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('⏱ Time\'s Up!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Text(
          '$winner wins on time!',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetAll();
            },
            child: const Text('New Game', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _resetAll() {
    _clockTimer?.cancel();
    ref.read(chessGameStateProvider.notifier).resetGame();
    setState(() {
      _selectedPosition = null;
      _validMoves = [];
      _timerStarted = false;
      _whiteMsRemaining = _selectedTimerMinutes * 60 * 1000;
      _blackMsRemaining = _selectedTimerMinutes * 60 * 1000;
    });
    if (_timerEnabled) _startClock();
  }

  String _formatTime(int ms) {
    if (ms <= 0) return '0:00';
    final totalSeconds = (ms / 1000).ceil();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (ms < 20000) {
      // Show tenths when under 20 seconds
      final tenths = ((ms % 1000) ~/ 100);
      return '$minutes:${seconds.toString().padLeft(2, '0')}.$tenths';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────
  //  Timer settings dialog
  // ─────────────────────────────────────────────

  void _showTimerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.white70, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Chess Clock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Toggle
                      Switch(
                        value: _timerEnabled,
                        activeThumbColor: const Color(0xFF4FACFE),
                        onChanged: (v) {
                          setModalState(() {});
                          setState(() {
                            _timerEnabled = v;
                            if (v) {
                              _whiteMsRemaining =
                                  _selectedTimerMinutes * 60 * 1000;
                              _blackMsRemaining =
                                  _selectedTimerMinutes * 60 * 1000;
                              _timerStarted = false;
                              _startClock();
                            } else {
                              _clockTimer?.cancel();
                              _timerStarted = false;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  if (_timerEnabled) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Time per player',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presets.map((mins) {
                        final isSelected = _selectedTimerMinutes == mins;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {});
                            setState(() {
                              _selectedTimerMinutes = mins;
                              _whiteMsRemaining = mins * 60 * 1000;
                              _blackMsRemaining = mins * 60 * 1000;
                              _timerStarted = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 72,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(colors: [
                                      Color(0xFF4FACFE),
                                      Color(0xFF00F2FE)
                                    ])
                                  : null,
                              color: isSelected
                                  ? null
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$mins min',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Move handling
  // ─────────────────────────────────────────────

  void _onSquareTapped(ChessPosition position, ChessGameState state) {
    if (state.isGameOver) return;
    // If timer ran out, block moves
    if (_timerEnabled &&
        (_whiteMsRemaining <= 0 || _blackMsRemaining <= 0)) {
      return;
    }

    final notifier = ref.read(chessGameStateProvider.notifier);

    if (_selectedPosition != null) {
      if (_selectedPosition == position) {
        setState(() {
          _selectedPosition = null;
          _validMoves = [];
        });
        return;
      }

      final tappedPiece = state.board[position];
      if (tappedPiece != null && tappedPiece.color == state.currentTurn) {
        setState(() {
          _selectedPosition = position;
          _validMoves = notifier.getValidMoves(position);
        });
        return;
      }

      if (_validMoves.contains(position)) {
        if (notifier.isPromotionMove(_selectedPosition!, position)) {
          _showPromotionDialog(state.currentTurn).then((piece) {
            if (piece != null) {
              _executeMove(notifier, _selectedPosition!, position,
                  promotionPiece: piece);
            }
            setState(() {
              _selectedPosition = null;
              _validMoves = [];
            });
          });
          return;
        }

        _executeMove(notifier, _selectedPosition!, position);
      }

      setState(() {
        _selectedPosition = null;
        _validMoves = [];
      });
    } else {
      final piece = state.board[position];
      if (piece != null && piece.color == state.currentTurn) {
        final moves = notifier.getValidMoves(position);
        setState(() {
          _selectedPosition = position;
          _validMoves = moves;
        });
      }
    }
  }

  void _executeMove(ChessGameStateNotifier notifier, ChessPosition from,
      ChessPosition to,
      {String? promotionPiece}) {
    final success =
        notifier.makeMove(from, to, promotionPiece: promotionPiece);
    if (success && _timerEnabled && !_timerStarted) {
      setState(() {
        _timerStarted = true;
      });
    }
  }

  Future<String?> _showPromotionDialog(ChessPieceColor color) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isWhite = color == ChessPieceColor.white;
        final pieces = [
          {'symbol': isWhite ? '♕' : '♛', 'value': 'q', 'name': 'Queen'},
          {'symbol': isWhite ? '♖' : '♜', 'value': 'r', 'name': 'Rook'},
          {'symbol': isWhite ? '♗' : '♝', 'value': 'b', 'name': 'Bishop'},
          {'symbol': isWhite ? '♘' : '♞', 'value': 'n', 'name': 'Knight'},
        ];

        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Promote Pawn',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: pieces.map((p) {
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(p['value']),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Center(
                    child: Text(
                      p['symbol']!,
                      style: TextStyle(
                        fontSize: 36,
                        color: isWhite ? Colors.white : Colors.black87,
                        shadows: [
                          Shadow(
                            color: isWhite ? Colors.black54 : Colors.white54,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(chessGameStateProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Pass & Play Chess',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Timer button
          IconButton(
            icon: Icon(
              _timerEnabled ? Icons.timer : Icons.timer_outlined,
              color: _timerEnabled ? const Color(0xFF4FACFE) : null,
            ),
            tooltip: 'Chess Clock',
            onPressed: _showTimerDialog,
          ),
          // Reset button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New Game',
            onPressed: _resetAll,
          ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Black player clock + indicator ──
              _buildPlayerClock(
                gameState,
                forBlackPlayer: true,
              ).animate().fade().slideY(begin: -0.2),

              const SizedBox(height: 12),

              // ── Chess board ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _buildBoard(gameState),
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(curve: Curves.easeOutBack, delay: 200.ms)
                  .fade(),

              const SizedBox(height: 12),

              // ── White player clock + indicator ──
              _buildPlayerClock(
                gameState,
                forBlackPlayer: false,
              ).animate().fade().slideY(begin: 0.2),

              // Game over banner
              if (gameState.isGameOver && gameState.resultMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFE65100).withValues(alpha: 0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Text(
                      gameState.resultMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(curve: Curves.elasticOut)
                    .fade(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Player clock / status widget
  // ─────────────────────────────────────────────

  Widget _buildPlayerClock(ChessGameState state,
      {required bool forBlackPlayer}) {
    final isWhiteTurn = state.currentTurn == ChessPieceColor.white;
    final isActive =
        (forBlackPlayer && !isWhiteTurn) || (!forBlackPlayer && isWhiteTurn);

    final bgColor = forBlackPlayer ? Colors.black87 : Colors.white;
    final textColor = forBlackPlayer ? Colors.white : Colors.black87;
    final subtitleColor =
        forBlackPlayer ? Colors.white70 : Colors.black54;

    final ms = forBlackPlayer ? _blackMsRemaining : _whiteMsRemaining;
    final isLowTime = _timerEnabled && ms < 30000 && ms > 0;
    final isTimedOut = _timerEnabled && ms <= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isActive ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (isLowTime
                              ? Colors.redAccent
                              : bgColor)
                          .withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 2,
                    )
                  ]
                : null,
            border: Border.all(
              color: isLowTime && isActive
                  ? Colors.redAccent.withValues(alpha: 0.7)
                  : Colors.grey.shade400,
              width: isLowTime && isActive ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Player info (left side)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      forBlackPlayer ? 'Black' : 'White',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    if (isActive && !state.isGameOver && !isTimedOut)
                      Text(
                        state.isCheck ? 'CHECK!' : 'YOUR TURN',
                        style: TextStyle(
                          color: state.isCheck ? Colors.redAccent : subtitleColor,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                    if (isTimedOut)
                      const Text(
                        'TIME OUT',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Clock (right side) — only when timer is enabled
              if (_timerEnabled)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isLowTime
                            ? Colors.red.withValues(alpha: 0.15)
                            : (forBlackPlayer
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06)))
                        : (forBlackPlayer
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLowTime && isActive
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : (forBlackPlayer
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.08)),
                    ),
                  ),
                  child: Text(
                    _formatTime(ms),
                    style: TextStyle(
                      fontSize: ms < 20000 ? 22 : 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      letterSpacing: 1,
                      color: isTimedOut
                          ? Colors.redAccent
                          : (isLowTime && isActive
                              ? Colors.redAccent
                              : textColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Board
  // ─────────────────────────────────────────────

  Widget _buildBoard(ChessGameState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final squareSize = constraints.maxWidth / 8;
        final pieceSize = squareSize * 0.75;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final row = index ~/ 8;
            final col = index % 8;
            final position = ChessPosition(row, col);
            final piece = state.board[position];

            final isLightSquare = (row + col) % 2 == 0;
            final isSelected = _selectedPosition == position;
            final isValidMove = _validMoves.contains(position);
            final isLastMoveFrom = state.lastMoveFrom == position;
            final isLastMoveTo = state.lastMoveTo == position;

            Color squareColor;
            if (isSelected) {
              squareColor = const Color(0xFFF6F669);
            } else if (isLastMoveFrom || isLastMoveTo) {
              squareColor = isLightSquare
                  ? const Color(0xFFC8E6A0)
                  : const Color(0xFF7CB342);
            } else if (isLightSquare) {
              squareColor = const Color(0xFFF0D9B5);
            } else {
              squareColor = const Color(0xFFB58863);
            }

            return GestureDetector(
              onTap: () => _onSquareTapped(position, state),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                color: squareColor,
                child: Stack(
                  children: [
                    if (isValidMove && piece == null)
                      Center(
                        child: Container(
                          width: squareSize * 0.3,
                          height: squareSize * 0.3,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (isValidMove && piece != null)
                      Center(
                        child: Container(
                          width: squareSize * 0.9,
                          height: squareSize * 0.9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.25),
                              width: squareSize * 0.08,
                            ),
                          ),
                        ),
                      ),
                    if (piece != null)
                      Center(
                        child: Text(
                          piece.symbol,
                          style: TextStyle(
                            fontSize: pieceSize,
                            height: 1.0,
                            color: piece.color == ChessPieceColor.white
                                ? Colors.white
                                : Colors.black87,
                            shadows: [
                              Shadow(
                                color: piece.color == ChessPieceColor.white
                                    ? Colors.black54
                                    : Colors.white54,
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
