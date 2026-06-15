import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/host/domain/game_state.dart';
import 'package:pocket_party/features/host/providers/game_loop_provider.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import 'package:pocket_party/features/game_draw/domain/models/draw_point.dart';
import 'package:pocket_party/features/game_draw/presentation/widgets/draw_canvas.dart';

class GameScreen extends ConsumerStatefulWidget {
  final bool isHost;

  const GameScreen({super.key, required this.isHost});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final TextEditingController _chatController = TextEditingController();
  final List<String> _chatMessages = [];
  StreamSubscription? _tcpSub;
  
  // A local Notifier for draw points could be used, or we just pass a ValueNotifier to the Canvas
  final ValueNotifier<List<DrawPoint>> _pointsNotifier = ValueNotifier([]);

  // ── Draw point batching ──
  // Buffer points locally and flush every 33ms (~30fps) as a single TCP message.
  // Reduces TCP writes from ~60/sec to ~3-4/sec during active drawing.
  final List<DrawPoint> _drawBatch = [];
  Timer? _batchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNetworkListeners();
    });
  }

  void _setupNetworkListeners() {
    if (widget.isHost) {
      final tcpServer = ref.read(tcpServerProvider);
      
      // Host also needs to listen to game state changes to broadcast them
      ref.listenManual(gameLoopProvider, (previous, next) {
        if (previous != next) {
          tcpServer.broadcastMessage({
            'type': 'game_state',
            'state': next.toJson(),
          });
        }
      });
      
      ref.listenManual(lobbyProvider, (previous, next) {
        if (previous != next) {
          final updatedLobby = next.map((p) => p.toJson()).toList();
          tcpServer.broadcastMessage({
            'type': 'lobby_update',
            'players': updatedLobby,
          });
        }
      });

      _tcpSub = tcpServer.messageStream.listen((msg) {
        if (!mounted) return;
        final type = msg['type'];
        
        if (type == 'draw_point') {
          // Legacy single-point message
          final pt = DrawPoint.fromJson(msg['point']);
          _pointsNotifier.value = [..._pointsNotifier.value, pt];
          tcpServer.broadcastMessage(msg);
        } else if (type == 'draw_path') {
          // Batched points — more efficient for LAN
          final points = (msg['points'] as List).map((p) => DrawPoint.fromJson(p)).toList();
          _pointsNotifier.value = [..._pointsNotifier.value, ...points];
          tcpServer.broadcastMessage(msg);
        } else if (type == 'chat') {
          final text = msg['text'];
          final playerId = msg['playerId'];
          
          setState(() {
            _chatMessages.add('$playerId: $text');
          });
          
          // Check for correct guess
          final gameState = ref.read(gameLoopProvider);
          if (gameState.status == GameStatus.playing &&
              text.toString().toLowerCase() == gameState.currentWord?.toLowerCase()) {
            ref.read(gameLoopProvider.notifier).handleCorrectGuess(playerId);
            tcpServer.broadcastMessage({
              'type': 'chat',
              'text': '$playerId guessed the word!',
              'playerId': 'SYSTEM',
            });
          } else {
            tcpServer.broadcastMessage(msg);
          }
        }
      });
    } else {
      final tcpClient = ref.read(tcpClientProvider);
      _tcpSub = tcpClient.messageStream.listen((msg) {
        if (!mounted) return;
        final type = msg['type'];
        
        if (type == 'game_state') {
          // We need a way to update the client's game state.
          // Since gameLoopProvider is a Notifier, we should ideally add a 'setState' method.
          // For now, we'll use a hack or we need to add setState to GameLoopNotifier.
          // I will add setState to GameLoopNotifier in the next step.
          ref.read(gameLoopProvider.notifier).setState(GameState.fromJson(msg['state']));
        } else if (type == 'lobby_update') {
          // Already handled partially in Lobby, but we need it here too to update scores
          // Actually lobby_provider should probably have this global listener.
          // For this MVP, we will handle it locally.
        } else if (type == 'draw_point') {
          final pt = DrawPoint.fromJson(msg['point']);
          _pointsNotifier.value = [..._pointsNotifier.value, pt];
        } else if (type == 'draw_path') {
          final points = (msg['points'] as List).map((p) => DrawPoint.fromJson(p)).toList();
          _pointsNotifier.value = [..._pointsNotifier.value, ...points];
        } else if (type == 'chat') {
          final text = msg['text'];
          final playerId = msg['playerId'];
          setState(() {
            _chatMessages.add('$playerId: $text');
          });
        }
      });
    }
  }

  void _sendDrawPoint(DrawPoint point) {
    // Add to local canvas immediately for responsive feel
    _pointsNotifier.value = [..._pointsNotifier.value, point];

    // Buffer the point for batched network send
    _drawBatch.add(point);

    // Start a 33ms flush timer if not already running
    _batchTimer ??= Timer(const Duration(milliseconds: 33), _flushDrawBatch);
  }

  /// Sends all buffered draw points as a single TCP message.
  void _flushDrawBatch() {
    _batchTimer = null;
    if (_drawBatch.isEmpty) return;

    final msg = {
      'type': 'draw_path',
      'points': _drawBatch.map((p) => p.toJson()).toList(),
    };

    if (widget.isHost) {
      ref.read(tcpServerProvider).broadcastMessage(msg);
    } else {
      ref.read(tcpClientProvider).sendMessage(msg);
    }

    _drawBatch.clear();
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    
    // For MVP, we need to know local player ID.
    // If Host, it's the first host. If client, we should have stored it.
    // Let's just use 'Player' for now to keep it simple, or find it from lobby.
    final players = ref.read(lobbyProvider);
    final me = players.firstWhere((p) => widget.isHost ? p.isHost : !p.isHost, orElse: () => players.first);
    
    final msg = {
      'type': 'chat',
      'text': text,
      'playerId': me.name, // Using name as ID for chat display MVP
    };
    
    if (widget.isHost) {
      setState(() {
        _chatMessages.add('${me.name}: $text');
      });
      // Check if host guessed (host shouldn't guess, but anyway)
      ref.read(tcpServerProvider).broadcastMessage(msg);
    } else {
      setState(() {
        _chatMessages.add('${me.name}: $text');
      });
      ref.read(tcpClientProvider).sendMessage(msg);
    }
    
    _chatController.clear();
  }

  @override
  void dispose() {
    _batchTimer?.cancel();
    // Flush remaining draw points while ref is still valid
    try {
      if (_drawBatch.isNotEmpty) {
        _flushDrawBatch();
      }
    } catch (_) {
      // ref may already be invalid during hot reload or app shutdown
    }
    _tcpSub?.cancel();
    _chatController.dispose();
    _pointsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameLoopProvider);
    final players = ref.watch(lobbyProvider);
    
    // Determine if I am drawing
    final me = players.firstWhere((p) => widget.isHost ? p.isHost : !p.isHost, orElse: () => players.first);
    final amIDrawing = gameState.currentDrawerId == me.id;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Round ${gameState.currentRound} - ${gameState.remainingSeconds}s'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              amIDrawing 
                ? 'Draw this: ${gameState.currentWord}' 
                : 'Guess the word! (Drawer: ${players.firstWhere((p) => p.id == gameState.currentDrawerId, orElse: () => players.first).name})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          
          // Canvas
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                // We'd pass _pointsNotifier and _sendDrawPoint to the CustomPainter
                // The existing DrawCanvas needs to be used here.
                // Assuming DrawCanvas takes a stream or notifier of points and an onDraw callback
                child: DrawCanvas(
                  pointsNotifier: _pointsNotifier,
                  onDraw: amIDrawing ? _sendDrawPoint : null,
                ),
              ),
            ),
          ),
          
          // Chat / Guesses
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true, // New messages at bottom
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, index) {
                      // Reversed index
                      final msg = _chatMessages[_chatMessages.length - 1 - index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text(msg),
                      );
                    },
                  ),
                ),
                if (!amIDrawing)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            decoration: const InputDecoration(
                              hintText: 'Type your guess...',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _sendChat(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _sendChat,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
