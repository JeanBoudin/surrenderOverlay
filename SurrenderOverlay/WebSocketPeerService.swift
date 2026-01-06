import Foundation
import Starscream
import IOKit

// MARK: - Payload Types (from PeerService compatibility)

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

// MARK: - WebSocket Message Types

// Message types matching the backend protocol
enum WSMessageType: String, Codable {
    // Client -> Server
    case register
    case surrenderRequest = "surrender_request"
    case surrenderVote = "surrender_vote"
    case coffeeRequest = "coffee_request"
    case coffeeVote = "coffee_vote"
    case fatigueAlert = "fatigue_alert"
    case goodBoy = "good_boy"
    case ping

    // Server -> Client
    case registered
    case peersList = "peers_list"
    case surrenderRequestReceived = "surrender_request_received"
    case surrenderVoteReceived = "surrender_vote_received"
    case coffeeRequestReceived = "coffee_request_received"
    case coffeeVoteReceived = "coffee_vote_received"
    case fatigueAlertReceived = "fatigue_alert_received"
    case goodBoyReceived = "good_boy_received"
    case pong
    case error
}

// MARK: - Client -> Server Messages

struct WSRegisterMessage: Codable {
    let type: String = "register"
    let peerId: String
    let peerName: String
}

struct WSSurrenderRequestMessage: Codable {
    let type: String = "surrender_request"
    let targetPeerId: String
    let duration: Double
    let title: String?
}

struct WSSurrenderVoteMessage: Codable {
    let type: String = "surrender_vote"
    let targetPeerId: String
    let vote: String
    let requestId: String?
}

struct WSCoffeeRequestMessage: Codable {
    let type: String = "coffee_request"
    let targetPeerId: String
    let duration: Double
    let title: String?
}

struct WSCoffeeVoteMessage: Codable {
    let type: String = "coffee_vote"
    let targetPeerId: String
    let vote: String
    let requestId: String?
}

struct WSFatigueAlertMessage: Codable {
    let type: String = "fatigue_alert"
    let targetPeerId: String
    let requestId: String?
}

struct WSGoodBoyMessage: Codable {
    let type: String = "good_boy"
    let targetPeerId: String
    let requestId: String?
}

// MARK: - Server -> Client Messages

struct WSRegisteredMessage: Codable {
    let type: String
    let clientId: String
    let peerId: String
    let peerName: String
}

struct WSPeer: Codable, Identifiable, Hashable {
    let peerId: String
    let peerName: String

    var id: String { peerId }
    var displayName: String { peerName }
}

struct WSPeersListMessage: Codable {
    let type: String
    let peers: [WSPeer]
}

struct WSSurrenderRequestReceivedMessage: Codable {
    let type: String
    let fromPeerId: String
    let fromPeerName: String
    let duration: Double
    let title: String?
    let requestId: String
}

struct WSSurrenderVoteReceivedMessage: Codable {
    let type: String
    let fromPeerId: String
    let fromPeerName: String
    let vote: String
    let requestId: String?
}

struct WSCoffeeRequestReceivedMessage: Codable {
    let type: String
    let fromPeerId: String
    let fromPeerName: String
    let duration: Double
    let title: String?
    let requestId: String
}

struct WSCoffeeVoteReceivedMessage: Codable {
    let type: String
    let fromPeerId: String
    let fromPeerName: String
    let vote: String
    let requestId: String?
}

struct WSFatigueAlertReceivedMessage: Codable {
    let type: String
    let fromPeerId: String
    let fromPeerName: String
    let requestId: String
}

struct WSGoodBoyReceivedMessage: Codable {
    let type: String
    let fromPeerId: String
    let fromPeerName: String
    let requestId: String
}

struct WSErrorMessage: Codable {
    let type: String
    let message: String
}

// MARK: - WebSocket Peer Service

@MainActor
final class WebSocketPeerService: ObservableObject {
    @Published var connectedPeers: [WSPeer] = []
    @Published var isConnected = false

    private var socket: WebSocket?
    private let serverURL: String
    private let peerId: String
    private let peerName: String
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectDelay: TimeInterval = 30.0

    // Callbacks matching PeerService interface
    var onSurrenderRequest: ((SurrenderRequestPayload, WSPeer) -> Void)?
    var onSurrenderVote: ((SurrenderVotePayload, WSPeer) -> Void)?
    var onCoffeeRequest: ((CoffeeRequestPayload, WSPeer) -> Void)?
    var onCoffeeVote: ((CoffeeVotePayload, WSPeer) -> Void)?
    var onFatigueAlert: ((FatigueAlertPayload, WSPeer) -> Void)?
    var onGoodBoy: ((GoodBoyPayload, WSPeer) -> Void)?

    // For compatibility with existing code
    var foundPeers: [WSPeer] { connectedPeers }
    var myPeerID: WSPeer { WSPeer(peerId: peerId, peerName: peerName) }

    init(serverURL: String = "ws://localhost:8080") {
        self.serverURL = serverURL
        self.peerId = Self.getPersistentPeerId()
        self.peerName = Host.current().localizedName ?? "Unknown Mac"
    }

    // MARK: - Persistent Peer ID

    private static func getPersistentPeerId() -> String {
        let key = "WebSocketPeerID"

        // Check if we already have a peer ID saved
        if let savedId = UserDefaults.standard.string(forKey: key) {
            return savedId
        }

        // Try to get a unique hardware identifier
        if let hardwareUUID = Self.getHardwareUUID() {
            UserDefaults.standard.set(hardwareUUID, forKey: key)
            return hardwareUUID
        }

        // Fallback: generate and save a new UUID
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private static func getHardwareUUID() -> String? {
        // Get the Mac's hardware UUID from IOKit
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard platformExpert != 0 else { return nil }
        defer { IOObjectRelease(platformExpert) }

        guard let serialNumberAsCFString = IORegistryEntryCreateCFProperty(
            platformExpert,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }

        return serialNumberAsCFString
    }

    // MARK: - Connection Management

    func start() {
        connect()
    }

    func stop() {
        disconnect()
    }

    private func connect() {
        guard let url = URL(string: serverURL) else {
            print("❌ Invalid server URL: \(serverURL)")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        socket = WebSocket(request: request)
        socket?.delegate = self
        socket?.connect()

        print("🔌 Connecting to WebSocket server: \(serverURL)")
    }

    func disconnect() {
        stopPingTimer()
        socket?.disconnect()
        socket = nil
        isConnected = false
        connectedPeers = []
    }

    // MARK: - Ping/Pong for Keep-Alive

    private func startPingTimer() {
        stopPingTimer()

        // Send ping every 20 seconds to keep connection alive
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendPing()
            }
        }

        print("💓 Started heartbeat timer")
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        struct PingMessage: Codable {
            let type = "ping"
        }
        sendMessage(PingMessage())
    }

    // MARK: - Send Messages

    private func sendMessage<T: Encodable>(_ message: T) {
        guard let data = try? JSONEncoder().encode(message),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("❌ Failed to encode message")
            return
        }

        socket?.write(string: jsonString)
    }

    func sendSurrenderRequest(to peer: WSPeer, duration: Double) {
        let message = WSSurrenderRequestMessage(
            targetPeerId: peer.peerId,
            duration: duration,
            title: nil
        )
        sendMessage(message)
        print("📤 Sending surrender request to \(peer.peerName)")
    }

    func sendVote(to peer: WSPeer, requestId: String, vote: String) {
        let message = WSSurrenderVoteMessage(
            targetPeerId: peer.peerId,
            vote: vote,
            requestId: requestId
        )
        sendMessage(message)
        print("📤 Sending vote \(vote) to \(peer.peerName)")
    }

    func sendCoffeeRequest(to peer: WSPeer, duration: Double) {
        let message = WSCoffeeRequestMessage(
            targetPeerId: peer.peerId,
            duration: duration,
            title: nil
        )
        sendMessage(message)
        print("☕️ Sending coffee request to \(peer.peerName)")
    }

    func sendCoffeeVote(to peer: WSPeer, requestId: String, vote: String) {
        let message = WSCoffeeVoteMessage(
            targetPeerId: peer.peerId,
            vote: vote,
            requestId: requestId
        )
        sendMessage(message)
        print("☕️ Sending coffee vote \(vote) to \(peer.peerName)")
    }

    func sendFatigueAlert(to peer: WSPeer) {
        let message = WSFatigueAlertMessage(
            targetPeerId: peer.peerId,
            requestId: UUID().uuidString
        )
        sendMessage(message)
        print("😴 Sending fatigue alert to \(peer.peerName)")
    }

    func sendGoodBoy(to peer: WSPeer) {
        let message = WSGoodBoyMessage(
            targetPeerId: peer.peerId,
            requestId: UUID().uuidString
        )
        sendMessage(message)
        print("🐕 Sending GoodBoy to \(peer.peerName)")
    }

    // MARK: - Message Handling

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        // Try to decode the type first
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeString = json["type"] as? String else {
            print("⚠️ Failed to parse message type")
            return
        }

        switch typeString {
        case "registered":
            handleRegistered(data)

        case "peers_list":
            handlePeersList(data)

        case "surrender_request_received":
            handleSurrenderRequestReceived(data)

        case "surrender_vote_received":
            handleSurrenderVoteReceived(data)

        case "coffee_request_received":
            handleCoffeeRequestReceived(data)

        case "coffee_vote_received":
            handleCoffeeVoteReceived(data)

        case "fatigue_alert_received":
            handleFatigueAlertReceived(data)

        case "good_boy_received":
            handleGoodBoyReceived(data)

        case "error":
            handleError(data)

        case "pong":
            break // Ignore pong

        default:
            print("⚠️ Unknown message type: \(typeString)")
        }
    }

    private func handleRegistered(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSRegisteredMessage.self, from: data) else {
            return
        }

        isConnected = true
        print("✅ Registered with server as \(message.peerName)")
    }

    private func handlePeersList(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSPeersListMessage.self, from: data) else {
            return
        }

        connectedPeers = message.peers
        print("📋 Peers list updated: \(connectedPeers.count) peer(s)")

        // Notify menu bar to update
        NotificationCenter.default.post(name: NSNotification.Name("PeersDidChange"), object: nil)
    }

    private func handleSurrenderRequestReceived(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSSurrenderRequestReceivedMessage.self, from: data) else {
            return
        }

        let peer = WSPeer(peerId: message.fromPeerId, peerName: message.fromPeerName)
        let payload = SurrenderRequestPayload(
            type: .surrenderRequest,
            requestId: message.requestId,
            fromName: message.fromPeerName,
            duration: message.duration
        )

        onSurrenderRequest?(payload, peer)
        print("🏴 Received surrender request from \(message.fromPeerName)")
    }

    private func handleSurrenderVoteReceived(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSSurrenderVoteReceivedMessage.self, from: data) else {
            return
        }

        let peer = WSPeer(peerId: message.fromPeerId, peerName: message.fromPeerName)
        let payload = SurrenderVotePayload(
            type: .surrenderVote,
            requestId: message.requestId ?? "",
            fromName: message.fromPeerName,
            vote: message.vote
        )

        onSurrenderVote?(payload, peer)
        print("✅ Received surrender vote from \(message.fromPeerName): \(message.vote)")
    }

    private func handleCoffeeRequestReceived(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSCoffeeRequestReceivedMessage.self, from: data) else {
            return
        }

        let peer = WSPeer(peerId: message.fromPeerId, peerName: message.fromPeerName)
        let payload = CoffeeRequestPayload(
            type: .coffeeRequest,
            requestId: message.requestId,
            fromName: message.fromPeerName,
            duration: message.duration
        )

        onCoffeeRequest?(payload, peer)
        print("☕️ Received coffee request from \(message.fromPeerName)")
    }

    private func handleCoffeeVoteReceived(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSCoffeeVoteReceivedMessage.self, from: data) else {
            return
        }

        let peer = WSPeer(peerId: message.fromPeerId, peerName: message.fromPeerName)
        let payload = CoffeeVotePayload(
            type: .coffeeVote,
            requestId: message.requestId ?? "",
            fromName: message.fromPeerName,
            vote: message.vote
        )

        onCoffeeVote?(payload, peer)
        print("☕️ Received coffee vote from \(message.fromPeerName): \(message.vote)")
    }

    private func handleFatigueAlertReceived(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSFatigueAlertReceivedMessage.self, from: data) else {
            return
        }

        let peer = WSPeer(peerId: message.fromPeerId, peerName: message.fromPeerName)
        let payload = FatigueAlertPayload(
            type: .fatigueAlert,
            requestId: message.requestId,
            fromName: message.fromPeerName
        )

        onFatigueAlert?(payload, peer)
        print("😴 Received fatigue alert from \(message.fromPeerName)")
    }

    private func handleGoodBoyReceived(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSGoodBoyReceivedMessage.self, from: data) else {
            return
        }

        let peer = WSPeer(peerId: message.fromPeerId, peerName: message.fromPeerName)
        let payload = GoodBoyPayload(
            type: .goodBoy,
            requestId: message.requestId,
            fromName: message.fromPeerName
        )

        onGoodBoy?(payload, peer)
        print("🐕 Received GoodBoy from \(message.fromPeerName)")
    }

    private func handleError(_ data: Data) {
        guard let message = try? JSONDecoder().decode(WSErrorMessage.self, from: data) else {
            return
        }

        print("❌ Server error: \(message.message)")
    }

    // MARK: - Compatibility methods (not applicable for WebSocket)

    func connect(to peer: WSPeer) {
        // Not needed for WebSocket - peers are auto-discovered via server
        print("ℹ️ WebSocket mode: Peers are auto-discovered, no manual connection needed")
    }

    func isTrustedPeer(_ peer: WSPeer) -> Bool {
        // Trust management could be implemented if needed
        return true
    }

    func addTrustedPeer(_ peer: WSPeer) {
        // Not applicable in WebSocket mode
    }

    func removeTrustedPeer(_ peer: WSPeer) {
        // Not applicable in WebSocket mode
    }
}

// MARK: - WebSocketDelegate

extension WebSocketPeerService: WebSocketDelegate {
    nonisolated func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        Task { @MainActor in
            handleWebSocketEvent(event)
        }
    }

    private func handleWebSocketEvent(_ event: WebSocketEvent) {
        switch event {
        case .connected(_):
            print("✅ WebSocket connected")
            isConnected = true
            reconnectAttempts = 0  // Reset reconnect counter

            // Start heartbeat to keep connection alive
            startPingTimer()

            // Register immediately
            let registerMsg = WSRegisterMessage(
                peerId: peerId,
                peerName: peerName
            )
            sendMessage(registerMsg)

        case .disconnected(let reason, let code):
            print("❌ WebSocket disconnected: \(reason) (code: \(code))")
            isConnected = false
            connectedPeers = []
            stopPingTimer()

            // Exponential backoff: 2s, 4s, 8s, 16s, max 30s
            reconnectAttempts += 1
            let delay = min(pow(2.0, Double(reconnectAttempts)), maxReconnectDelay)

            print("🔄 Will attempt reconnect #\(reconnectAttempts) in \(Int(delay))s...")

            // Attempt to reconnect with exponential backoff
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if !isConnected {
                    print("🔄 Reconnecting...")
                    connect()
                }
            }

        case .text(let text):
            handleMessage(text)

        case .error(let error):
            print("❌ WebSocket error: \(error?.localizedDescription ?? "Unknown error")")

        case .cancelled:
            print("⚠️ WebSocket connection cancelled")

        default:
            break
        }
    }
}
