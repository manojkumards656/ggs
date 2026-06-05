import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/providers/network_providers.dart';
import '../domain/providers/hangman_provider.dart';
import '../domain/models/hangman_state.dart';
import 'hangman_figure.dart';

class HangmanScreen extends ConsumerStatefulWidget {
  final bool isNetworked;
  final bool isHost; 

  const HangmanScreen({
    super.key,
    this.isNetworked = false,
    this.isHost = false,
  });

  @override
  ConsumerState<HangmanScreen> createState() => _HangmanScreenState();
}

class _HangmanScreenState extends ConsumerState<HangmanScreen> {
  final TextEditingController _wordController = TextEditingController();
  StreamSubscription? _tcpSub;
  int _wiggleKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hangmanProvider.notifier).reset();
      if (widget.isNetworked) {
        _setupNetwork();
      }
    });
  }
  
  void _setupNetwork() {
    if (widget.isHost) {
      final tcpServer = ref.read(tcpServerProvider);
      _tcpSub = tcpServer.messageStream.listen((msg) {
        if (!mounted) return;
        if (msg['type'] == 'hangman_guess') {
          final oldLives = ref.read(hangmanProvider).remainingLives;
          ref.read(hangmanProvider.notifier).guessLetter(msg['letter']);
          
          final newLives = ref.read(hangmanProvider).remainingLives;
          if (newLives < oldLives) _triggerWiggle();
          
          _broadcastState();
        }
      });
    } else {
      final tcpClient = ref.read(tcpClientProvider);
      _tcpSub = tcpClient.messageStream.listen((msg) {
        if (!mounted) return;
        if (msg['type'] == 'hangman_state') {
          final newState = HangmanState.fromJson(msg['state']);
          
          final oldState = ref.read(hangmanProvider);
          if (newState.remainingLives < oldState.remainingLives) {
            _triggerWiggle();
          }
          
          ref.read(hangmanProvider.notifier).setState(newState);
        }
      });
    }
  }

  void _broadcastState() {
    if (widget.isNetworked && widget.isHost) {
      final state = ref.read(hangmanProvider);
      ref.read(tcpServerProvider).broadcastMessage({
        'type': 'hangman_state',
        'state': state.toJson(),
      });
    }
  }

  void _triggerWiggle() {
    setState(() {
      _wiggleKey++;
    });
  }

  void _setWord() {
    final word = _wordController.text.trim();
    if (word.isNotEmpty) {
      ref.read(hangmanProvider.notifier).setWord(word);
      _broadcastState();
    }
  }

  void _guess(String letter) {
    final state = ref.read(hangmanProvider);
    if (state.guessedLetters.contains(letter)) return;
    
    if (widget.isNetworked) {
      if (!widget.isHost) {
        ref.read(tcpClientProvider).sendMessage({
          'type': 'hangman_guess',
          'letter': letter,
        });
      }
    } else {
      final oldLives = state.remainingLives;
      ref.read(hangmanProvider.notifier).guessLetter(letter);
      final newLives = ref.read(hangmanProvider).remainingLives;
      
      if (newLives < oldLives) {
        _triggerWiggle();
      }
    }
  }

  @override
  void dispose() {
    _tcpSub?.cancel();
    _wordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hangmanProvider);
    final isSettingWord = state.secretWord.isEmpty;

    bool canGuess = false;
    if (!isSettingWord && !state.isGameOver && !state.isGameWon) {
      if (widget.isNetworked) {
        canGuess = !widget.isHost; // Clients guess
      } else {
        canGuess = true; // Pass & Play
      }
    }

    Widget content;
    if (isSettingWord) {
      bool canSet = !widget.isNetworked || widget.isHost;
      if (canSet) {
        content = Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.isNetworked ? 'Host: Set the Secret Word' : 'Player 1: Set the Secret Word',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _wordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelText: 'Secret Word',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: Colors.white10,
                ),
                onSubmitted: (_) => _setWord(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _setWord,
                child: const Text('Start Game', style: TextStyle(fontSize: 18)),
              )
            ],
          ),
        );
      } else {
        content = const Center(
          child: Text('Waiting for Host to set the word...', style: TextStyle(fontSize: 20, color: Colors.white)),
        );
      }
    } else {
      content = Column(
        children: [
          const SizedBox(height: 24),
          HangmanFigure(remainingLives: state.remainingLives, maxLives: state.maxLives),
          
          const SizedBox(height: 32),
          
          Wrap(
            spacing: 8,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: state.secretWord.toUpperCase().split('').map((char) {
              if (char == ' ') return const SizedBox(width: 20);
              final isRevealed = state.guessedLetters.contains(char) || state.isGameOver;
              return Container(
                width: 40,
                height: 50,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white, width: 3)),
                ),
                child: Text(
                  isRevealed ? char : '',
                  style: TextStyle(
                    fontSize: 32, 
                    fontWeight: FontWeight.bold,
                    color: (state.isGameOver && !state.guessedLetters.contains(char)) 
                        ? Colors.redAccent 
                        : Colors.white,
                  ),
                ).animate(target: isRevealed ? 1 : 0).fadeIn().scale(),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          
          if (state.isGameOver)
            const Text('GAME OVER', style: TextStyle(fontSize: 32, color: Colors.redAccent, fontWeight: FontWeight.bold))
              .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              
          if (state.isGameWon)
            const Text('YOU WIN!', style: TextStyle(fontSize: 32, color: Colors.greenAccent, fontWeight: FontWeight.bold))
              .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              
          const Spacer(),
          
          if (canGuess)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
                  final isGuessed = state.guessedLetters.contains(letter);
                  return GestureDetector(
                    onTap: isGuessed ? null : () => _guess(letter),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isGuessed ? Colors.white10 : Colors.blueAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: isGuessed ? Colors.white30 : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else if (!widget.isNetworked && !isSettingWord)
            const SizedBox.shrink()
          else if (widget.isHost)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Clients are guessing...', style: TextStyle(fontSize: 18, color: Colors.white54)),
            ),
            
          const SizedBox(height: 24),
        ],
      );
    }

    Widget scaffold = Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      appBar: AppBar(
        title: const Text('Hangman', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: content,
    );

    if (_wiggleKey > 0) {
      scaffold = scaffold
          .animate(key: ValueKey(_wiggleKey))
          .shakeX(amount: 10, duration: 400.ms);
    }

    return scaffold;
  }
}
