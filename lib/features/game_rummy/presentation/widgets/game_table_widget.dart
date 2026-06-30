import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';
import 'package:pocket_party/features/game_rummy/presentation/widgets/card_widget.dart';

/// The central table area showing the stock pile, discard pile,
/// and wild joker indicator.
class GameTableWidget extends StatelessWidget {
  final List<PlayingCard> stockPile;
  final List<PlayingCard> discardPile;
  final PlayingCard? wildJokerCard;
  final bool canDraw;
  final VoidCallback onDrawFromStock;
  final VoidCallback onDrawFromDiscard;
  final double cardWidth;

  const GameTableWidget({
    super.key,
    required this.stockPile,
    required this.discardPile,
    this.wildJokerCard,
    required this.canDraw,
    required this.onDrawFromStock,
    required this.onDrawFromDiscard,
    this.cardWidth = 60,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = cardWidth * 1.4;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E).withValues(alpha: 0.71),
            const Color(0xFF16213E).withValues(alpha: 0.71),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── Wild Joker indicator ──
          _WildJokerIndicator(
            wildCard: wildJokerCard,
            cardWidth: cardWidth * 0.65,
          ),

          // ── Stock pile (face-down) ──
          _PileWidget(
            label: 'STOCK',
            count: stockPile.length,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            canTap: canDraw && stockPile.isNotEmpty,
            onTap: onDrawFromStock,
            child: _buildStockPile(cardWidth, cardHeight),
          ),

          // ── Discard pile (face-up) ──
          _PileWidget(
            label: 'DISCARD',
            count: discardPile.length,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            canTap: canDraw && discardPile.isNotEmpty,
            onTap: onDrawFromDiscard,
            child: _buildDiscardPile(cardWidth, cardHeight),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms).scale(
      begin: const Offset(0.95, 0.95),
      duration: 400.ms,
      curve: Curves.easeOut,
    );
  }

  Widget _buildStockPile(double w, double h) {
    if (stockPile.isEmpty) {
      return _EmptyPileSlot(width: w, height: h);
    }
    // Stacked face-down cards with slight offset
    return SizedBox(
      width: w + 4,
      height: h + 4,
      child: Stack(
        children: [
          if (stockPile.length > 2)
            Positioned(
              left: 4, top: 4,
              child: PlayingCardWidget(isFaceDown: true, width: w),
            ),
          if (stockPile.length > 1)
            Positioned(
              left: 2, top: 2,
              child: PlayingCardWidget(isFaceDown: true, width: w),
            ),
          Positioned(
            left: 0, top: 0,
            child: PlayingCardWidget(isFaceDown: true, width: w),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscardPile(double w, double h) {
    if (discardPile.isEmpty) {
      return _EmptyPileSlot(width: w, height: h);
    }
    return PlayingCardWidget(
      card: discardPile.last,
      width: w,
      isWildJoker: wildJokerCard != null &&
          discardPile.last.isWildJoker(wildJokerCard),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────

class _WildJokerIndicator extends StatelessWidget {
  final PlayingCard? wildCard;
  final double cardWidth;

  const _WildJokerIndicator({this.wildCard, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'WILD',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF00F2FE).withValues(alpha: 0.78),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        if (wildCard != null)
          PlayingCardWidget(
            card: wildCard,
            width: cardWidth,
            isWildJoker: true,
          ).animate(
            onPlay: (c) => c.repeat(reverse: true),
          ).shimmer(
            duration: 2000.ms,
            color: const Color(0xFF00F2FE).withValues(alpha: 0.24),
          )
        else
          SizedBox(
            width: cardWidth,
            height: cardWidth * 1.4,
            child: const Center(
              child: Text('?', style: TextStyle(color: Colors.white38, fontSize: 20)),
            ),
          ),
      ],
    );
  }
}

class _PileWidget extends StatelessWidget {
  final String label;
  final int count;
  final double cardWidth;
  final double cardHeight;
  final bool canTap;
  final VoidCallback onTap;
  final Widget child;

  const _PileWidget({
    required this.label,
    required this.count,
    required this.cardWidth,
    required this.cardHeight,
    required this.canTap,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.47),
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: canTap ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: canTap
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.16),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: child,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.39),
          ),
        ),
      ],
    );
  }
}

class _EmptyPileSlot extends StatelessWidget {
  final double width;
  final double height;

  const _EmptyPileSlot({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Center(
        child: Icon(
          Icons.layers_clear,
          size: 18,
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}
