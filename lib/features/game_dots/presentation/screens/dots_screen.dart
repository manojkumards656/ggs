import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/models/dots_state.dart';
import '../../domain/providers/dots_provider.dart';

class DotsScreen extends ConsumerStatefulWidget {
  const DotsScreen({super.key});

  @override
  ConsumerState<DotsScreen> createState() => _DotsScreenState();
}

class _DotsScreenState extends ConsumerState<DotsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dotsProvider.notifier).initializeGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dotsProvider);
    final isNetworked = state.mode == DotsMode.networked;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Dots and Boxes'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildScoreBoard(state),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: _buildGrid(state),
              ),
            ),
          ),
          if (state.isGameOver)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Text(
                    state.winnerId == null
                        ? 'It\'s a Tie!'
                        : '${state.winnerId == 'player1' ? 'Player 1' : 'Player 2'} Wins!',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    onPressed: () {
                      ref.read(dotsProvider.notifier).initializeGame();
                    },
                    child: const Text('Play Again', style: TextStyle(fontSize: 18, color: Colors.white)),
                  )
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBoard(DotsState state) {
    final p1Score = state.scores['player1'] ?? 0;
    final p2Score = state.scores['player2'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPlayerScore('Player 1', p1Score, state.activePlayerId == 'player1', const Color(0xFFE94560)),
          const Text('vs', style: TextStyle(color: Colors.white54, fontSize: 18)),
          _buildPlayerScore('Player 2', p2Score, state.activePlayerId == 'player2', const Color(0xFF0F3460)),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(String name, int score, bool isActive, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? color : color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: Colors.white, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(
            name,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            score.toString(),
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
        ],
      ),
    ).animate(target: isActive ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 200.ms);
  }

  Widget _buildGrid(DotsState state) {
    const double dotSize = 16.0;
    const double lineLength = 50.0;
    const double lineThickness = 12.0;

    List<Widget> gridRows = [];

    for (int r = 0; r <= state.gridRows; r++) {
      // Row of dots and horizontal lines
      List<Widget> horizontalRow = [];
      for (int c = 0; c <= state.gridCols; c++) {
        // Dot
        horizontalRow.add(
          Container(
            width: dotSize,
            height: dotSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        );

        // Horizontal Line (if not last col)
        if (c < state.gridCols) {
          final isDrawn = state.horizontalLines.contains("${r}_$c");
          horizontalRow.add(
            GestureDetector(
              onTap: () => ref.read(dotsProvider.notifier).drawLineLocal(true, r, c),
              child: Container(
                width: lineLength,
                height: dotSize,
                alignment: Alignment.center,
                child: Container(
                  height: lineThickness,
                  width: lineLength,
                  decoration: BoxDecoration(
                    color: isDrawn ? Colors.white : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(lineThickness / 2),
                  ),
                ).animate(target: isDrawn ? 1 : 0)
                 .tint(color: Colors.white)
                 .scaleX(begin: 0, end: 1, duration: 300.ms, curve: Curves.easeOut),
              ),
            ),
          );
        }
      }
      gridRows.add(Row(mainAxisSize: MainAxisSize.min, children: horizontalRow));

      // Row of vertical lines and boxes (if not last row)
      if (r < state.gridRows) {
        List<Widget> verticalRow = [];
        for (int c = 0; c <= state.gridCols; c++) {
          // Vertical Line
          final isDrawn = state.verticalLines.contains("${r}_$c");
          verticalRow.add(
            GestureDetector(
              onTap: () => ref.read(dotsProvider.notifier).drawLineLocal(false, r, c),
              child: Container(
                width: dotSize,
                height: lineLength,
                alignment: Alignment.center,
                child: Container(
                  width: lineThickness,
                  height: lineLength,
                  decoration: BoxDecoration(
                    color: isDrawn ? Colors.white : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(lineThickness / 2),
                  ),
                ).animate(target: isDrawn ? 1 : 0)
                 .tint(color: Colors.white)
                 .scaleY(begin: 0, end: 1, duration: 300.ms, curve: Curves.easeOut),
              ),
            ),
          );

          // Box (if not last col)
          if (c < state.gridCols) {
            final capturedBy = state.boxes["${r}_$c"];
            final isCaptured = capturedBy != null;
            Color boxColor = Colors.transparent;
            if (isCaptured) {
              boxColor = capturedBy == 'player1' ? const Color(0xFFE94560) : const Color(0xFF0F3460);
            }

            verticalRow.add(
              Container(
                width: lineLength,
                height: lineLength,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isCaptured ? boxColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
              ).animate(target: isCaptured ? 1 : 0)
               .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 400.ms, curve: Curves.elasticOut)
               .fadeIn(),
            );
          }
        }
        gridRows.add(Row(mainAxisSize: MainAxisSize.min, children: verticalRow));
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: gridRows,
      ),
    );
  }
}
