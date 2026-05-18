import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/reversi_game_state.dart';
import '../providers/reversi_provider.dart';

class ReversiScreen extends ConsumerStatefulWidget {
  const ReversiScreen({super.key});

  @override
  ConsumerState<ReversiScreen> createState() => _ReversiScreenState();
}

class _ReversiScreenState extends ConsumerState<ReversiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(reversiProvider).turnCount == 0) {
        ref.read(reversiProvider.notifier).initializeLocalGame();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reversiProvider);
    final notifier = ref.read(reversiProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20), // Green 800
      appBar: AppBar(
        title: const Text('Reversi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF124016), // Darker green
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 10,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Score Board
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ScoreCard(
                  color: PlayerColor.black,
                  score: state.blackScore,
                  isTurn: state.currentTurn == PlayerColor.black && !state.isGameOver,
                ),
                _ScoreCard(
                  color: PlayerColor.white,
                  score: state.whiteScore,
                  isTurn: state.currentTurn == PlayerColor.white && !state.isGameOver,
                ),
              ],
            ),
          ),
          
          if (state.isGameOver)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                state.winner == null ? 'It\'s a Tie!' : '${state.winner!.name.toUpperCase()} WINS!',
                style: const TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.amber,
                  letterSpacing: 2,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))]
                ),
              ).animate().fade(duration: 500.ms).scale(curve: Curves.elasticOut, duration: 800.ms),
            ),

          // Game Board
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32), // Green 700
                    border: Border.all(color: Colors.black87, width: 4),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 15, offset: Offset(0, 10)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                      ),
                      itemCount: 64,
                      itemBuilder: (context, index) {
                        final r = index ~/ 8;
                        final c = index % 8;
                        final piece = state.board[r][c];

                        return GestureDetector(
                          onTap: () {
                            notifier.makeMove(r, c);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black38, width: 1),
                            ),
                            child: Center(
                              child: piece != null
                                  ? _ReversiDisc(piece: piece)
                                  : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final PlayerColor color;
  final int score;
  final bool isTurn;

  const _ScoreCard({required this.color, required this.score, required this.isTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color == PlayerColor.black ? const Color(0xFF222222) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(16),
        border: isTurn ? Border.all(color: Colors.amber, width: 3) : Border.all(color: Colors.transparent, width: 3),
        boxShadow: [
          if (isTurn) BoxShadow(color: Colors.amber.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
          const BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 4))
        ]
      ),
      child: Column(
        children: [
          Text(
            color.name.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              color: color == PlayerColor.black ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            score.toString(),
            style: TextStyle(
              fontSize: 32,
              color: color == PlayerColor.black ? Colors.white : Colors.black,
              fontWeight: FontWeight.w900,
            ),
          ).animate(target: isTurn ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 200.ms),
        ],
      ),
    );
  }
}

class _ReversiDisc extends StatelessWidget {
  final ReversiPiece piece;

  const _ReversiDisc({required this.piece});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: piece.color == PlayerColor.black ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
        gradient: RadialGradient(
          colors: piece.color == PlayerColor.black 
            ? [const Color(0xFF444444), const Color(0xFF111111)] 
            : [Colors.white, const Color(0xFFDDDDDD)],
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black87, offset: Offset(2, 3), blurRadius: 4),
        ],
      ),
    )
    .animate(key: ValueKey('${piece.color.name}_${piece.lastFlippedTurn}'))
    .flipH(
      begin: -0.5,
      end: 0,
      duration: 350.ms,
      delay: piece.delayMs.ms,
      curve: Curves.easeOutBack,
    );
  }
}
