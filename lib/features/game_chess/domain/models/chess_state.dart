import 'package:flutter/foundation.dart';

@immutable
class ChessState {
  final String boardFen;
  final int whiteTimeRemaining; // in seconds
  final int blackTimeRemaining; // in seconds
  final String activeColor; // 'w' or 'b'
  final bool isGameOver;
  final String? gameOverReason; // 'Checkmate', 'Stalemate', 'Draw', 'Timeout', 'Resignation'
  final String? winnerColor; // 'w' (White), 'b' (Black), 'draw'
  final String? selectedSquare; // e.g. 'e2'
  final List<String> validMovesForSelected; // e.g. ['e3', 'e4']
  final List<String> moveHistory; // List of moves in SAN or custom format
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final bool isCheck;
  final String whitePlayerName;
  final String blackPlayerName;
  final bool isPromotionPending;
  final String? promotionSource;
  final String? promotionTarget;
  final bool isTimed;
  final List<String> capturedWhitePieces;
  final List<String> capturedBlackPieces;

  const ChessState({
    required this.boardFen,
    required this.whiteTimeRemaining,
    required this.blackTimeRemaining,
    required this.activeColor,
    required this.isGameOver,
    this.gameOverReason,
    this.winnerColor,
    this.selectedSquare,
    this.validMovesForSelected = const [],
    this.moveHistory = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.isCheck = false,
    required this.whitePlayerName,
    required this.blackPlayerName,
    this.isPromotionPending = false,
    this.promotionSource,
    this.promotionTarget,
    this.isTimed = true,
    this.capturedWhitePieces = const [],
    this.capturedBlackPieces = const [],
  });

  factory ChessState.initial({
    String whitePlayerName = 'White',
    String blackPlayerName = 'Black',
    int initialTimeSeconds = 600, // Default 10 minutes
  }) {
    return ChessState(
      boardFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      whiteTimeRemaining: initialTimeSeconds,
      blackTimeRemaining: initialTimeSeconds,
      activeColor: 'w',
      isGameOver: false,
      whitePlayerName: whitePlayerName,
      blackPlayerName: blackPlayerName,
      isTimed: initialTimeSeconds > 0,
      capturedWhitePieces: const [],
      capturedBlackPieces: const [],
    );
  }

  ChessState copyWith({
    String? boardFen,
    int? whiteTimeRemaining,
    int? blackTimeRemaining,
    String? activeColor,
    bool? isGameOver,
    String? gameOverReason,
    String? winnerColor,
    String? selectedSquare,
    List<String>? validMovesForSelected,
    List<String>? moveHistory,
    String? lastMoveFrom,
    String? lastMoveTo,
    bool? isCheck,
    String? whitePlayerName,
    String? blackPlayerName,
    bool? isPromotionPending,
    String? promotionSource,
    String? promotionTarget,
    bool? isTimed,
    List<String>? capturedWhitePieces,
    List<String>? capturedBlackPieces,
  }) {
    return ChessState(
      boardFen: boardFen ?? this.boardFen,
      whiteTimeRemaining: whiteTimeRemaining ?? this.whiteTimeRemaining,
      blackTimeRemaining: blackTimeRemaining ?? this.blackTimeRemaining,
      activeColor: activeColor ?? this.activeColor,
      isGameOver: isGameOver ?? this.isGameOver,
      gameOverReason: gameOverReason ?? this.gameOverReason,
      winnerColor: winnerColor ?? this.winnerColor,
      selectedSquare: selectedSquare ?? this.selectedSquare,
      validMovesForSelected: validMovesForSelected ?? this.validMovesForSelected,
      moveHistory: moveHistory ?? this.moveHistory,
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      isCheck: isCheck ?? this.isCheck,
      whitePlayerName: whitePlayerName ?? this.whitePlayerName,
      blackPlayerName: blackPlayerName ?? this.blackPlayerName,
      isPromotionPending: isPromotionPending ?? this.isPromotionPending,
      promotionSource: promotionSource ?? this.promotionSource,
      promotionTarget: promotionTarget ?? this.promotionTarget,
      isTimed: isTimed ?? this.isTimed,
      capturedWhitePieces: capturedWhitePieces ?? this.capturedWhitePieces,
      capturedBlackPieces: capturedBlackPieces ?? this.capturedBlackPieces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'boardFen': boardFen,
      'whiteTimeRemaining': whiteTimeRemaining,
      'blackTimeRemaining': blackTimeRemaining,
      'activeColor': activeColor,
      'isGameOver': isGameOver,
      'gameOverReason': gameOverReason,
      'winnerColor': winnerColor,
      'selectedSquare': selectedSquare,
      'validMovesForSelected': validMovesForSelected,
      'moveHistory': moveHistory,
      'lastMoveFrom': lastMoveFrom,
      'lastMoveTo': lastMoveTo,
      'isCheck': isCheck,
      'whitePlayerName': whitePlayerName,
      'blackPlayerName': blackPlayerName,
      'isPromotionPending': isPromotionPending,
      'promotionSource': promotionSource,
      'promotionTarget': promotionTarget,
      'isTimed': isTimed,
      'capturedWhitePieces': capturedWhitePieces,
      'capturedBlackPieces': capturedBlackPieces,
    };
  }

  factory ChessState.fromJson(Map<String, dynamic> json) {
    return ChessState(
      boardFen: json['boardFen'] as String,
      whiteTimeRemaining: json['whiteTimeRemaining'] as int,
      blackTimeRemaining: json['blackTimeRemaining'] as int,
      activeColor: json['activeColor'] as String,
      isGameOver: json['isGameOver'] as bool,
      gameOverReason: json['gameOverReason'] as String?,
      winnerColor: json['winnerColor'] as String?,
      selectedSquare: json['selectedSquare'] as String?,
      validMovesForSelected: List<String>.from(json['validMovesForSelected'] ?? []),
      moveHistory: List<String>.from(json['moveHistory'] ?? []),
      lastMoveFrom: json['lastMoveFrom'] as String?,
      lastMoveTo: json['lastMoveTo'] as String?,
      isCheck: json['isCheck'] as bool? ?? false,
      whitePlayerName: json['whitePlayerName'] as String? ?? 'White',
      blackPlayerName: json['blackPlayerName'] as String? ?? 'Black',
      isPromotionPending: json['isPromotionPending'] as bool? ?? false,
      promotionSource: json['promotionSource'] as String?,
      promotionTarget: json['promotionTarget'] as String?,
      isTimed: json['isTimed'] as bool? ?? true,
      capturedWhitePieces: List<String>.from(json['capturedWhitePieces'] ?? []),
      capturedBlackPieces: List<String>.from(json['capturedBlackPieces'] ?? []),
    );
  }
}
