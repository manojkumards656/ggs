import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/connect4_state.dart';

class Connect4Screen extends ConsumerWidget {
  const Connect4Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(connect4Provider);
    final notifier = ref.read(connect4Provider.notifier);

    final neonRed = const Color(0xFFFF003C);
    final neonYellow = const Color(0xFFFFE600);
    final boardColor = const Color(0xFF1E293B);
    final bgColor = const Color(0xFF0F172A);
    final slotColor = const Color(0xFF0B1120);

    Color getPlayerColor(int player) {
      if (player == 1) return neonRed;
      if (player == 2) return neonYellow;
      return Colors.transparent;
    }

    String getStatusText() {
      if (state.winner == 1) return "RED WINS!";
      if (state.winner == 2) return "YELLOW WINS!";
      if (state.winner == -1) return "DRAW!";
      return state.currentPlayer == 1 ? "RED'S TURN" : "YELLOW'S TURN";
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => notifier.resetGame(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Status Header
            Text(
              getStatusText(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: state.winner == 0
                    ? getPlayerColor(state.currentPlayer)
                    : (state.winner > 0 ? getPlayerColor(state.winner) : Colors.white),
                shadows: [
                  Shadow(
                    color: state.winner == 0
                        ? getPlayerColor(state.currentPlayer).withOpacity(0.5)
                        : (state.winner > 0 ? getPlayerColor(state.winner).withOpacity(0.5) : Colors.transparent),
                    blurRadius: 10,
                  )
                ],
              ),
            )
                .animate(target: state.winner != 0 ? 1 : 0)
                .scale(end: const Offset(1.2, 1.2), duration: 400.ms, curve: Curves.easeOutBack)
                .shimmer(duration: 1.seconds, color: Colors.white54),
                
            const SizedBox(height: 40),
            
            // Game Board
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: Connect4Notifier.cols / Connect4Notifier.rows,
                    child: Container(
                      decoration: BoxDecoration(
                        color: boardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: List.generate(Connect4Notifier.rows, (r) {
                          return Expanded(
                            child: Row(
                              children: List.generate(Connect4Notifier.cols, (c) {
                                final cellValue = state.board[r][c];
                                final isWinningCell = state.winningCells.any((cell) => cell[0] == r && cell[1] == c);

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => notifier.dropChecker(c),
                                    child: Container(
                                      margin: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: slotColor,
                                        border: Border.all(color: Colors.black45, width: 1.5),
                                      ),
                                      child: cellValue == 0
                                          ? null
                                          : Container(
                                              margin: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: RadialGradient(
                                                  colors: [
                                                    getPlayerColor(cellValue).withOpacity(0.7),
                                                    getPlayerColor(cellValue),
                                                  ],
                                                  center: Alignment.topLeft,
                                                  radius: 0.8,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: getPlayerColor(cellValue).withOpacity(isWinningCell ? 0.8 : 0.4),
                                                    blurRadius: isWinningCell ? 15 : 6,
                                                    spreadRadius: isWinningCell ? 3 : 1,
                                                  )
                                                ],
                                              ),
                                            )
                                            .animate(key: ValueKey('checker_${r}_${c}_$cellValue'))
                                            .slideY(
                                              begin: -(r + 1.5).toDouble(), // Drops from above the board
                                              end: 0,
                                              duration: (400 + r * 50).ms,
                                              curve: Curves.bounceOut,
                                            )
                                            .fadeIn(duration: 200.ms)
                                            .then(delay: isWinningCell ? 100.ms : 0.ms)
                                            .shimmer(
                                              duration: 800.ms,
                                              color: Colors.white70,
                                              blendMode: BlendMode.srcATop,
                                            ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Mode toggle (for testing)
            if (state.winner == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Mode: ", style: TextStyle(color: Colors.white70)),
                    Switch(
                      value: state.isNetworked,
                      onChanged: (val) {
                        notifier.setMode(isNetworked: val, isHost: state.isHost);
                      },
                      activeThumbColor: neonYellow,
                    ),
                    Text(state.isNetworked ? "Networked" : "Pass & Play", 
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
