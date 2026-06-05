import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/draw_guess_provider.dart';
import '../domain/models/draw_point.dart';
import 'widgets/draw_canvas.dart';

class DrawGuessSingleScreen extends ConsumerStatefulWidget {
  const DrawGuessSingleScreen({super.key});

  @override
  ConsumerState<DrawGuessSingleScreen> createState() => _DrawGuessSingleScreenState();
}

class _DrawGuessSingleScreenState extends ConsumerState<DrawGuessSingleScreen> {
  final ValueNotifier<List<DrawPoint>> _pointsNotifier = ValueNotifier([]);
  final TextEditingController _guessController = TextEditingController();
  Color _currentColor = Colors.white;
  double _currentStrokeWidth = 3.0;

  static const _colors = [
    Colors.white, Colors.red, Colors.blue, Colors.green,
    Colors.yellow, Colors.orange, Colors.purple, Colors.pink,
    Colors.cyan, Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(drawGuessProvider.notifier).initGame();
    });
  }

  @override
  void dispose() {
    _pointsNotifier.dispose();
    _guessController.dispose();
    super.dispose();
  }

  void _clearCanvas() {
    _pointsNotifier.value = [];
  }

  void _undoStroke() {
    final pts = List<DrawPoint>.from(_pointsNotifier.value);
    if (pts.isEmpty) return;
    // Remove back to the last null-point separator
    while (pts.isNotEmpty && pts.last.point != null) {
      pts.removeLast();
    }
    if (pts.isNotEmpty) pts.removeLast(); // remove the null separator
    _pointsNotifier.value = pts;
  }

  void _addPoint(DrawPoint point) {
    _pointsNotifier.value = [..._pointsNotifier.value, point];
  }

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(drawGuessProvider);
    final notifier = ref.read(drawGuessProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Round ${gs.currentRound}/${gs.maxRounds}'),
        centerTitle: true,
        actions: [
          if (gs.phase == DrawGuessPhase.drawing || gs.phase == DrawGuessPhase.guessing)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: gs.remainingSeconds <= 10
                        ? Colors.red.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${gs.remainingSeconds}s',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: gs.remainingSeconds <= 10 ? Colors.redAccent : Colors.white,
                      )),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(gs, notifier)),
    );
  }

  Widget _buildBody(DrawGuessState gs, DrawGuessNotifier notifier) {
    switch (gs.phase) {
      case DrawGuessPhase.wordReveal:
        return _buildWordReveal(gs, notifier);
      case DrawGuessPhase.drawing:
        return _buildDrawing(gs, notifier);
      case DrawGuessPhase.guessing:
        return _buildGuessing(gs, notifier);
      case DrawGuessPhase.result:
        return _buildResult(gs, notifier);
      case DrawGuessPhase.gameOver:
        return _buildGameOver(gs, notifier);
    }
  }

  // ── Word Reveal ──
  Widget _buildWordReveal(DrawGuessState gs, DrawGuessNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility_off, size: 64, color: Colors.white54)
                .animate().fade().scale(),
            const SizedBox(height: 24),
            Text('Pass the phone to', style: TextStyle(fontSize: 18, color: Colors.grey.shade400))
                .animate().fade(delay: 200.ms),
            const SizedBox(height: 8),
            Text(gs.drawerName,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent))
                .animate().fade(delay: 400.ms).slideY(begin: 0.2),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1a1a2e), Color(0xFF16213e)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text('Your word is:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Text(gs.currentWord.toUpperCase(),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)),
                ],
              ),
            ).animate().fade(delay: 600.ms).scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  _clearCanvas();
                  notifier.startDrawing();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('READY TO DRAW', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ).animate().fade(delay: 800.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  // ── Drawing Phase ──
  Widget _buildDrawing(DrawGuessState gs, DrawGuessNotifier notifier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('${gs.drawerName}, draw: ${gs.currentWord}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        ),
        // Canvas
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DrawCanvas(
                pointsNotifier: _pointsNotifier,
                onDraw: _addPoint,
                currentColor: _currentColor,
                currentStrokeWidth: _currentStrokeWidth,
              ),
            ),
          ),
        ),
        // Toolbar
        _buildToolbar(),
        // Done button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: () => notifier.finishDrawing(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('DONE DRAWING', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Colors
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colors.map((c) {
                  final selected = c == _currentColor;
                  return GestureDetector(
                    onTap: () => setState(() => _currentColor = c),
                    child: Container(
                      width: 28, height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.cyanAccent : Colors.transparent,
                          width: selected ? 2.5 : 0,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Stroke width
          IconButton(icon: const Icon(Icons.remove, size: 18, color: Colors.white70), onPressed: () {
            setState(() => _currentStrokeWidth = (_currentStrokeWidth - 1).clamp(1, 12));
          }),
          Text('${_currentStrokeWidth.toInt()}', style: const TextStyle(color: Colors.white70)),
          IconButton(icon: const Icon(Icons.add, size: 18, color: Colors.white70), onPressed: () {
            setState(() => _currentStrokeWidth = (_currentStrokeWidth + 1).clamp(1, 12));
          }),
          IconButton(icon: const Icon(Icons.undo, color: Colors.white70), onPressed: _undoStroke),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _clearCanvas),
        ],
      ),
    );
  }

  // ── Guessing Phase ──
  Widget _buildGuessing(DrawGuessState gs, DrawGuessNotifier notifier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Pass phone to ${gs.guesserName} to guess!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: DrawCanvas(pointsNotifier: _pointsNotifier, onDraw: null),
            ),
          ),
        ),
        if (gs.lastWrongGuess != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('"${gs.lastWrongGuess}" is wrong!',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))
                .animate().shake(),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _guessController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type your guess... (${gs.guessAttemptsLeft} left)',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true, fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _submitGuess(notifier),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
                onPressed: () => _submitGuess(notifier),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _submitGuess(DrawGuessNotifier notifier) {
    final text = _guessController.text.trim();
    if (text.isEmpty) return;
    _guessController.clear();
    notifier.submitGuess(text);
  }

  // ── Result ──
  Widget _buildResult(DrawGuessState gs, DrawGuessNotifier notifier) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(gs.guessedCorrectly ? Icons.check_circle : Icons.cancel,
                size: 80, color: gs.guessedCorrectly ? Colors.greenAccent : Colors.redAccent)
                .animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(gs.guessedCorrectly ? 'Correct!' : 'Wrong!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold,
                    color: gs.guessedCorrectly ? Colors.greenAccent : Colors.redAccent))
                .animate().fade(delay: 200.ms),
            const SizedBox(height: 12),
            Text('The word was: ${gs.currentWord}',
                style: const TextStyle(fontSize: 20, color: Colors.white70))
                .animate().fade(delay: 400.ms),
            const SizedBox(height: 32),
            // Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _scoreCard(gs.playerNames[0], gs.scores[0]),
                _scoreCard(gs.playerNames[1], gs.scores[1]),
              ],
            ).animate().fade(delay: 600.ms),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => notifier.nextRound(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  gs.currentRound >= gs.maxRounds ? 'SEE FINAL RESULTS' : 'NEXT ROUND',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().fade(delay: 800.ms).slideY(begin: 0.3),
          ],
        ),
      ),
    );
  }

  Widget _scoreCard(String name, int score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(name, style: const TextStyle(fontSize: 16, color: Colors.white70)),
          const SizedBox(height: 4),
          Text('$score', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
        ],
      ),
    );
  }

  // ── Game Over ──
  Widget _buildGameOver(DrawGuessState gs, DrawGuessNotifier notifier) {
    final winner = gs.scores[0] > gs.scores[1] ? gs.playerNames[0]
        : gs.scores[1] > gs.scores[0] ? gs.playerNames[1] : 'Tie';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amberAccent)
                .animate().scale(curve: Curves.elasticOut),
            const SizedBox(height: 16),
            Text(winner == 'Tie' ? "It's a Tie!" : '$winner Wins!',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.amberAccent))
                .animate().fade(delay: 300.ms),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _scoreCard(gs.playerNames[0], gs.scores[0]),
                _scoreCard(gs.playerNames[1], gs.scores[1]),
              ],
            ).animate().fade(delay: 500.ms),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () {
                  notifier.resetGame();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('BACK TO HOME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ).animate().fade(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
