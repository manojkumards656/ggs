# INSTRUCT — How to Add a New Game to Pocket Party

> This file contains EVERYTHING an AI agent needs to create a new game module.
> You do NOT need to read any other file in the codebase. This is your single source of truth.

---

## TABLE OF CONTENTS

1. [What This App Is](#1-what-this-app-is)
2. [Tech Stack & Dependencies](#2-tech-stack--dependencies)
3. [Project Structure (What Exists)](#3-project-structure-what-exists)
4. [The 3 Steps to Add a Game](#4-the-3-steps-to-add-a-game)
5. [Game Folder Convention](#5-game-folder-convention)
6. [Game Registration (game_registry.dart)](#6-game-registration)
7. [Game Modes Explained](#7-game-modes-explained)
8. [Networking API (For Multiplayer Games)](#8-networking-api-for-multiplayer-games)
9. [Available Shared Models](#9-available-shared-models)
10. [Theme & Styling](#10-theme--styling)
11. [Critical Rules & Pitfalls](#11-critical-rules--pitfalls)
12. [Complete Example: Single-Phone-Only Game](#12-complete-example-single-phone-only-game)
13. [Complete Example: Networked Game Screen](#13-complete-example-networked-game-screen)

---

## 1. What This App Is

**Pocket Party** is a Flutter party game collection. Players on the same Wi-Fi/hotspot discover and join rooms via LAN. No internet, no backend, no accounts. One phone hosts, others join.

The app has two play modes per game:
- **Single Phone (pass-and-play)**: Everyone shares one device, taking turns.
- **Network (LAN multiplayer)**: Host creates a TCP server, clients connect over Wi-Fi.

---

## 2. Tech Stack & Dependencies

| Technology | Purpose |
|------------|---------|
| **Flutter** (Dart SDK ^3.11.0) | UI framework |
| **flutter_riverpod** ^3.3.1 | State management (all game state uses Riverpod) |
| **flutter_animate** ^4.5.2 | Animations (`.animate().fade().scale()` etc.) |
| **google_fonts** ^8.1.0 | Typography (Outfit font family) |
| **uuid** ^4.5.3 | Generating player/room IDs |
| **shared_preferences** ^2.5.5 | Storing username locally |

**Package name**: `pocket_party`
**Import prefix**: `package:pocket_party/...`

If your game needs a new pub dependency, add it to `pubspec.yaml` under `dependencies:`.

---

## 3. Project Structure (What Exists — DO NOT MODIFY)

```
lib/
├── main.dart                              ← App entry + HomeScreen (auto-generates game grid)
├── core/
│   ├── game_registry.dart                 ← YOU EDIT THIS (Step 2 only)
│   ├── network/
│   │   ├── tcp_server_manager.dart        ← Host TCP server (DO NOT MODIFY)
│   │   ├── tcp_client_manager.dart        ← Client TCP connection (DO NOT MODIFY)
│   │   ├── tcp_framing.dart               ← Length-prefixed framing (DO NOT MODIFY)
│   │   └── udp_discovery_service.dart     ← Room broadcast/discovery (DO NOT MODIFY)
│   ├── providers/
│   │   ├── network_providers.dart         ← Global singletons: tcpClientProvider, tcpServerProvider, udpDiscoveryProvider
│   │   └── preferences_provider.dart      ← usernameProvider, sharedPreferencesProvider
│   ├── theme/
│   │   └── app_theme.dart                 ← Dark theme with Material 3
│   └── utils/
│       └── game_types.dart                ← GameMode enum (localPassAndPlay, networked)
└── features/
    ├── discovery/                          ← Join room flow (DO NOT MODIFY)
    ├── host/                              ← Host lobby flow (DO NOT MODIFY)
    │   ├── domain/
    │   │   ├── player.dart                ← Player model (id, name, score, isHost, isDrawing, hasGuessedCorrectly)
    │   │   └── game_state.dart            ← GameState model (status, currentRound, remainingSeconds, etc.)
    │   └── providers/
    │       ├── lobby_provider.dart         ← lobbyProvider: List<Player> management
    │       └── game_loop_provider.dart     ← gameLoopProvider: round timer, scoring
    ├── settings/                          ← Username settings (DO NOT MODIFY)
    └── game_<YOUR_GAME>/                  ← YOUR NEW GAME GOES HERE
```

**IMPORTANT**: You only create files inside `lib/features/game_<name>/` and edit ONE existing file: `lib/core/game_registry.dart`.

---

## 4. The 3 Steps to Add a Game

### Step 1: Create the game folder

Create `lib/features/game_<name>/` with the convention from Section 5.

### Step 2: Register in game_registry.dart

Open `lib/core/game_registry.dart` and:
- Add your screen import(s) at the top (in the imports section)
- Add a `GameDefinition` entry to the `gameRegistry` list

### Step 3: Done

That's it. The home screen grid, play-mode dialog, and lobby routing ALL auto-read from the registry. No other file needs editing.

---

## 5. Game Folder Convention

Every game MUST follow this structure:

```
lib/features/game_<name>/
├── domain/
│   ├── models/
│   │   └── <name>_state.dart       # Game state class (immutable, with copyWith)
│   └── providers/
│       └── <name>_provider.dart    # Riverpod StateNotifier or Notifier for game logic
└── presentation/
    ├── screens/
    │   └── <name>_screen.dart      # Main game screen widget
    └── widgets/                    # Optional: reusable sub-widgets (board, timer, etc.)
```

Some simpler games flatten this (e.g., `presentation/<name>_screen.dart` directly). Either is acceptable.

---

## 6. Game Registration

The file `lib/core/game_registry.dart` contains the `GameDefinition` class and the `gameRegistry` list.

### GameDefinition fields:

```dart
class GameDefinition {
  final String id;                    // Unique ID: 'chess', 'trivia', 'tic_tac_toe'
  final String displayName;          // Shown in UI: 'Chess', 'Trivia', 'Tic Tac Toe'
  final IconData icon;               // Card icon (use Icons.* from Material)
  final LinearGradient gradient;     // Card gradient (pick 2 vibrant colors)
  final bool isComingSoon;           // true = greyed-out placeholder, no code needed
  final bool supportsNetwork;        // true = shows Host/Join buttons
  final bool supportsSinglePhone;    // true = shows Single Phone button
  final Widget Function()? singlePhoneScreenBuilder;
  final Widget Function({required bool isHost})? networkScreenBuilder;
}
```

### How to add your entry:

At the top of `game_registry.dart`, add your import:
```dart
import 'package:pocket_party/features/game_<name>/presentation/screens/<name>_screen.dart';
```

Then add an entry to the `gameRegistry` list:

```dart
// SINGLE-PHONE ONLY game:
GameDefinition(
  id: '<name>',
  displayName: '<Display Name>',
  icon: Icons.<icon>,
  gradient: const LinearGradient(
    colors: [Color(0xFF______), Color(0xFF______)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  supportsSinglePhone: true,
  singlePhoneScreenBuilder: () => const <Name>Screen(),
),

// NETWORK + SINGLE-PHONE game:
GameDefinition(
  id: '<name>',
  displayName: '<Display Name>',
  icon: Icons.<icon>,
  gradient: const LinearGradient(
    colors: [Color(0xFF______), Color(0xFF______)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  supportsNetwork: true,
  supportsSinglePhone: true,
  singlePhoneScreenBuilder: () => const <Name>Screen(isNetworked: false),
  networkScreenBuilder: ({required bool isHost}) =>
      <Name>Screen(isNetworked: true, isHost: isHost),
),
```

---

## 7. Game Modes Explained

### Mode A: Single Phone (Pass-and-Play)

- No networking at all.
- All game state lives locally in a Riverpod provider.
- Players take turns on the same device.
- Your screen constructor takes NO network arguments (or `isNetworked: false`).

### Mode B: Network (LAN Multiplayer)

- **Host flow**: User taps "Host a Game" → enters the host lobby (`HostLobbyScreen`) → when they press "Start Game", the lobby looks up your game by `displayName` in the registry → calls `networkScreenBuilder(isHost: true)` → navigates to your screen.
- **Client flow**: User taps "Join a Game" → discovers rooms via UDP → connects via TCP → receives `game_started` message → the join screen looks up your game in the registry → calls `networkScreenBuilder(isHost: false)` → navigates to your screen.
- Your screen receives `isHost: true/false` — use this to decide whether to listen on the **server** stream or the **client** stream.

The shared enum (importable from `package:pocket_party/core/utils/game_types.dart`):
```dart
enum GameMode { localPassAndPlay, networked }
```

---

## 8. Networking API (For Multiplayer Games)

> SKIP THIS SECTION if your game is single-phone only.

### 8.1 Accessing Network Managers

Import:
```dart
import 'package:pocket_party/core/providers/network_providers.dart';
```

In a `ConsumerStatefulWidget`:
```dart
final tcpServer = ref.read(tcpServerProvider);  // Host only
final tcpClient = ref.read(tcpClientProvider);  // Client only
```

### 8.2 Sending Messages

All messages are `Map<String, dynamic>` (JSON-serializable). Always include a `'type'` key.

**Host → All Clients:**
```dart
tcpServer.broadcastMessage({
  'type': 'your_game_event',
  'payload': { 'key': 'value' },
});
```

**Client → Host:**
```dart
tcpClient.sendMessage({
  'type': 'your_game_event',
  'payload': { 'key': 'value' },
});
```

### 8.3 Receiving Messages

Both managers expose a `messageStream` (broadcast `Stream<Map<String, dynamic>>`).

```dart
late StreamSubscription _sub;

@override
void initState() {
  super.initState();
  if (isHost) {
    _sub = ref.read(tcpServerProvider).messageStream.listen(_onMessage);
  } else {
    _sub = ref.read(tcpClientProvider).messageStream.listen(_onMessage);
  }
}

void _onMessage(Map<String, dynamic> msg) {
  if (!mounted) return;  // ALWAYS check mounted first
  switch (msg['type']) {
    case 'your_event':
      // handle it
      break;
  }
}

@override
void dispose() {
  _sub.cancel();  // CRITICAL: always cancel in dispose
  super.dispose();
}
```

### 8.4 Host ↔ Client Pattern

The host acts as the authoritative server:
1. **Client** sends action to host (e.g., `{ 'type': 'make_move', 'row': 2, 'col': 3 }`)
2. **Host** validates the move, updates state, then broadcasts the updated state to ALL clients
3. **Clients** receive the broadcast and update their UI

### 8.5 Wire Format (FYI — you don't need to handle this)

Messages are automatically length-prefixed (4-byte big-endian header + UTF-8 JSON). The `tcp_framing.dart` handles this transparently. You just send/receive `Map<String, dynamic>`.

### 8.6 Cleaning Up on Exit

When leaving your game screen and going back to home:

```dart
import 'package:pocket_party/core/providers/network_providers.dart';

// Call this to tear down all network resources:
resetNetworkProviders(ref);
```

This invalidates and recreates the TCP/UDP providers cleanly.

---

## 9. Available Shared Models

### Player (from `package:pocket_party/features/host/domain/player.dart`)

```dart
class Player {
  final String id;
  final String name;
  final int score;
  final bool isHost;
  final bool isDrawing;           // Game-specific, can ignore
  final bool hasGuessedCorrectly; // Game-specific, can ignore

  // Has: copyWith(), toJson(), fromJson()
}
```

### GameState (from `package:pocket_party/features/host/domain/game_state.dart`)

```dart
enum GameStatus { lobby, playing, roundEnd, gameOver }

class GameState {
  final GameStatus status;
  final int currentRound;
  final int maxRounds;
  final int remainingSeconds;
  final String? currentWord;
  final String? currentDrawerId;

  // Has: copyWith(), toJson(), fromJson()
}
```

### Lobby Provider (from `package:pocket_party/features/host/providers/lobby_provider.dart`)

```dart
final lobbyProvider = NotifierProvider<LobbyNotifier, List<Player>>(...);

// Methods:
ref.read(lobbyProvider.notifier).addPlayer(player);
ref.read(lobbyProvider.notifier).removePlayer(playerId);
ref.read(lobbyProvider.notifier).updateScore(playerId, points);
ref.read(lobbyProvider.notifier).setDrawer(drawerId);
ref.read(lobbyProvider.notifier).markGuessedCorrectly(playerId);
ref.read(lobbyProvider.notifier).setPlayers(playerList);
ref.read(lobbyProvider.notifier).resetLobby();
```

### Game Loop Provider (from `package:pocket_party/features/host/providers/game_loop_provider.dart`)

```dart
final gameLoopProvider = NotifierProvider<GameLoopNotifier, GameState>(...);

// Methods:
ref.read(gameLoopProvider.notifier).startGame(firstDrawerId, word);
ref.read(gameLoopProvider.notifier).startNextRound(nextDrawerId, word);
ref.read(gameLoopProvider.notifier).handleCorrectGuess(playerId);
ref.read(gameLoopProvider.notifier).setState(newGameState);
```

> NOTE: The existing lobbyProvider/gameLoopProvider are somewhat tied to Draw & Guess conventions. For your game, you may want to create your OWN provider in `game_<name>/domain/providers/` if the shared model doesn't fit. That's perfectly fine and recommended.

---

## 10. Theme & Styling

The app uses a **dark theme** with Material 3. Key colors:

```dart
scaffoldBackgroundColor: Color(0xFF0F0C29)  // Deep navy
colorScheme.primary:     Color(0xFF00F2FE)  // Cyan
colorScheme.secondary:   Color(0xFF4FACFE)  // Blue
colorScheme.surface:     Color(0xFF1E1E36)  // Dark card
```

Font: **Outfit** (via `google_fonts`). Access via `Theme.of(context).textTheme`.

Background gradient used on most screens:
```dart
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
    ),
  ),
)
```

Use `flutter_animate` for UI polish:
```dart
import 'package:flutter_animate/flutter_animate.dart';

// Examples:
widget.animate().fade().scale()
widget.animate().fade(delay: 200.ms).slideY(begin: 0.2)
widget.animate(onPlay: (c) => c.repeat(reverse: true)).shimmer()
```

---

## 11. Critical Rules & Pitfalls

### DO:
- ✅ Always cancel `StreamSubscription` in `dispose()`
- ✅ Always check `if (!mounted) return;` before `setState()` in async callbacks
- ✅ Use `ConsumerStatefulWidget` if you access `ref` in `initState`/`dispose`
- ✅ Create your own Riverpod provider for game state (don't rely on the shared gameLoopProvider unless it fits)
- ✅ Make your screen accept `isHost` param if it supports network mode
- ✅ Call `resetNetworkProviders(ref)` when navigating back to home from a networked game
- ✅ Use `Timer` (not `Future.delayed`) for anything you need to cancel in `dispose()`

### DON'T:
- ❌ DO NOT modify any file in `lib/core/` (except adding your entry to `game_registry.dart`)
- ❌ DO NOT modify `lib/main.dart`
- ❌ DO NOT modify anything in `features/host/`, `features/discovery/`, or `features/settings/`
- ❌ DO NOT create your own TCP/UDP code — use the shared providers
- ❌ DO NOT subscribe to BOTH `tcpServerProvider.messageStream` AND `tcpClientProvider.messageStream` in the same widget — pick one based on `isHost`
- ❌ DO NOT use `Future.delayed` for timers you can't cancel
- ❌ DO NOT add hardcoded routes or switch statements in other files — the registry handles all routing

---

## 12. Complete Example: Single-Phone-Only Game

Here is a minimal complete game (Tic Tac Toe, single-phone only):

### File: `lib/features/game_tictactoe/presentation/screens/tictactoe_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Simple state: list of 9 cells, current player
final _boardProvider = StateProvider<List<String>>((ref) => List.filled(9, ''));
final _currentPlayerProvider = StateProvider<String>((ref) => 'X');
final _winnerProvider = StateProvider<String?>((ref) => null);

class TicTacToeScreen extends ConsumerWidget {
  const TicTacToeScreen({super.key});

  void _onTap(int index, WidgetRef ref) {
    final board = ref.read(_boardProvider);
    if (board[index].isNotEmpty || ref.read(_winnerProvider) != null) return;

    final newBoard = List<String>.from(board);
    final current = ref.read(_currentPlayerProvider);
    newBoard[index] = current;
    ref.read(_boardProvider.notifier).state = newBoard;

    // Check winner
    final winner = _checkWinner(newBoard);
    if (winner != null) {
      ref.read(_winnerProvider.notifier).state = winner;
    } else {
      ref.read(_currentPlayerProvider.notifier).state = current == 'X' ? 'O' : 'X';
    }
  }

  String? _checkWinner(List<String> b) {
    const wins = [
      [0,1,2],[3,4,5],[6,7,8], // rows
      [0,3,6],[1,4,7],[2,5,8], // cols
      [0,4,8],[2,4,6],         // diags
    ];
    for (final w in wins) {
      if (b[w[0]].isNotEmpty && b[w[0]] == b[w[1]] && b[w[1]] == b[w[2]]) {
        return b[w[0]];
      }
    }
    if (b.every((c) => c.isNotEmpty)) return 'Draw';
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(_boardProvider);
    final currentPlayer = ref.watch(_currentPlayerProvider);
    final winner = ref.watch(_winnerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tic Tac Toe')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                winner != null ? (winner == 'Draw' ? "It's a Draw!" : '$winner Wins!') : "Turn: $currentPlayer",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ).animate().fade(),
              const SizedBox(height: 32),
              SizedBox(
                width: 300, height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: 9,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => _onTap(i, ref),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E36),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            board[i],
                            style: TextStyle(
                              fontSize: 40, fontWeight: FontWeight.bold,
                              color: board[i] == 'X' ? const Color(0xFF00F2FE) : const Color(0xFFFF416C),
                            ),
                          ),
                        ),
                      ),
                    ).animate().scale(delay: (i * 50).ms);
                  },
                ),
              ),
              const SizedBox(height: 32),
              if (winner != null)
                ElevatedButton(
                  onPressed: () {
                    ref.read(_boardProvider.notifier).state = List.filled(9, '');
                    ref.read(_currentPlayerProvider.notifier).state = 'X';
                    ref.read(_winnerProvider.notifier).state = null;
                  },
                  child: const Text('Play Again'),
                ).animate().fade().slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Registration in `game_registry.dart`:

```dart
// Add import at top:
import 'package:pocket_party/features/game_tictactoe/presentation/screens/tictactoe_screen.dart';

// Add entry to gameRegistry list:
GameDefinition(
  id: 'tictactoe',
  displayName: 'Tic Tac Toe',
  icon: Icons.grid_3x3,
  gradient: const LinearGradient(
    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  supportsSinglePhone: true,
  singlePhoneScreenBuilder: () => const TicTacToeScreen(),
),
```

---

## 13. Complete Example: Networked Game Screen

Here's the pattern for a network-capable game screen:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocket_party/core/providers/network_providers.dart';

class MyNetworkGameScreen extends ConsumerStatefulWidget {
  final bool isNetworked;
  final bool isHost;

  const MyNetworkGameScreen({
    super.key,
    this.isNetworked = false,
    this.isHost = false,
  });

  @override
  ConsumerState<MyNetworkGameScreen> createState() => _MyNetworkGameScreenState();
}

class _MyNetworkGameScreenState extends ConsumerState<MyNetworkGameScreen> {
  StreamSubscription? _networkSub;

  @override
  void initState() {
    super.initState();
    if (widget.isNetworked) {
      _setupNetworkListeners();
    }
  }

  void _setupNetworkListeners() {
    if (widget.isHost) {
      // Host listens to server stream (messages FROM clients)
      _networkSub = ref.read(tcpServerProvider).messageStream.listen(_handleMessage);
    } else {
      // Client listens to client stream (messages FROM host/server)
      _networkSub = ref.read(tcpClientProvider).messageStream.listen(_handleMessage);
    }
  }

  void _handleMessage(Map<String, dynamic> msg) {
    if (!mounted) return;
    switch (msg['type']) {
      case 'game_move':
        // Update local state based on received move
        break;
      case 'game_state_sync':
        // Full state sync from host
        break;
    }
  }

  void _sendMove(Map<String, dynamic> moveData) {
    if (!widget.isNetworked) return;

    final message = {'type': 'game_move', ...moveData};

    if (widget.isHost) {
      // Host broadcasts to all clients
      ref.read(tcpServerProvider).broadcastMessage(message);
    } else {
      // Client sends to host
      ref.read(tcpClientProvider).sendMessage(message);
    }
  }

  void _leaveGame() {
    if (widget.isNetworked) {
      resetNetworkProviders(ref);  // Clean up network resources
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void dispose() {
    _networkSub?.cancel();  // ALWAYS cancel
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveGame,
        ),
      ),
      body: const Center(child: Text('Game goes here')),
    );
  }
}
```

---

## QUICK REFERENCE CARD

| What | Where |
|------|-------|
| Your game code | `lib/features/game_<name>/` |
| Register game | `lib/core/game_registry.dart` (ONLY file to edit) |
| TCP server (host) | `ref.read(tcpServerProvider)` |
| TCP client (joiner) | `ref.read(tcpClientProvider)` |
| Send to all clients | `tcpServer.broadcastMessage({...})` |
| Send to host | `tcpClient.sendMessage({...})` |
| Listen for messages | `.messageStream.listen(...)` |
| Player model | `import 'package:pocket_party/features/host/domain/player.dart'` |
| Lobby state | `ref.watch(lobbyProvider)` |
| Network cleanup | `resetNetworkProviders(ref)` |
| Game mode enum | `import 'package:pocket_party/core/utils/game_types.dart'` |
| Background gradient | `[Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)]` |
| Primary color | `Color(0xFF00F2FE)` (cyan) |

---

**END OF INSTRUCTIONS**
