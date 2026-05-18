import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../domain/spyfall_state.dart';
import '../providers/spyfall_provider.dart';

class SpyfallScreen extends ConsumerWidget {
  const SpyfallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(spyfallProvider);
    final notifier = ref.read(spyfallProvider.notifier);

    // Dark red and black theme colors
    const bgColor = Color(0xFF110000);
    const cardColor = Color(0xFF1A1A1A);
    const accentColor = Color(0xFF8B0000); // Dark Red
    const textColor = Colors.white70;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          'SPYFALL',
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: accentColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.mode == GameMode.localPassAndPlay && !state.isGameOver)
                _buildPassAndPlayHeader(state, textColor, accentColor),
                
              if (state.mode == GameMode.networked)
                _buildNetworkHeader(textColor, accentColor),

              if (state.isGameOver && state.mode == GameMode.localPassAndPlay)
                _buildGameOver(notifier, textColor, accentColor)
              else
                Expanded(
                  child: Center(
                    child: _buildRoleCard(state, notifier, cardColor, accentColor, textColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassAndPlayHeader(SpyfallState state, Color textColor, Color accentColor) {
    if (state.players.isEmpty) return const SizedBox.shrink();
    final currentPlayer = state.players[state.currentPlayerIndex];
    return Column(
      children: [
        Text(
          'PASS DEVICE TO',
          style: TextStyle(color: textColor, fontSize: 16, letterSpacing: 1.5),
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: 8),
        Text(
          currentPlayer.toUpperCase(),
          style: TextStyle(
            color: accentColor,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      ],
    );
  }

  Widget _buildNetworkHeader(Color textColor, Color accentColor) {
    return Column(
      children: [
        Text(
          'YOUR ROLE',
          style: TextStyle(color: textColor, fontSize: 16, letterSpacing: 1.5),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }

  Widget _buildGameOver(SpyfallNotifier notifier, Color textColor, Color accentColor) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, color: accentColor, size: 80)
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 2.seconds, color: Colors.red),
          const SizedBox(height: 24),
          Text(
            'TIME TO START QUESTIONING!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => notifier.restartLocalGame(),
            child: const Text('RESTART GAME', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    SpyfallState state, 
    SpyfallNotifier notifier, 
    Color cardColor, 
    Color accentColor, 
    Color textColor
  ) {
    String roleText = 'UNKNOWN';
    String subText = '';
    bool isSpy = false;

    if (state.mode == GameMode.localPassAndPlay) {
      if (state.players.isNotEmpty) {
        final currentPlayer = state.players[state.currentPlayerIndex];
        roleText = state.playerRoles[currentPlayer] ?? 'UNKNOWN';
        isSpy = roleText == 'Spy';
        subText = isSpy ? 'Try to figure out the location.' : 'Try to find the Spy.';
      }
    } else {
      if (state.localPlayerId != null) {
        roleText = state.playerRoles[state.localPlayerId] ?? 'UNKNOWN';
        isSpy = roleText == 'Spy';
        subText = isSpy ? 'Try to figure out the location.' : 'Try to find the Spy.';
      }
    }

    return GestureDetector(
      onTap: () => notifier.toggleReveal(),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeInBack,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            child: child,
            builder: (context, widget) {
              final isUnder = (ValueKey(state.isRoleRevealed) != widget?.key);
              var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
              tilt *= isUnder ? -1.0 : 1.0;
              final value = isUnder ? min(rotateAnim.value, pi / 2) : rotateAnim.value;
              return Transform(
                transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                alignment: Alignment.center,
                child: widget,
              );
            },
          );
        },
        child: state.isRoleRevealed
            ? _buildCardFront(
                key: const ValueKey(true),
                roleText: roleText,
                subText: subText,
                isSpy: isSpy,
                cardColor: cardColor,
                accentColor: accentColor,
                textColor: textColor,
                notifier: notifier,
                mode: state.mode,
              )
            : _buildCardBack(
                key: const ValueKey(false),
                cardColor: cardColor,
                accentColor: accentColor,
                textColor: textColor,
              ),
      ),
    );
  }

  Widget _buildCardBack(
      {required Key key, required Color cardColor, required Color accentColor, required Color textColor}) {
    return Container(
      key: key,
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fingerprint, size: 80, color: accentColor.withOpacity(0.5))
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fade(duration: 1.seconds, begin: 0.3, end: 0.7),
          const SizedBox(height: 32),
          Text(
            'TAP TO REVEAL\nYOUR ROLE',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront({
    required Key key,
    required String roleText,
    required String subText,
    required bool isSpy,
    required Color cardColor,
    required Color accentColor,
    required Color textColor,
    required SpyfallNotifier notifier,
    required GameMode mode,
  }) {
    final displayColor = isSpy ? accentColor : Colors.blueGrey.shade700;
    
    return Container(
      key: key,
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: displayColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: displayColor.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  isSpy ? Icons.visibility_off : Icons.location_on,
                  size: 60,
                  color: displayColor,
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(
                  isSpy ? 'YOU ARE THE' : 'LOCATION',
                  style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14, letterSpacing: 2.0),
                ),
                const SizedBox(height: 8),
                Text(
                  roleText.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: displayColor,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 16),
                Text(
                  subText,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16),
                ).animate().fadeIn(delay: 400.ms),
              ],
            ),
          ),
          if (mode == GameMode.localPassAndPlay)
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: displayColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  notifier.nextPlayer();
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('HIDE & NEXT PLAYER', style: TextStyle(fontWeight: FontWeight.bold)),
              ).animate().fadeIn(delay: 600.ms),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 32.0),
              child: Text('Tap anywhere to hide', style: TextStyle(color: Colors.white38)),
            ),
        ],
      ),
    );
  }
}
