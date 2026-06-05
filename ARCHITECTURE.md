# Pocket Party — Architecture Guide

## Overview

Pocket Party is a local multiplayer party game app using **LAN-only** networking. Zero backend, zero ads. Players connect via Wi-Fi using UDP discovery and TCP messaging.

## Tech Stack

- **Flutter** with **Riverpod** for state management
- **TCP** for game messaging between devices (via `dart:io` Sockets)
- **UDP** for room discovery/broadcasting on the LAN
- **flutter_animate** for UI animations

---

## Project Structure

```
lib/
├── core/
│   ├── game_registry.dart     ← Single source of truth for all games
│   ├── network/
│   │   ├── tcp_client_manager.dart
│   │   ├── tcp_server_manager.dart
│   │   └── udp_discovery_service.dart
│   ├── providers/
│   │   ├── network_providers.dart   ← Global singletons (tcpClient/Server/udp)
│   │   └── preferences_provider.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
│       └── game_types.dart    ← Shared enums (GameMode)
├── features/
│   ├── discovery/             ← Join room flow (UDP listening, room list)
│   ├── host/                  ← Host room flow (TCP server, lobby)
│   ├── settings/              ← Username settings
│   └── game_<name>/           ← One module per game (see below)
└── main.dart                  ← App entry, HomeScreen with game grid
```

---

## Game Module Convention

Every game follows this standardized structure:

```
features/game_<name>/
├── domain/
│   ├── models/         # State classes, data models
│   └── providers/      # Riverpod notifiers + providers
└── presentation/
    ├── screens/        # Full-page screens (optional subdirectory)
    └── widgets/        # Reusable sub-widgets (optional)
```

**No `data/` layer** — games use the shared `core/network/` TCP/UDP layer or are purely local.

---

## Game Registry Pattern

The **Game Registry** (`core/game_registry.dart`) is the single source of truth for all game metadata. It eliminates all hardcoded switch statements and scattered imports.

### GameDefinition

```dart
class GameDefinition {
  final String id;
  final String displayName;
  final IconData icon;
  final LinearGradient gradient;
  final bool isComingSoon;
  final bool supportsNetwork;
  final bool supportsSinglePhone;
  final Widget Function()? singlePhoneScreenBuilder;
  final Widget Function({required bool isHost})? networkScreenBuilder;
}
```

### Adding a Game

1. Create `lib/features/game_<name>/` with the standard folder structure
2. Import the screen at the top of `game_registry.dart`
3. Add one `GameDefinition` entry to `gameRegistry`

### Removing a Game

1. Delete the `GameDefinition` entry from `gameRegistry`
2. Remove the import from `game_registry.dart`
3. Delete the `lib/features/game_<name>/` folder

**No other files need editing.** The home screen grid, lobby routing, and mode buttons all derive from the registry.

---

## Networking Architecture

### Global Singletons

All network managers are global Riverpod providers defined in `core/providers/network_providers.dart`:

```dart
final tcpServerProvider = Provider((_) => TcpServerManager());
final tcpClientProvider = Provider((_) => TcpClientManager());
final udpDiscoveryProvider = Provider((_) => UdpDiscoveryService());
```

### Connection Flow

1. **Host**: Creates TCP server → Starts UDP broadcasting room info
2. **Client**: Listens for UDP broadcasts → Discovers rooms → Connects via TCP
3. **Game**: All game messages sent over TCP (reliable, ordered)

### Battery-Critical Guidelines

| Rule | Why |
|------|-----|
| **Always cancel StreamSubscriptions in dispose()** | Prevents ghost listeners that process messages after screen is gone |
| **Use TCP_NODELAY** | Eliminates Nagle buffering for instant LAN response |
| **Role-based subscriptions** | Subscribe to server stream (host) OR client stream (client), never both |
| **Cancellable Timers** | Use `Timer` instead of `Future.delayed` — can be cancelled in dispose |
| **Adaptive UDP broadcast** | Start fast (500ms), slow down to 5s after initial burst |
| **Draw point batching** | Buffer points and flush every 33ms (3-4 TCP writes/sec vs 60/sec) |
| **Chess timer: 1s ticks** | Use Stopwatch for interpolation, only drop to 100ms under 20 seconds |
| **Stale room cleanup** | Prune rooms not seen for 6+ seconds every 3 seconds |

---

## State Management

- **Riverpod Notifiers** for game state (each game has its own provider)
- **ValueNotifier** for high-frequency UI state (e.g., draw canvas points)
- **StreamSubscription** for network messages (always stored + cancelled)

---

## Key Design Decisions

1. **No backend** — Everything is LAN-only for privacy and zero infrastructure cost
2. **Registry pattern** — Prevents the "add game → edit 5 files" problem
3. **Standardized modules** — Every game follows the same folder convention
4. **Explicit resource cleanup** — Every screen that uses network resources handles dispose
5. **Print instead of logger** — Intentional for development; replace with `debugPrint` for production
