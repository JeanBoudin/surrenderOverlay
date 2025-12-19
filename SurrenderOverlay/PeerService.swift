import Foundation
import MultipeerConnectivity
import AppKit

// ⚠️ serviceType: 1..15 caractères, minuscules + chiffres + tiret
private let serviceType = "surr-vote"

enum P2PEvent: String, Codable {
    case surrenderRequest = "surrender_request"
    case surrenderVote = "surrender_vote"
    case coffeeRequest = "coffee_request"
    case coffeeVote = "coffee_vote"
    case fatigueAlert = "fatigue_alert"
    case goodBoy = "good_boy"
}

struct SurrenderRequestPayload: Codable {
    let type: P2PEvent
    let requestId: String
    let fromName: String
    let duration: Double
}

struct SurrenderVotePayload: Codable {
    let type: P2PEvent
    let requestId: String
    let fromName: String
    let vote: String // "yes" | "no"
}

struct CoffeeRequestPayload: Codable {
    let type: P2PEvent
    let requestId: String
    let fromName: String
    let duration: Double
}

struct CoffeeVotePayload: Codable {
    let type: P2PEvent
    let requestId: String
    let fromName: String
    let vote: String // "yes" | "no"
}

struct FatigueAlertPayload: Codable {
    let type: P2PEvent
    let requestId: String
    let fromName: String
}

struct GoodBoyPayload: Codable {
    let type: P2PEvent
    let requestId: String
    let fromName: String
}

@MainActor
final class PeerService: NSObject, ObservableObject {
    // Découverte
    @Published var foundPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []

    let myPeerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // Callbacks vers ton app
    var onSurrenderRequest: ((SurrenderRequestPayload, MCPeerID) -> Void)?
    var onSurrenderVote: ((SurrenderVotePayload, MCPeerID) -> Void)?
    var onCoffeeRequest: ((CoffeeRequestPayload, MCPeerID) -> Void)?
    var onCoffeeVote: ((CoffeeVotePayload, MCPeerID) -> Void)?
    var onFatigueAlert: ((FatigueAlertPayload, MCPeerID) -> Void)?
    var onGoodBoy: ((GoodBoyPayload, MCPeerID) -> Void)?

    // Trusted peers storage
    private let trustedPeersKey = "TrustedPeers"
    private var trustedPeerNames: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: trustedPeersKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: trustedPeersKey)
        }
    }

    init(displayName: String = Host.current().localizedName ?? "Mac") {
        self.myPeerID = MCPeerID(displayName: displayName)

        self.session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        self.advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: serviceType
        )

        self.browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)

        super.init()

        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        foundPeers.removeAll()
        connectedPeers.removeAll()
    }

    func connect(to peer: MCPeerID) {
        // Invitation envoyée depuis TON Mac
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    func sendSurrenderRequest(to peer: MCPeerID, duration: Double) {
        let payload = SurrenderRequestPayload(
            type: .surrenderRequest,
            requestId: UUID().uuidString,
            fromName: myPeerID.displayName,
            duration: duration
        )
        send(payload, to: [peer])
    }

    func sendVote(to peer: MCPeerID, requestId: String, vote: String) {
        let payload = SurrenderVotePayload(
            type: .surrenderVote,
            requestId: requestId,
            fromName: myPeerID.displayName,
            vote: vote
        )
        send(payload, to: [peer])
    }

    func sendCoffeeRequest(to peer: MCPeerID, duration: Double) {
        let payload = CoffeeRequestPayload(
            type: .coffeeRequest,
            requestId: UUID().uuidString,
            fromName: myPeerID.displayName,
            duration: duration
        )
        send(payload, to: [peer])
    }

    func sendCoffeeVote(to peer: MCPeerID, requestId: String, vote: String) {
        let payload = CoffeeVotePayload(
            type: .coffeeVote,
            requestId: requestId,
            fromName: myPeerID.displayName,
            vote: vote
        )
        send(payload, to: [peer])
    }

    func sendFatigueAlert(to peer: MCPeerID) {
        let payload = FatigueAlertPayload(
            type: .fatigueAlert,
            requestId: UUID().uuidString,
            fromName: myPeerID.displayName
        )
        send(payload, to: [peer])
    }

    func sendGoodBoy(to peer: MCPeerID) {
        let payload = GoodBoyPayload(
            type: .goodBoy,
            requestId: UUID().uuidString,
            fromName: myPeerID.displayName
        )
        send(payload, to: [peer])
    }

    // MARK: - Trusted Peers Management

    func addTrustedPeer(_ peer: MCPeerID) {
        var trusted = trustedPeerNames
        trusted.insert(peer.displayName)
        trustedPeerNames = trusted
        print("✅ \(peer.displayName) ajouté aux peers de confiance")
    }

    func removeTrustedPeer(_ peer: MCPeerID) {
        var trusted = trustedPeerNames
        trusted.remove(peer.displayName)
        trustedPeerNames = trusted
        print("🗑️ \(peer.displayName) retiré des peers de confiance")
    }

    func isTrustedPeer(_ peer: MCPeerID) -> Bool {
        return trustedPeerNames.contains(peer.displayName)
    }

    private func send<T: Codable>(_ payload: T, to peers: [MCPeerID]) {
        guard session.connectedPeers.count > 0 else { return }
        guard let data = try? JSONEncoder().encode(payload) else { return }

        do {
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            print("❌ send error:", error)
        }
    }

    private func updateConnectedPeers() {
        connectedPeers = session.connectedPeers

        // Notify menu bar to update
        NotificationCenter.default.post(name: NSNotification.Name("PeersDidChange"), object: nil)
    }
}

// MARK: - Browser
extension PeerService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if !foundPeers.contains(peerID) && peerID != myPeerID {
                foundPeers.append(peerID)

                // Auto-invite trusted peers
                if self.isTrustedPeer(peerID) && !self.connectedPeers.contains(peerID) {
                    print("🔗 Auto-inviting trusted peer: \(peerID.displayName)")
                    self.connect(to: peerID)
                }
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            foundPeers.removeAll { $0 == peerID }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ browse error:", error)
    }
}

// MARK: - Advertiser (réception invitation)
extension PeerService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                               didReceiveInvitationFromPeer peerID: MCPeerID,
                               withContext context: Data?,
                               invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Auto-accept trusted peers
            if self.isTrustedPeer(peerID) {
                print("✅ Auto-accepting trusted peer: \(peerID.displayName)")
                invitationHandler(true, self.session)
                return
            }

            // Popup macOS "Accepter la connexion ?"
            let alert = NSAlert()
            alert.messageText = "Connexion P2P"
            alert.informativeText = "\(peerID.displayName) veut se connecter. Accepter ?"
            alert.addButton(withTitle: "Accepter")
            alert.addButton(withTitle: "Refuser")

            let response = alert.runModal()
            let accept = (response == .alertFirstButtonReturn)

            // Add to trusted peers if accepted
            if accept {
                self.addTrustedPeer(peerID)
            }

            invitationHandler(accept, accept ? self.session : nil)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ advertise error:", error)
    }
}

// MARK: - Session
extension PeerService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            updateConnectedPeers()
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // On essaye de décoder les types
        if let req = try? JSONDecoder().decode(SurrenderRequestPayload.self, from: data),
           req.type == .surrenderRequest {
            Task { @MainActor in
                onSurrenderRequest?(req, peerID)
            }
            return
        }

        if let vote = try? JSONDecoder().decode(SurrenderVotePayload.self, from: data),
           vote.type == .surrenderVote {
            Task { @MainActor in
                onSurrenderVote?(vote, peerID)
            }
            return
        }

        if let req = try? JSONDecoder().decode(CoffeeRequestPayload.self, from: data),
           req.type == .coffeeRequest {
            Task { @MainActor in
                onCoffeeRequest?(req, peerID)
            }
            return
        }

        if let vote = try? JSONDecoder().decode(CoffeeVotePayload.self, from: data),
           vote.type == .coffeeVote {
            Task { @MainActor in
                onCoffeeVote?(vote, peerID)
            }
            return
        }

        if let alert = try? JSONDecoder().decode(FatigueAlertPayload.self, from: data),
           alert.type == .fatigueAlert {
            Task { @MainActor in
                onFatigueAlert?(alert, peerID)
            }
            return
        }

        if let goodBoy = try? JSONDecoder().decode(GoodBoyPayload.self, from: data),
           goodBoy.type == .goodBoy {
            Task { @MainActor in
                onGoodBoy?(goodBoy, peerID)
            }
            return
        }

        print("⚠️ data reçu non reconnu")
    }

    // Non utilisés ici
    nonisolated func session(_ session: MCSession,
                             didReceive stream: InputStream,
                             withName streamName: String,
                             fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession,
                             didStartReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID,
                             with progress: Progress) {}

    nonisolated func session(_ session: MCSession,
                             didFinishReceivingResourceWithName resourceName: String,
                             fromPeer peerID: MCPeerID,
                             at localURL: URL?,
                             withError error: Error?) {}
}
