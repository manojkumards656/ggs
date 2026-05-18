# Known Issues & Risks Tracker

This file tracks open technical debt, Android-specific bugs, and architecture risks.

## Currently Monitored Risks

1. **UDP Broadcast Blocks**
   - *Issue*: Some Android devices or network routers block UDP broadcast packets, breaking the "Auto Discovery" feature.
   - *Mitigation strategy*: We will implement a "Manual Join" fallback where users can type in the Host's IP address.
   - *Status*: Open. Requires testing across multiple OEM devices.

2. **Mobile Hotspot Client Isolation**
   - *Issue*: Android's built-in Mobile Hotspot may occasionally enforce AP Isolation, preventing clients from pinging each other. 
   - *Mitigation strategy*: Since the Hotspot device itself acts as the gateway (Host), clients only need to talk to the Host, not directly to each other. This should bypass typical client-to-client isolation, but requires physical testing.
   - *Status*: Open.

3. **Background Process Suspension**
   - *Issue*: If the host puts the app in the background to answer a text, Android might pause the TCP ServerSocket.
   - *Mitigation strategy*: For MVP, we will advise users to keep the app open. If we experience heavy OS kills, we may need to explore Foreground Services, though we want to avoid the battery drain if possible.
   - *Status*: Open.

4. **Location Permissions**
   - *Issue*: Wi-Fi scanning often requires Location permissions on Android.
   - *Mitigation strategy*: We must clearly explain this in the UI during onboarding before requesting the permission.
   - *Status*: Open.
