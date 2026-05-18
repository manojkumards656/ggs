# Task Board & Implementation Plan

This document tracks the execution phases for Pocket Party.

## Milestones

### [ ] Milestone 1: Project Scaffold
- Initialize Flutter project with standard clean architecture folders.
- Setup Riverpod, Google Fonts, and generic UI themes.
- Create basic routing (Home -> Host Lobby / Join Room).

### [ ] Milestone 2: Networking Core
- Implement the raw Dart UDP broadcast abstraction.
- Implement the raw Dart TCP `ServerSocket` and `Socket` abstractions.
- Create message parsing layer (JSON string encoding/decoding with newline delimiters).

### [ ] Milestone 3: Room Management
- Implement Host lobby creation (starts TCP server).
- Implement Player connection to Host.
- Sync player list across all connected devices in the lobby.

### [ ] Milestone 4: Discovery Service
- Implement UDP broadcasting on the Host.
- Implement UDP listener on the Join screen to populate available rooms dynamically.
- Add manual IP entry fallback for networks that block UDP.

### [ ] Milestone 5: Draw Synchronization
- Build the Flutter CustomPainter canvas.
- Implement local drawing (touch -> path).
- Broadcast drawn coordinates over TCP.
- Render received coordinates on guest devices.

### [ ] Milestone 6: Chat Sync
- Implement chat UI.
- Send text payloads over TCP.
- Add guess validation on the Host (did they match the word?).

### [ ] Milestone 7: Scoring/Timers
- Add a countdown timer managed by the Host and synced to clients.
- Implement scoring logic (faster guess = more points).
- Implement Round transitions.

### [ ] Milestone 8: Resilience/Error Handling
- Handle client disconnections gracefully (remove from player list).
- Handle host disconnection gracefully (show "Host Disconnected" error dialog and return to home).
- Reconnection attempts if a socket drops unexpectedly.

### [ ] Milestone 9: Polish
- Add micro-animations to UI (Lottie / Flutter Animate).
- Add sound effects (ticks, successful guesses).
- Polish the dark mode / vibrant party UI design.

### [ ] Milestone 10: Play Store Prep
- Prepare Android Manifest (icons, permissions).
- Draft privacy policy regarding Location permissions for Wi-Fi discovery.
- Final test runs on physical devices over Hotspot.
