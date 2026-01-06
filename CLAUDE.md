# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SurrenderOverlay is a macOS SwiftUI application that displays a floating overlay panel for voting prompts over a P2P (peer-to-peer) LAN network. The app uses MultipeerConnectivity to discover and connect with other Macs on the same WiFi network, allowing users to send "surrender" voting requests to each other.

## Building and Running

**Build the project:**
```bash
xcodebuild -project SurrenderOverlay.xcodeproj -scheme SurrenderOverlay -configuration Debug build
```

**Run the app:**
Open `SurrenderOverlay.xcodeproj` in Xcode and press Cmd+R, or build and run the app from the Products folder.

**Testing P2P:**
To test the P2P functionality, you need at least 2 Macs on the same WiFi network. Launch the app on both machines and they should discover each other automatically.

## Architecture

The application is structured around three main files:

### Key Components

1. **SurrenderOverlayApp.swift**: Main application file containing:
   - **SurrenderOverlayApp**: SwiftUI App entry point displaying `PeersView` in a window
   - **AppDelegate**: Manages application lifecycle, initializes `PeerService`, configures P2P callbacks
   - **OverlayService**: Manages the floating overlay panel that displays vote requests
   - **OverlayViewModel**: ObservableObject holding overlay state (title, progress, footer, callbacks)
   - **OverlayView**: SwiftUI view rendering the overlay UI

2. **PeerService.swift**: P2P networking layer using MultipeerConnectivity:
   - **Service type**: `"surr-vote"` (must be 1-15 chars, lowercase, numbers, hyphens only)
   - **Discovery**: Automatically advertises and browses for peers on LAN
   - **Connection**: Manual invitation-based with acceptance dialog
   - **Messages**: JSON-encoded `SurrenderRequestPayload` and `SurrenderVotePayload`
   - **Published properties**: `foundPeers` (discovered), `connectedPeers` (active connections)
   - **Callbacks**: `onSurrenderRequest` and `onSurrenderVote` for handling incoming messages

3. **PeersView.swift**: SwiftUI interface for managing P2P connections:
   - Displays list of discovered peers
   - Shows connection status for each peer
   - Provides "Connect" button to invite peers
   - Provides "Send Surrender" button with configurable duration (5-20 seconds)

### P2P Flow

1. **Discovery**: Each device advertises and browses simultaneously using `MCNearbyServiceAdvertiser` and `MCNearbyServiceBrowser`
2. **Connection**: User clicks "Connect" → sends invitation → receiving device shows system alert to accept/reject
3. **Send Vote Request**: User sends surrender request with duration → other device receives and displays overlay
4. **Vote Response**: Receiving device clicks Yes/No → sends vote back → original sender receives vote notification

### Panel Configuration

The overlay uses `NSPanel` with specific configuration for non-intrusive behavior:
- **Style**: `.nonactivatingPanel` and `.borderless` - doesn't steal focus
- **Level**: `.floating` - stays above other windows
- **Collection behavior**: `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.ignoresCycle` - available on all spaces, works in fullscreen, doesn't appear in window cycling
- **Positioning**: Centered on the screen containing the mouse cursor

### Threading Model

All UI operations are `@MainActor` annotated. The countdown mechanism uses structured concurrency with `Task` and `async/await` rather than timers. P2P delegate callbacks use `nonisolated` with `Task { @MainActor in }` to safely update UI.

## Current Implementation Notes

- `ContentView.swift` exists but is unused (boilerplate from template)
- Connection acceptance is currently shown via `NSAlert` popup
- Vote responses are printed to console (see `onSurrenderVote` in AppDelegate)
- The app shows a main window with `PeersView` for managing connections
