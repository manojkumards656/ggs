import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';
import 'package:pocket_party/features/host/providers/lobby_provider.dart';
import '../models/tod_state.dart';

const List<String> truths = [
  "When was the last time you lied?",
  "What is your biggest fear?",
  "What is your most embarrassing memory?",
  "Have you ever cheated on a test?",
  "What's the worst food you've ever tasted?",
  "What's the longest you've gone without a shower?",
  "What is the most childish thing you still do?",
  "What's the worst trouble you got into as a kid?",
  "Who is your secret crush?",
  "What's a secret you've never told anyone?",
  "What is your worst habit?",
  "What is your biggest regret?",
  "Have you ever stolen anything?",
  "What's the most embarrassing thing in your room?",
  "What's the dumbest thing you've ever said?",
  "What is your strangest dream?",
  "Have you ever snooped on someone's phone?",
  "What is your most embarrassing phase?",
  "Have you ever faked being sick?",
  "What's the most awkward date you've been on?",
  "What's the weirdest thing you've eaten?",
  "What's a movie you secretly love but pretend to hate?",
  "Who is the last person you searched on social media?",
  "What's the most money you've ever spent on something useless?",
  "Have you ever regifted a present?",
  "What's your most irrational fear?",
  "What's the most embarrassing nickname you've had?",
  "Have you ever eavesdropped on a conversation?",
  "What's a lie you told to get out of doing something?",
  "What's the worst advice you've ever taken?"
];

const List<String> dares = [
  "Do 10 pushups.",
  "Let someone write a word on your forehead.",
  "Sing the chorus of a pop song loudly.",
  "Do your best dance move for 30 seconds.",
  "Talk with a fake accent for the next 3 rounds.",
  "Eat a spoonful of a condiment of the group's choice.",
  "Let someone draw a mustache on your face.",
  "Act like a monkey until it's your turn again.",
  "Call a random contact and sing happy birthday.",
  "Wear your socks on your hands for the next 3 rounds.",
  "Do 20 jumping jacks.",
  "Attempt to do a cartwheel.",
  "Speak only in whispers for the next 10 minutes.",
  "Let the group choose a new hairstyle for you.",
  "Walk backwards for the next 5 minutes.",
  "Try to touch your nose with your tongue.",
  "Make an animal sound loudly.",
  "Hold your breath for 10 seconds.",
  "Keep your eyes closed until your next turn.",
  "Act like a robot for the next 3 rounds.",
  "Balance a spoon on your nose for 10 seconds.",
  "Draw a picture blindfolded.",
  "Try to juggle 3 items.",
  "Pretend to be a waiter and take everyone's order.",
  "Do a dramatic reading of a random text message.",
  "Stand on one leg for a minute.",
  "Make a funny face and hold it for 15 seconds.",
  "Act like a statue for 30 seconds.",
  "Speak in a high-pitched voice for the next 3 rounds.",
  "Give a 1-minute speech on a random topic chosen by the group."
];

class TodNotifier extends Notifier<TodState> {
  StreamSubscription? _networkSubscription;
  bool _isHost = false;

  // Cancellable timer replaces the old Future.delayed which could fire after
  // the provider was disposed, causing "setState after dispose" crashes.
  Timer? _spinTimer;

  @override
  TodState build() {
    _listenToNetwork();

    ref.onDispose(() {
      _networkSubscription?.cancel();
      _spinTimer?.cancel();
    });

    return const TodState();
  }

  /// Set the host role for network subscriptions.
  void setHost(bool isHost) {
    _isHost = isHost;
  }

  void _listenToNetwork() {
    // Only subscribe to the relevant stream based on role.
    // Host listens to server stream, client listens to client stream.
    if (_isHost) {
      final serverManager = ref.read(tcpServerProvider);
      _networkSubscription = serverManager.messageStream.listen((msg) {
        if (msg['type'] == 'tod_spin') {
          _handleIncomingSpin(msg);
        }
      });
    } else {
      final clientManager = ref.read(tcpClientProvider);
      _networkSubscription = clientManager.messageStream.listen((msg) {
        if (msg['type'] == 'tod_spin') {
          _handleIncomingSpin(msg);
        }
      });
    }
  }

  void _handleIncomingSpin(Map<String, dynamic> msg) {
    if (state.mode == TodMode.networked) {
      final promptType = msg['promptType'] == 'truth' ? PromptType.truth : PromptType.dare;
      final promptText = msg['promptText'] as String;
      final playerId = msg['playerId'] as String;
      final playerName = msg['playerName'] as String;

      state = state.copyWith(
        isSpinning: true,
        activePlayerId: playerId,
        activePlayerName: playerName,
        currentPromptType: promptType,
        currentPromptText: promptText,
      );

      _startSpinTimer();
    }
  }

  void setMode(TodMode mode) {
    state = state.copyWith(mode: mode);
  }

  void spin() {
    if (state.isSpinning) return;

    final random = Random();
    final isTruth = random.nextBool();
    final promptType = isTruth ? PromptType.truth : PromptType.dare;
    final list = isTruth ? truths : dares;
    final promptText = list[random.nextInt(list.length)];

    String playerId = '';
    String playerName = '';

    if (state.mode == TodMode.networked) {
      final players = ref.read(lobbyProvider);
      if (players.isNotEmpty) {
        // Simple rotation based on current active player
        int currentIndex = players.indexWhere((p) => p.id == state.activePlayerId);
        int nextIndex = ((currentIndex + 1) % players.length).toInt();
        playerId = players[nextIndex].id;
        playerName = players[nextIndex].name;
      }
    }

    // Set local state
    state = state.copyWith(
      isSpinning: true,
      activePlayerId: playerId,
      activePlayerName: playerName,
      currentPromptType: promptType,
      currentPromptText: promptText,
    );

    // Broadcast if networked — host broadcasts, client sends to host
    if (state.mode == TodMode.networked) {
      final msg = {
        'type': 'tod_spin',
        'promptType': isTruth ? 'truth' : 'dare',
        'promptText': promptText,
        'playerId': playerId,
        'playerName': playerName,
      };
      if (_isHost) {
        ref.read(tcpServerProvider).broadcastMessage(msg);
      } else {
        ref.read(tcpClientProvider).sendMessage(msg);
      }
    }

    _startSpinTimer();
  }

  /// Starts a cancellable 3-second timer that ends the spin animation.
  /// Cancels any previous timer to prevent overlapping callbacks.
  void _startSpinTimer() {
    _spinTimer?.cancel();
    _spinTimer = Timer(const Duration(seconds: 3), () {
      state = state.copyWith(isSpinning: false);
    });
  }
}

final todProvider = NotifierProvider<TodNotifier, TodState>(() {
  return TodNotifier();
});
