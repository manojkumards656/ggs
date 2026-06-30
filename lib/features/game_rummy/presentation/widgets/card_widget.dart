import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pocket_party/features/game_rummy/domain/models/rummy_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants — keep top-level so the compiler can inline them.
// ─────────────────────────────────────────────────────────────────────────────

const Color _kCardFace = Color(0xFFFEF9F0); // warm white
const Color _kRedSuit = Color(0xFFD32F2F);
const Color _kBlackSuit = Color(0xFF1A1A2E);
const Color _kCardBack = Color(0xFF1A1A2E);
const Color _kGold = Color(0xFFCFAE70);
const Color _kCyan = Color(0xFF00F2FE);

// Normalized card coordinate system: 500 × 700
const double _kNW = 500;
const double _kNH = 700;
const double _kCornerRadius = 6;
const double _kAspect = 5 / 7;

// ─────────────────────────────────────────────────────────────────────────────
// PlayingCardWidget
// ─────────────────────────────────────────────────────────────────────────────

/// Renders a single playing card using [CustomPainter].
///
/// * If [card] is `null` or [isFaceDown] is `true`, the card back is shown.
/// * [isSelected] adds a glowing cyan border and slight pop-up.
/// * [isWildJoker] paints a cyan **W** badge in the top-right corner.
class PlayingCardWidget extends StatelessWidget {
  const PlayingCardWidget({
    super.key,
    this.card,
    this.isFaceDown = false,
    this.isSelected = false,
    this.isWildJoker = false,
    required this.width,
    this.onTap,
  });

  final PlayingCard? card;
  final bool isFaceDown;
  final bool isSelected;
  final bool isWildJoker;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double height = width / _kAspect;
    final bool showBack = card == null || isFaceDown;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isSelected ? -4 : 0, 0),
        width: width,
        height: height,
        child: CustomPaint(
          size: Size(width, height),
          painter: showBack
              ? _CardBackPainter()
              : _CardFacePainter(
                  card: card!,
                  isSelected: isSelected,
                  isWildJoker: isWildJoker,
                ),
          foregroundPainter: isSelected ? _GlowBorderPainter() : null,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD FACE PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _CardFacePainter extends CustomPainter {
  _CardFacePainter({
    required this.card,
    required this.isSelected,
    required this.isWildJoker,
  });

  final PlayingCard card;
  final bool isSelected;
  final bool isWildJoker;

  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _kNW;
    final double sy = size.height / _kNH;
    final double r = _kCornerRadius * sx;
    final RRect cardRect = RRect.fromLTRBR(0, 0, size.width, size.height, Radius.circular(r));

    // ── Drop shadow ──
    final shadowPaint = Paint()
      ..color = Colors.black54
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * sx);
    canvas.drawRRect(cardRect.shift(Offset(1.5 * sx, 2 * sy)), shadowPaint);

    // ── Card body ──
    canvas.drawRRect(cardRect, Paint()..color = _kCardFace);

    // Clip to rounded rect for safety
    canvas.save();
    canvas.clipRRect(cardRect);

    // ── Subtle border ──
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = const Color(0xFFD0D0D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * sx,
    );

    final Color suitColor = card.isPrintedJoker
        ? const Color(0xFF6A1B9A)
        : card.isRed
            ? _kRedSuit
            : _kBlackSuit;

    // ── Corner labels ──
    _paintCornerLabels(canvas, size, sx, sy, suitColor);

    // ── Centre artwork ──
    if (card.isPrintedJoker) {
      _paintJokerCentre(canvas, size, sx, sy);
    } else if (card.rank == 1) {
      _paintAce(canvas, size, sx, sy, suitColor);
    } else if (card.rank >= 2 && card.rank <= 10) {
      _paintPips(canvas, size, sx, sy, suitColor);
    } else {
      _paintFaceCard(canvas, size, sx, sy, suitColor);
    }

    // ── Wild joker badge ──
    if (isWildJoker) {
      _paintWildBadge(canvas, size, sx, sy);
    }

    canvas.restore();
  }

  // ── Corner rank + suit ──
  void _paintCornerLabels(Canvas canvas, Size size, double sx, double sy, Color color) {
    final String rankStr = card.rankSymbol;
    final String suitStr = card.suitSymbol;

    final double rankFontSize = 60 * sy;
    final double suitFontSize = 50 * sy;
    final double leftPad = 20 * sx;
    final double topPad = 18 * sy;

    // Top-left rank
    _drawText(
      canvas,
      rankStr,
      Offset(leftPad, topPad),
      rankFontSize,
      color,
      fontWeight: FontWeight.w800,
    );

    // Top-left suit
    if (!card.isPrintedJoker) {
      _drawText(
        canvas,
        suitStr,
        Offset(leftPad + 2 * sx, topPad + rankFontSize * 0.85),
        suitFontSize,
        color,
      );
    }

    // Bottom-right (rotated 180°)
    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.rotate(math.pi);

    _drawText(
      canvas,
      rankStr,
      Offset(leftPad, topPad),
      rankFontSize,
      color,
      fontWeight: FontWeight.w800,
    );

    if (!card.isPrintedJoker) {
      _drawText(
        canvas,
        suitStr,
        Offset(leftPad + 2 * sx, topPad + rankFontSize * 0.85),
        suitFontSize,
        color,
      );
    }

    canvas.restore();
  }

  // ── Ace ──
  void _paintAce(Canvas canvas, Size size, double sx, double sy, Color color) {
    final double bigSize = 200 * sy;
    final suitStr = card.suitSymbol;
    _drawText(
      canvas,
      suitStr,
      Offset(size.width / 2, size.height / 2 - bigSize * 0.45),
      bigSize,
      color,
      align: TextAlign.center,
      anchorX: true,
    );

    // Decorative circle behind ace
    final acePaint = Paint()
      ..color = color.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      90 * sx,
      acePaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      90 * sx,
      Paint()
        ..color = color.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * sx,
    );
  }

  // ── Number cards 2–10: pip patterns ──
  void _paintPips(Canvas canvas, Size size, double sx, double sy, Color color) {
    final double pipSize = 64 * sy;
    final String sym = card.suitSymbol;

    // Pip positions in normalized coords (origin = centre of card).
    // x: left=-1, centre=0, right=1
    // y: positions from top to bottom
    final List<Offset> positions = _pipLayout(card.rank);

    // Map normalised positions to canvas coords.
    // x: left col ~160, centre ~250, right col ~340  (of 500)
    // y: mapped within the middle zone (y ∈ 110..590 of 700)
    const double cx = _kNW / 2; // 250
    const double colSpan = 90; // half-distance between L/R columns
    const double yTop = 140;
    const double yBot = 560;
    final double ySpan = yBot - yTop;

    for (final pos in positions) {
      final double px = (cx + pos.dx * colSpan) * sx;
      final double py = (yTop + pos.dy * ySpan) * sy;

      // Pips in the lower half are drawn upside-down on real cards
      final bool flip = pos.dy > 0.55;

      if (flip) {
        canvas.save();
        canvas.translate(px, py + pipSize * 0.45);
        canvas.rotate(math.pi);
        _drawText(canvas, sym, Offset(-pipSize * 0.25, -pipSize * 0.45), pipSize, color);
        canvas.restore();
      } else {
        _drawText(
          canvas,
          sym,
          Offset(px, py),
          pipSize,
          color,
          anchorX: true,
        );
      }
    }
  }

  // ── Face cards (J, Q, K) ──
  void _paintFaceCard(Canvas canvas, Size size, double sx, double sy, Color color) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Decorative frame
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 260 * sx, height: 360 * sy),
      Radius.circular(12 * sx),
    );
    canvas.drawRRect(
      frameRect,
      Paint()
        ..color = color.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      frameRect,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * sx,
    );

    // Inner frame
    final innerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 230 * sx, height: 330 * sy),
      Radius.circular(8 * sx),
    );
    canvas.drawRRect(
      innerRect,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * sx,
    );

    // Large letter
    final double letterSize = 180 * sy;
    _drawText(
      canvas,
      card.rankSymbol,
      Offset(cx, cy - letterSize * 0.48),
      letterSize,
      color.withValues(alpha: 0.85),
      fontWeight: FontWeight.w900,
      align: TextAlign.center,
      anchorX: true,
    );

    // Suit decorations — four small suits in corners of the frame
    final double deco = 42 * sy;
    final double dx = 100 * sx;
    final double dy = 140 * sy;
    for (final off in [
      Offset(cx - dx, cy - dy),
      Offset(cx + dx, cy - dy),
      Offset(cx - dx, cy + dy),
      Offset(cx + dx, cy + dy),
    ]) {
      _drawText(canvas, card.suitSymbol, off, deco, color.withValues(alpha: 0.45), anchorX: true);
    }

    // Horizontal ornamental lines
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 1.5 * sx;
    canvas.drawLine(
      Offset(cx - 110 * sx, cy - 160 * sy),
      Offset(cx + 110 * sx, cy - 160 * sy),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx - 110 * sx, cy + 160 * sy),
      Offset(cx + 110 * sx, cy + 160 * sy),
      linePaint,
    );
  }

  // ── Printed Joker ──
  void _paintJokerCentre(Canvas canvas, Size size, double sx, double sy) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Rainbow gradient circle
    final Rect gradRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: 200 * sx,
      height: 200 * sy,
    );
    final gradPaint = Paint()
      ..shader = ui.Gradient.sweep(
        Offset(cx, cy),
        [
          const Color(0xFFFF6B6B),
          const Color(0xFFFFD93D),
          const Color(0xFF6BCB77),
          const Color(0xFF4D96FF),
          const Color(0xFFC084FC),
          const Color(0xFFFF6B6B),
        ],
        [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 * sx;
    canvas.drawOval(gradRect.deflate(20 * sx), gradPaint);

    // Filled translucent
    canvas.drawOval(
      gradRect.deflate(20 * sx),
      Paint()
        ..shader = ui.Gradient.sweep(
          Offset(cx, cy),
          [
            const Color(0x22FF6B6B),
            const Color(0x22FFD93D),
            const Color(0x226BCB77),
            const Color(0x224D96FF),
            const Color(0x22C084FC),
            const Color(0x22FF6B6B),
          ],
          [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        ),
    );

    // Star
    _drawText(
      canvas,
      '★',
      Offset(cx, cy - 80 * sy),
      160 * sy,
      const Color(0xFF6A1B9A),
      fontWeight: FontWeight.w900,
      anchorX: true,
    );

    // JOKER text
    _drawText(
      canvas,
      'JOKER',
      Offset(cx, cy + 70 * sy),
      36 * sy,
      const Color(0xFF6A1B9A),
      fontWeight: FontWeight.w800,
      anchorX: true,
      letterSpacing: 6 * sx,
    );
  }

  // ── Wild badge ──
  void _paintWildBadge(Canvas canvas, Size size, double sx, double sy) {
    final double bx = size.width - 34 * sx;
    final double by = 18 * sy;
    final double br = 16 * sx;

    // Glow
    canvas.drawCircle(
      Offset(bx, by + br),
      br + 4 * sx,
      Paint()
        ..color = _kCyan.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * sx),
    );

    // Badge circle
    canvas.drawCircle(
      Offset(bx, by + br),
      br,
      Paint()..color = _kCyan,
    );

    // W letter
    _drawText(
      canvas,
      'W',
      Offset(bx, by + br * 0.25),
      24 * sy,
      const Color(0xFF0F0C29),
      fontWeight: FontWeight.w900,
      anchorX: true,
    );
  }

  // ── Helper: draw text ──
  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color, {
    FontWeight fontWeight = FontWeight.w600,
    TextAlign align = TextAlign.left,
    bool anchorX = false,
    double letterSpacing = 0,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: 1.0,
          letterSpacing: letterSpacing > 0 ? letterSpacing : null,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();

    final Offset paintOffset =
        anchorX ? Offset(offset.dx - tp.width / 2, offset.dy) : offset;
    tp.paint(canvas, paintOffset);
  }

  @override
  bool shouldRepaint(_CardFacePainter oldDelegate) =>
      card != oldDelegate.card ||
      isSelected != oldDelegate.isSelected ||
      isWildJoker != oldDelegate.isWildJoker;
}

// ─────────────────────────────────────────────────────────────────────────────
// PIP LAYOUTS — normalised positions (dx ∈ {-1,0,1}, dy ∈ [0,1])
// ─────────────────────────────────────────────────────────────────────────────

List<Offset> _pipLayout(int rank) {
  return switch (rank) {
    2 => const [
      Offset(0, 0.0), // top centre
      Offset(0, 1.0), // bottom centre
    ],
    3 => const [
      Offset(0, 0.0),
      Offset(0, 0.5),
      Offset(0, 1.0),
    ],
    4 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    5 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(0, 0.5),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    6 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(-1, 0.5),
      Offset(1, 0.5),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    7 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(0, 0.25),
      Offset(-1, 0.5),
      Offset(1, 0.5),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    8 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(0, 0.25),
      Offset(-1, 0.5),
      Offset(1, 0.5),
      Offset(0, 0.75),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    9 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(-1, 0.333),
      Offset(1, 0.333),
      Offset(0, 0.5),
      Offset(-1, 0.667),
      Offset(1, 0.667),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    10 => const [
      Offset(-1, 0.0),
      Offset(1, 0.0),
      Offset(0, 0.167),
      Offset(-1, 0.333),
      Offset(1, 0.333),
      Offset(-1, 0.667),
      Offset(1, 0.667),
      Offset(0, 0.833),
      Offset(-1, 1.0),
      Offset(1, 1.0),
    ],
    _ => const [],
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD BACK PAINTER
// ─────────────────────────────────────────────────────────────────────────────

class _CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _kNW;
    final double sy = size.height / _kNH;
    final double r = _kCornerRadius * sx;
    final RRect outer = RRect.fromLTRBR(0, 0, size.width, size.height, Radius.circular(r));

    // ── Shadow ──
    canvas.drawRRect(
      outer.shift(Offset(1.5 * sx, 2 * sy)),
      Paint()
        ..color = Colors.black54
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * sx),
    );

    // ── Background ──
    canvas.drawRRect(outer, Paint()..color = _kCardBack);
    canvas.save();
    canvas.clipRRect(outer);

    // ── Border ──
    final insetRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(8 * sx, 8 * sy, size.width - 8 * sx, size.height - 8 * sy),
      Radius.circular(4 * sx),
    );
    canvas.drawRRect(
      insetRect,
      Paint()
        ..color = _kGold.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * sx,
    );

    // ── Diamond crosshatch pattern ──
    final goldPaint = Paint()
      ..color = _kGold.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * sx;

    const double spacing = 40; // in normalised coords
    // Diagonal lines — top-left to bottom-right
    for (double d = -_kNH; d < _kNW + _kNH; d += spacing) {
      canvas.drawLine(
        Offset(d * sx, 0),
        Offset((d + _kNH) * sx, _kNH * sy),
        goldPaint,
      );
    }
    // Diagonal lines — top-right to bottom-left
    for (double d = -_kNH; d < _kNW + _kNH; d += spacing) {
      canvas.drawLine(
        Offset((_kNW - d) * sx, 0),
        Offset((_kNW - d - _kNH) * sx, _kNH * sy),
        goldPaint,
      );
    }

    // ── Centre diamond emblem ──
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double dw = 80 * sx;
    final double dh = 110 * sy;

    final path = Path()
      ..moveTo(cx, cy - dh)
      ..lineTo(cx + dw, cy)
      ..lineTo(cx, cy + dh)
      ..lineTo(cx - dw, cy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = _kGold.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _kGold.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * sx,
    );

    // Smaller inner diamond
    final inner = Path()
      ..moveTo(cx, cy - dh * 0.5)
      ..lineTo(cx + dw * 0.5, cy)
      ..lineTo(cx, cy + dh * 0.5)
      ..lineTo(cx - dw * 0.5, cy)
      ..close();
    canvas.drawPath(
      inner,
      Paint()
        ..color = _kGold.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * sx,
    );

    // Tiny centre dot
    canvas.drawCircle(Offset(cx, cy), 4 * sx, Paint()..color = _kGold.withValues(alpha: 0.6));

    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardBackPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// GLOW BORDER PAINTER (foreground)
// ─────────────────────────────────────────────────────────────────────────────

class _GlowBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / _kNW;
    final double r = _kCornerRadius * sx;
    final RRect rrect = RRect.fromLTRBR(0, 0, size.width, size.height, Radius.circular(r));

    // Outer glow
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _kCyan.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * sx
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * sx),
    );

    // Crisp border
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _kCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * sx,
    );
  }

  @override
  bool shouldRepaint(_GlowBorderPainter oldDelegate) => false;
}
