import SwiftUI

struct PeersView: View {
    @ObservedObject var peerService: WebSocketPeerService
    let overlayService: OverlayService

    @State private var duration: Double = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WebSocket – Surrender")
                .font(.title2)

            HStack {
                Circle()
                    .fill(peerService.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(peerService.isConnected ? "Connected to server" : "Disconnected")
                    .font(.subheadline)
                    .opacity(0.8)

                Spacer()

                Text("Peers: \(peerService.connectedPeers.count)")
                    .font(.subheadline)
                    .opacity(0.8)
            }

            Divider()

            HStack {
                Text("Durée")
                Slider(value: $duration, in: 5...20, step: 1)
                Text("\(Int(duration))s")
                    .frame(width: 45, alignment: .trailing)
            }

            Divider()

            Text("Test Overlays")
                .font(.headline)

            HStack(spacing: 8) {
                Button("Test Surrender 🏴") {
                    overlayService.present(
                        title: "Surrender – Test",
                        duration: duration,
                        onYes: { print("Test: Yes clicked") },
                        onNo: { print("Test: No clicked") }
                    )
                }
                .buttonStyle(.bordered)

                Button("Test Coffee ☕️") {
                    overlayService.present(
                        title: "☕️ Coffee? – Test",
                        duration: duration,
                        onYes: { print("Test: Yes clicked") },
                        onNo: { print("Test: No clicked") }
                    )
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button("Test Fatigue 😴") {
                    let advice = """
                      Prends une pause de 5-10 minutes
                      Regarde au loin (règle 20-20-20)
                      Lève-toi et bouge un peu
                      Bois de l'eau
                      Étire-toi et respire profondément
                    """
                    overlayService.presentNotification(
                        title: "Fatigue Détectée – Test",
                        message: advice,
                        isDismissible: true
                    )
                }
                .buttonStyle(.bordered)

                Button("Test Vote Response ✅") {
                    overlayService.presentNotification(
                        title: "🏴 Surrender Response",
                        message: "Test User said: ✅ Yes!",
                        duration: 3.0
                    )
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 8) {
                Button("Test GoodBoy 🐕") {
                    overlayService.presentGoodBoy(fromName: "Test User")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            Divider()

            Text("Connected Peers")
                .font(.headline)

            if peerService.connectedPeers.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)

                    Text("No peers connected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if !peerService.isConnected {
                        Text("Reconnecting to server...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                List(peerService.connectedPeers) { peer in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(peer.displayName)
                                .font(.headline)

                            Text(peer.peerId)
                                .font(.caption)
                                .opacity(0.7)
                        }
                        Spacer()

                        Button("Send Surrender") {
                            peerService.sendSurrenderRequest(to: peer, duration: duration)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 8)
                }
                .frame(minHeight: 200)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 520, height: 580)
    }
}
