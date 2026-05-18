import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/network_providers.dart';
import '../../host/providers/lobby_provider.dart';
import '../models/dots_state.dart';

class DotsNotifier extends Notifier<DotsState> {
  StreamSubscription? _clientSubscription;
  StreamSubscription? _serverSubscription;

  @override
  DotsState build() {
    _listenToNetwork();
    return const DotsState();
  }

  void _listenToNetwork() {
    final clientManager = ref.read(tcpClientProvider);
    final serverManager = ref.read(tcpServerProvider);

    _clientSubscription = clientManager.messageStream.listen((msg) {
      if (msg['type'] == 'dots_draw') {
        _handleIncomingDraw(msg);
      }
    });

    _serverSubscription = serverManager.messageStream.listen((msg) {
      if (msg['type'] == 'dots_draw') {
        _handleIncomingDraw(msg);
      }
    });

    ref.onDispose(() {
      _clientSubscription?.cancel();
      _serverSubscription?.cancel();
    });
  }

  void _handleIncomingDraw(Map<String, dynamic> msg) {
    if (state.mode == DotsMode.networked) {
      final isHorizontal = msg['isHorizontal'] as bool;
      final row = msg['row'] as int;
      final col = msg['col'] as int;
      final playerId = msg['playerId'] as String;
      
      // We only apply if it's the active player's turn (or just trust the network event)
      _drawLine(isHorizontal, row, col, isLocal: false, explicitPlayerId: playerId);
    }
  }

  void setMode(DotsMode mode) {
    state = state.copyWith(mode: mode);
  }

  void initializeGame() {
    state = const DotsState(
      mode: DotsMode.passAndPlay,
      scores: {'player1': 0, 'player2': 0},
      activePlayerId: 'player1',
      activePlayerName: 'Player 1',
    );
    
    if (state.mode == DotsMode.networked) {
      final players = ref.read(lobbyProvider);
      if (players.isNotEmpty) {
        state = state.copyWith(
          mode: DotsMode.networked,
          activePlayerId: players.first.id,
          activePlayerName: players.first.name,
          scores: { for (var p in players) p.id : 0 },
        );
      }
    }
  }

  void drawLineLocal(bool isHorizontal, int row, int col) {
    // Prevent drawing if game is over
    if (state.isGameOver) return;
    
    // In networked mode, only allow the active player to draw on their own device
    if (state.mode == DotsMode.networked) {
       final localPlayerId = ref.read(preferencesProvider).getString('deviceId'); 
       // Note: We might need to check if local player matches active player if we had a full auth/device ID system,
       // but for now we just draw it and broadcast. To be robust, let's assume UI handles disablement or we just pass it.
    }

    _drawLine(isHorizontal, row, col, isLocal: true, explicitPlayerId: state.activePlayerId);
  }

  void _drawLine(bool isHorizontal, int row, int col, {required bool isLocal, String? explicitPlayerId}) {
    final lineKey = "${row}_$col";
    
    // Check if line already exists
    if (isHorizontal && state.horizontalLines.contains(lineKey)) return;
    if (!isHorizontal && state.verticalLines.contains(lineKey)) return;

    final newH = Set<String>.from(state.horizontalLines);
    final newV = Set<String>.from(state.verticalLines);

    if (isHorizontal) {
      newH.add(lineKey);
    } else {
      newV.add(lineKey);
    }

    // Check for completed boxes
    final playerId = explicitPlayerId ?? state.activePlayerId;
    final newBoxes = Map<String, String>.from(state.boxes);
    int completedCount = 0;

    bool checkAndCaptureBox(int r, int c) {
      // A box at r, c is bounded by:
      // top: h(r, c), bottom: h(r+1, c)
      // left: v(r, c), right: v(r, c+1)
      if (r < 0 || r >= state.gridRows || c < 0 || c >= state.gridCols) return false;
      
      final key = "${r}_$c";
      if (newBoxes.containsKey(key)) return false; // Already captured

      if (newH.contains("${r}_$c") && 
          newH.contains("${r+1}_$c") &&
          newV.contains("${r}_$c") &&
          newV.contains("${r}_${c+1}")) {
        
        newBoxes[key] = playerId;
        return true;
      }
      return false;
    }

    if (isHorizontal) {
      // Check box above and below
      if (checkAndCaptureBox(row - 1, col)) completedCount++;
      if (checkAndCaptureBox(row, col)) completedCount++;
    } else {
      // Check box left and right
      if (checkAndCaptureBox(row, col - 1)) completedCount++;
      if (checkAndCaptureBox(row, col)) completedCount++;
    }

    // Update scores
    final newScores = Map<String, int>.from(state.scores);
    if (completedCount > 0) {
      newScores[playerId] = (newScores[playerId] ?? 0) + completedCount;
    }

    // Switch turns if no box was captured
    String nextPlayerId = state.activePlayerId;
    String nextPlayerName = state.activePlayerName;

    if (completedCount == 0) {
      if (state.mode == DotsMode.networked) {
        final players = ref.read(lobbyProvider);
        if (players.isNotEmpty) {
          int currentIndex = players.indexWhere((p) => p.id == state.activePlayerId);
          int nextIndex = (currentIndex + 1) % players.length;
          nextPlayerId = players[nextIndex].id;
          nextPlayerName = players[nextIndex].name;
        }
      } else {
        // Pass and play toggle
        if (state.activePlayerId == 'player1') {
          nextPlayerId = 'player2';
          nextPlayerName = 'Player 2';
        } else {
          nextPlayerId = 'player1';
          nextPlayerName = 'Player 1';
        }
      }
    }

    // Check game over
    bool isOver = newBoxes.length == (state.gridRows * state.gridCols);
    String? winner;
    if (isOver) {
      int maxScore = -1;
      for (var entry in newScores.entries) {
        if (entry.value > maxScore) {
          maxScore = entry.value;
          winner = entry.key;
        } else if (entry.value == maxScore) {
          winner = null; // tie
        }
      }
    }

    state = state.copyWith(
      horizontalLines: newH,
      verticalLines: newV,
      boxes: newBoxes,
      scores: newScores,
      activePlayerId: nextPlayerId,
      activePlayerName: nextPlayerName,
      isGameOver: isOver,
      winnerId: winner,
    );

    // Broadcast if local move and networked
    if (isLocal && state.mode == DotsMode.networked) {
      final msg = {
        'type': 'dots_draw',
        'isHorizontal': isHorizontal,
        'row': row,
        'col': col,
        'playerId': playerId,
      };
      ref.read(tcpServerProvider).broadcastMessage(msg);
      ref.read(tcpClientProvider).sendMessage(msg);
    }
  }
}

final dotsProvider = NotifierProvider<DotsNotifier, DotsState>(() {
  return DotsNotifier();
});
