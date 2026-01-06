import SwiftUI
import AppKit
import Sparkle

@main
struct SurrenderOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}


@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // WebSocket connection to Railway backend
    let peerService = WebSocketPeerService(serverURL: "wss://surrenderback-production.up.railway.app")
    private let overlay = OverlayService()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let updaterController: SPUStandardUpdaterController

    override init() {
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup menu bar
        setupMenuBar()

        // Start WebSocket service
        peerService.start()

        peerService.onSurrenderRequest = { [weak self] (req: SurrenderRequestPayload, fromPeer: WSPeer) in
            guard let self else { return }

            // Affiche l'overlay
            self.overlay.present(
                title: "Surrender – \(req.fromName)",
                duration: req.duration,
                onYes: {
                    self.peerService.sendVote(to: fromPeer, requestId: req.requestId, vote: "yes")
                },
                onNo: {
                    self.peerService.sendVote(to: fromPeer, requestId: req.requestId, vote: "no")
                }
            )
        }

        peerService.onSurrenderVote = { [weak self] (vote: SurrenderVotePayload, fromPeer: WSPeer) in
            guard let self else { return }

            let response = vote.vote == "yes" ? "✅ Yes!" : "❌ No"
            self.overlay.presentNotification(
                title: "🏴 Surrender Response",
                message: "\(fromPeer.displayName) said: \(response)"
            )
            print("✅ Vote reçu de \(fromPeer.displayName): \(vote.vote) (req \(vote.requestId))")
        }

        peerService.onCoffeeRequest = { [weak self] (req: CoffeeRequestPayload, fromPeer: WSPeer) in
            guard let self else { return }

            // Affiche l'overlay
            self.overlay.present(
                title: "☕️ Coffee? – \(req.fromName)",
                duration: req.duration,
                onYes: {
                    self.peerService.sendCoffeeVote(to: fromPeer, requestId: req.requestId, vote: "yes")
                },
                onNo: {
                    self.peerService.sendCoffeeVote(to: fromPeer, requestId: req.requestId, vote: "no")
                }
            )
        }

        peerService.onCoffeeVote = { [weak self] (vote: CoffeeVotePayload, fromPeer: WSPeer) in
            guard let self else { return }

            let response = vote.vote == "yes" ? "✅ Yes!" : "❌ No"
            self.overlay.presentNotification(
                title: "☕️ Coffee Response",
                message: "\(fromPeer.displayName) said: \(response)"
            )
            print("☕️ Coffee vote reçu de \(fromPeer.displayName): \(vote.vote) (req \(vote.requestId))")
        }

        peerService.onFatigueAlert = { [weak self] (alert: FatigueAlertPayload, fromPeer: WSPeer) in
            guard let self else { return }

            let advice = """
              Prends une pause de 5-10 minutes
              Regarde au loin (règle 20-20-20)
              Lève-toi et bouge un peu
              Bois de l'eau
              Étire-toi et respire profondément
            """

            self.overlay.presentNotification(
                title: " Fatigue Détectée – \(fromPeer.displayName)",
                message: advice,
                isDismissible: true
            )
            print("😴 Fatigue alert reçu de \(fromPeer.displayName)")
        }

        peerService.onGoodBoy = { [weak self] (goodBoy: GoodBoyPayload, fromPeer: WSPeer) in
            guard let self else { return }

            self.overlay.presentGoodBoy(fromName: fromPeer.displayName)
            print("🐕 GoodBoy reçu de \(fromPeer.displayName)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        peerService.stop()
    }

    private func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use SF Symbol for the icon
            button.image = NSImage(systemSymbolName: "flag.fill", accessibilityDescription: "Surrender")
        }

        statusItem.menu = createMenu()
        self.statusItem = statusItem

        // Update menu when peers change
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PeersDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.statusItem?.menu = self?.createMenu()
        }
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Connection status
        let statusText = peerService.isConnected ? "🟢 Connected to server" : "🔴 Disconnected"
        let statusItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Connected peers section
        let connectedPeers = peerService.connectedPeers

        if connectedPeers.isEmpty {
            let item = NSMenuItem(title: "No peers connected", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            for peer in connectedPeers {
                // Create parent item with peer name
                let parentItem = NSMenuItem(title: peer.displayName, action: nil, keyEquivalent: "")
                let submenu = NSMenu()

                // Send surrender
                let sendItem = NSMenuItem(
                    title: "Surrender 🏴",
                    action: #selector(sendSurrenderWS(_:)),
                    keyEquivalent: ""
                )
                sendItem.representedObject = peer
                sendItem.target = self
                submenu.addItem(sendItem)

                // Send coffee
                let coffeeItem = NSMenuItem(
                    title: "Coffee ☕️",
                    action: #selector(sendCoffeeWS(_:)),
                    keyEquivalent: ""
                )
                coffeeItem.representedObject = peer
                coffeeItem.target = self
                submenu.addItem(coffeeItem)

                // Send fatigue alert
                let fatigueItem = NSMenuItem(
                    title: "Fatigue Alert 😴",
                    action: #selector(sendFatigueAlertWS(_:)),
                    keyEquivalent: ""
                )
                fatigueItem.representedObject = peer
                fatigueItem.target = self
                submenu.addItem(fatigueItem)

                // Send GoodBoy
                let goodBoyItem = NSMenuItem(
                    title: "GoodBoy 🐕",
                    action: #selector(sendGoodBoyWS(_:)),
                    keyEquivalent: ""
                )
                goodBoyItem.representedObject = peer
                goodBoyItem.target = self
                submenu.addItem(goodBoyItem)

                parentItem.submenu = submenu
                menu.addItem(parentItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    @objc private func sendSurrenderWS(_ sender: NSMenuItem) {
        guard let peer = sender.representedObject as? WSPeer else { return }

        // Default duration: 12 seconds
        peerService.sendSurrenderRequest(to: peer, duration: 12)

        // Optional: Show notification or feedback
        print("📤 Sending surrender to \(peer.displayName)")
    }

    @objc private func sendCoffeeWS(_ sender: NSMenuItem) {
        guard let peer = sender.representedObject as? WSPeer else { return }

        // Default duration: 12 seconds
        peerService.sendCoffeeRequest(to: peer, duration: 12)

        // Optional: Show notification or feedback
        print("☕️ Sending coffee request to \(peer.displayName)")
    }

    @objc private func sendFatigueAlertWS(_ sender: NSMenuItem) {
        guard let peer = sender.representedObject as? WSPeer else { return }

        peerService.sendFatigueAlert(to: peer)

        print("😴 Sending fatigue alert to \(peer.displayName)")
    }

    @objc private func sendGoodBoyWS(_ sender: NSMenuItem) {
        guard let peer = sender.representedObject as? WSPeer else { return }

        peerService.sendGoodBoy(to: peer)

        print("🐕 Sending GoodBoy to \(peer.displayName)")
    }

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = PeersView(peerService: peerService, overlayService: overlay)
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Surrender Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}


@MainActor
final class OverlayService {
    private var panel: NSPanel?
    private var task: Task<Void, Never>?

    func present(title: String, duration: TimeInterval, onYes: (() -> Void)? = nil, onNo: (() -> Void)? = nil) {
        task?.cancel()

        let vm = OverlayViewModel(
            title: title,
            duration: duration,
            onYes: { [weak self] in
                onYes?()
                self?.finish(message: "You voted yes.")
            },
            onNo: { [weak self] in
                onNo?()
                self?.finish(message: "You voted no.")
            }
        )

        let view = OverlayView(viewModel: vm)

        if panel == nil {
            panel = makePanel(rootView: view)
        } else {
            panel?.contentView = NSHostingView(rootView: view)
        }

        centerOnActiveScreen()
        panel?.orderFrontRegardless()

        task = Task { [weak self] in
            guard let self else { return }
            await self.runCountdown(vm: vm, duration: duration)
        }
    }

    func presentNotification(title: String, message: String, duration: TimeInterval = 3.0, isDismissible: Bool = false) {
        task?.cancel()

        let vm = OverlayViewModel(
            title: title,
            duration: 0, // No countdown for notifications
            onYes: { [weak self] in
                self?.panel?.orderOut(nil)
            },
            onNo: {},
            isDismissible: isDismissible
        )
        vm.footer = message
        vm.progress = 1.0 // Full progress bar (or could be 0 to hide it)

        let view = OverlayView(viewModel: vm)

        if panel == nil {
            panel = makePanel(rootView: view)
        } else {
            panel?.contentView = NSHostingView(rootView: view)
        }

        centerOnActiveScreen()
        panel?.orderFrontRegardless()

        // Auto close after duration (only if not dismissible)
        if !isDismissible {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                panel?.orderOut(nil)
            }
        }
    }

    func presentGoodBoy(fromName: String) {
        task?.cancel()

        let vm = OverlayViewModel(
            title: "Good Boy! – \(fromName)",
            duration: 0,
            onYes: { [weak self] in
                self?.panel?.orderOut(nil)
            },
            onNo: {},
            isDismissible: true
        )
        vm.showImage = true

        let view = OverlayView(viewModel: vm)

        if panel == nil {
            panel = makePanel(rootView: view)
        } else {
            panel?.contentView = NSHostingView(rootView: view)
        }

        centerOnActiveScreen()
        panel?.orderFrontRegardless()
    }

    private func runCountdown(vm: OverlayViewModel, duration: TimeInterval) async {
        let start = Date()
        while !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(start)
            let p = min(max(elapsed / duration, 0), 1)
            vm.progress = p

            if p >= 1 {
                finish(message: "Vote expired.")
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        }
    }

    private func finish(message: String) {
        task?.cancel()
        task = nil

        vmSetFooter(message)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            panel?.orderOut(nil)
        }
    }

    private func vmSetFooter(_ message: String) {
        guard let hosting = panel?.contentView as? NSHostingView<OverlayView> else { return }
        hosting.rootView.viewModel.footer = message
    }

    private func makePanel<Content: View>(rootView: Content) -> NSPanel {
        let hosting = NSHostingView(rootView: rootView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Ne vole pas le focus
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = false

        panel.contentView = hosting
        return panel
    }

    private func centerOnActiveScreen() {
        guard let panel else { return }

        // Choix de l'écran : celui où est la souris
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main

        guard let screen else { return }
        let frame = screen.visibleFrame

        let x = frame.midX - panel.frame.width / 2
        let y = frame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
final class OverlayViewModel: ObservableObject {
    let title: String
    let duration: TimeInterval
    let onYes: () -> Void
    let onNo: () -> Void
    let isDismissible: Bool

    @Published var progress: Double = 0
    @Published var footer: String = ""
    @Published var showImage: Bool = false

    init(title: String, duration: TimeInterval, onYes: @escaping () -> Void, onNo: @escaping () -> Void, isDismissible: Bool = false) {
        self.title = title
        self.duration = duration
        self.onYes = onYes
        self.onNo = onNo
        self.isDismissible = isDismissible
    }
}

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        VStack(spacing: 16) {
            // GoodBoy image or Icon + Title
            if viewModel.showImage {
                // Large dog image for GoodBoy
                VStack(spacing: 12) {
                    Text(viewModel.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Image("GoodBoyDog")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 300, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            } else {
                // Icon + Title
                HStack(spacing: 12) {
                    // Icon based on title
                    if viewModel.title.contains("Surrender") {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.orange)
                    } else if viewModel.title.contains("Coffee") {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.brown)
                    } else if viewModel.title.contains("Fatigue") {
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.purple)
                    } else {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        if !viewModel.footer.isEmpty {
                            Text(viewModel.footer)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()
                }
            }

            // Progress bar (only if duration > 0)
            if viewModel.duration > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor)
                            .frame(width: geometry.size.width * viewModel.progress, height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Buttons
            if viewModel.duration > 0 {
                // Yes/No buttons for requests
                HStack(spacing: 8) {
                    Spacer()

                    Button("No") { viewModel.onNo() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                    Button("Yes") { viewModel.onYes() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            } else if viewModel.isDismissible {
                // OK button for dismissible notifications
                HStack(spacing: 8) {
                    Spacer()

                    Button("OK") { viewModel.onYes() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
        }
        .padding(20)
        .frame(width: viewModel.showImage ? 340 : 380)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        )
    }
}
