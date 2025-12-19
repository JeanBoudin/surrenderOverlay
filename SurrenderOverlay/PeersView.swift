import SwiftUI
import MultipeerConnectivity

struct PeersView: View {
    @ObservedObject var peerService: PeerService
    let overlayService: OverlayService

    @State private var duration: Double = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("P2P LAN – Surrender")
                .font(.title2)

            HStack {
                Text("Moi : \(peerService.myPeerID.displayName)")
                Spacer()
                Text("Connectés : \(peerService.connectedPeers.count)")
            }
            .font(.subheadline)
            .opacity(0.8)

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

            Text("Peers trouvés")
                .font(.headline)

            List(peerService.foundPeers, id: \.self) { peer in
                HStack {
                    VStack(alignment: .leading) {
                        Text(peer.displayName)
                        Text(peerService.connectedPeers.contains(peer) ? "Connecté" : "Non connecté")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    Spacer()

                    Button("Connect") {
                        peerService.connect(to: peer)
                    }
                    .disabled(peerService.connectedPeers.contains(peer))

                    Button("Send Surrender") {
                        peerService.sendSurrenderRequest(to: peer, duration: duration)
                    }
                    .disabled(!peerService.connectedPeers.contains(peer))
                }
            }
            .frame(minHeight: 260)

            Spacer()
        }
        .padding(16)
        .frame(width: 520, height: 580)
    }
}
