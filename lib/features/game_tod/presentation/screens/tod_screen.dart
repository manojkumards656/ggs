import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/providers/tod_provider.dart';
import '../../domain/models/tod_state.dart';

class TodScreen extends ConsumerWidget {
  const TodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(todProvider);
    final notifier = ref.read(todProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Truth or Dare'),
        actions: [
          Row(
            children: [
              Text(
                state.mode == TodMode.networked ? 'Networked' : 'Pass & Play',
                style: const TextStyle(fontSize: 12),
              ),
              Switch(
                value: state.mode == TodMode.networked,
                onChanged: (val) {
                  notifier.setMode(val ? TodMode.networked : TodMode.passAndPlay);
                },
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ],
          )
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (state.mode == TodMode.passAndPlay) {
            notifier.spin();
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (state.mode == TodMode.networked && state.activePlayerName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Text(
                    "${state.activePlayerName}'s Turn!",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate(key: ValueKey(state.activePlayerId))
                   .fadeIn(duration: 400.ms)
                   .slideY(begin: -0.5, end: 0),
                ),
              
              // Spinner
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.local_drink,
                    size: 80,
                    color: Theme.of(context).colorScheme.secondary,
                  )
                  .animate(
                    target: state.isSpinning ? 1 : 0,
                  )
                  .custom(
                    duration: 3.seconds,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      // value goes from 0 to 1 when target is 1
                      // we want it to spin many times. 
                      // 10 full rotations = 10 * 2pi = 20pi
                      return Transform.rotate(
                        angle: value * 20 * 3.14159,
                        child: child,
                      );
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),

              // The Result Card
              if (!state.isSpinning && state.currentPromptType != PromptType.none)
                Card(
                  elevation: 8,
                  shadowColor: state.currentPromptType == PromptType.truth 
                      ? Colors.blueAccent 
                      : Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: Theme.of(context).colorScheme.surface,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          state.currentPromptType == PromptType.truth ? "TRUTH" : "DARE",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: state.currentPromptType == PromptType.truth 
                                ? Colors.blueAccent 
                                : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.currentPromptText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate()
                 .scale(duration: 500.ms, curve: Curves.easeOutBack)
                 .fadeIn(duration: 400.ms),
              
              if (state.isSpinning)
                const SizedBox(height: 150), // placeholder so things don't jump around too much

              const SizedBox(height: 40),

              if (state.mode == TodMode.networked && !state.isSpinning)
                ElevatedButton.icon(
                  onPressed: () => notifier.spin(),
                  icon: const Icon(Icons.skip_next),
                  label: const Text("Next Player"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                  ),
                ).animate().fadeIn(delay: 500.ms),

              if (state.mode == TodMode.passAndPlay && !state.isSpinning)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "Tap anywhere to spin!",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .fade(begin: 0.5, end: 1.0, duration: 1.seconds),
            ],
          ),
        ),
      ),
    );
  }
}
