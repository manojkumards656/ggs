# Project Context: Pocket Party

## Mission
Build a Play Store publishable Android app that enables offline local multiplayer party games over LAN (Wi-Fi / mobile hotspot), with zero backend infrastructure and zero ads for MVP.

## Primary Product Goal
Create a viral-feeling app where one person hosts a room on their phone and nearby friends connected to the same hotspot/Wi-Fi can instantly discover and join multiplayer games.

## Target Users
Friends physically together:
- College students
- Parties
- Travel groups
- Classrooms
- Family gatherings

## Core Product Principles
- **Instant Join:** Zero friction onboarding. No accounts.
- **No Internet Required:** Must work purely over local LAN subnet.
- **Zero Backend/Ads:** Clean, premium UX.
- **Low Latency:** High responsiveness for real-time multiplayer.
- **Android First:** Focus exclusively on Android optimization for the MVP.
- **Scalable Architecture:** Built to easily plug in new mini-games later.

## MVP Game: Draw & Guess
A multiplayer Skribbl-like LAN game featuring:
- Shared drawing canvas synchronization.
- Real-time guessing chat.
- Scoring, timers, and multiple rounds.
- Auto-discovery of local hosts.

## Core Technical Constraints
- The app must handle standard Wi-Fi LANs and Android Mobile Hotspots.
- No Firebase or cloud backends (except optionally for later crash reporting, if strictly necessary, but preferably none).
- All multiplayer logic must be peer-to-peer (Host acts as server).
