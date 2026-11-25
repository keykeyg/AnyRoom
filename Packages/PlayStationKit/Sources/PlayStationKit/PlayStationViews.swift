// Anyroom's PlayStation screens for Apple TV: the console section on the Consoles page,
// pairing (PSN sign-in + PIN), and the full-screen stream with its menu and stats.
import Combine
import CoreImage.CIFilterBuiltins
import GameController
import SwiftUI
import UIKit
import ChiakiBridge

// MARK: - Consoles section

/// The PlayStation part of the Consoles page: every PS4/PS5 found on the network or added by address.
public struct PlayStationConsolesSection: View {
    @ObservedObject private var hub = PlayStationHub.shared
    @State private var pairing: PSConsole?
    @State private var streaming: PSConsole?
    @State private var addingAddress = false
    @State private var address = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text("PlayStation")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                if hub.isSearching { ProgressView() }
                Spacer()
                Button("Search again") { hub.startDiscovery() }
                Button("Add by IP address") { addingAddress = true }
            }

            if hub.consoles.isEmpty {
                Text("No PS5 or PS4 found yet. Turn on Settings > System > Remote Play on your console, keep it on the same network as this Apple TV, then search again.")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 28) {
                        ForEach(hub.consoles) { console in
                            PSConsoleCard(console: console,
                                          onPlay: { streaming = console },
                                          onWake: { hub.wake(console) },
                                          onPair: { pairing = console },
                                          onForget: { hub.forget(console) })
                        }
                    }
                    .padding(.vertical, 24)
                }
                .scrollClipDisabled()
            }
        }
        .onAppear { hub.startDiscovery() }
        .onDisappear { hub.stopDiscovery() }
        .sheet(item: $pairing) { console in
            PSPairingView(console: console) { pairing = nil }
        }
        .fullScreenCover(item: $streaming) { console in
            if let screen = hub.streamView(for: console, onExit: { streaming = nil }) {
                screen.ignoresSafeArea()
            } else {
                Text("Pair this console first.").onAppear { streaming = nil }
            }
        }
        .alert("Add a console by IP address", isPresented: $addingAddress) {
            TextField("192.168.1.20", text: $address)
            Button("Add") { hub.addConsole(address: address); address = "" }
            Button("Cancel", role: .cancel) { address = "" }
        } message: {
            Text("Find it on the console under Settings > Network > View Connection Status.")
        }
    }
}

struct PSConsoleCard: View {
    let console: PSConsole
    let onPlay: () -> Void
    let onWake: () -> Void
    let onPair: () -> Void
    let onForget: () -> Void

    private var status: String {
        switch console.power {
        case .awake: return console.runningApp.map { "On · \($0)" } ?? "On"
        case .standby: return "Rest mode"
        case .unknown: return console.address.isEmpty ? "Not found" : console.address
        }
    }

    var body: some View {
        Button(action: primaryAction) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: console.isPS5 ? "logo.playstation" : "gamecontroller.fill")
                    .font(.system(size: 44))
                Text(console.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text("\(console.kindName) · \(status)")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(primaryTitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .padding(.top, 6)
            }
            .frame(width: 420, height: 230, alignment: .leading)
            .padding(24)
        }
        .buttonStyle(.card)
        .contextMenu {
            if console.isRegistered {
                Button("Wake") { onWake() }
                Button("Pair again") { onPair() }
                Button("Forget this console", role: .destructive) { onForget() }
            } else {
                Button("Pair") { onPair() }
            }
        }
    }

    private var primaryTitle: String {
        if !console.isRegistered { return "Pair to play" }
        return console.power == .standby ? "Wake and play" : "Play"
    }

    private func primaryAction() {
        if !console.isRegistered { onPair(); return }
        if console.power == .standby { onWake() }
        onPlay()
    }
}

// MARK: - Pairing

struct PSPairingView: View {
    let console: PSConsole
    let onDone: () -> Void
    @ObservedObject private var hub = PlayStationHub.shared
    @State private var npsso = ""
    @State private var pin = ""
    @State private var working = false
    @State private var message: String?
    @State private var paired = false

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Pair \(console.name)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))

            if paired {
                Text("Paired. Pick the console on the Consoles page to play.")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                Button("Done", action: onDone)
            } else if !hub.isSignedIn {
                signInStep
            } else {
                pinStep
            }

            if let message {
                Text(message)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(80)
        .frame(maxWidth: 1400, alignment: .leading)
        .disabled(working)
    }

    private var signInStep: some View {
        HStack(alignment: .top, spacing: 60) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Step 1 of 2: sign in to PlayStation Network")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("1. On your phone, sign in at playstation.com.\n2. Then scan this code to open Sony's sign-in code page.\n3. Copy the long code after \"npsso\" and paste it below with your iPhone's Apple TV keyboard.")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("npsso code", text: $npsso)
                    .textContentType(.oneTimeCode)
                Button(working ? "Signing in…" : "Sign in") {
                    working = true; message = nil
                    Task {
                        let ok = await hub.signIn(npsso: npsso)
                        working = false
                        message = ok ? nil : "That code didn't work. Codes expire quickly: open the page again and copy a fresh one."
                    }
                }
            }
            QRCodeView(text: PlayStationHub.npssoURL.absoluteString)
                .frame(width: 320, height: 320)
        }
    }

    private var pinStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Step 2 of 2: enter the console's PIN")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(console.isPS5
                 ? "On your PS5, open Settings > System > Remote Play > Pair Device. Enter the 8-digit number it shows."
                 : "On your PS4, open Settings > Remote Play Connection Settings > Add Device. Enter the 8-digit number it shows.")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            TextField("8-digit PIN", text: $pin)
                .keyboardType(.numberPad)
            HStack(spacing: 24) {
                Button(working ? "Pairing…" : "Pair") {
                    working = true; message = nil
                    Task {
                        do {
                            try await hub.register(console, pin: pin)
                            paired = true
                        } catch {
                            message = error.localizedDescription
                        }
                        working = false
                    }
                }
                Button("Use a different PSN account") { hub.signOut() }
            }
            if !hub.psnOnlineId.isEmpty {
                Text("Signed in as \(hub.psnOnlineId)")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct QRCodeView: View {
    let text: String
    var body: some View {
        if let image = Self.make(text) {
            Image(uiImage: image).interpolation(.none).resizable().scaledToFit()
        } else {
            Text(text).font(.footnote)
        }
    }

    static func make(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Stream

struct PSStreamScreen: View {
    let console: PSConsole
    let onExit: @MainActor () -> Void
    @StateObject private var session: StreamSession
    @State private var showMenu = false
    @AppStorage("anyroom.ps.stats") private var showStats = false
    @State private var statsText = ""
    @State private var lastDropped: UInt64?
    @State private var pin = ""
    @State private var exited = false

    init(console: PSConsole, connectInfo: StreamConnectInfo, onExit: @escaping @MainActor () -> Void) {
        self.console = console
        self.onExit = onExit
        _session = StateObject(wrappedValue: StreamSession(connectInfo: connectInfo, input: StreamInput()))
    }

    var body: some View {
        PSControllerInputHost(interactive: showMenu || needsRemote,
                              onMenuButton: { showMenu.toggle() }) {
            ZStack {
                Color.black.ignoresSafeArea()
                StreamVideoView(aspectRatio: 16.0 / 9.0, displayMode: .fit) { view in
                    session.attachToView(view)
                }
                .ignoresSafeArea()

                stateOverlay

                if showStats, case .connected = session.state, !statsText.isEmpty {
                    VStack {
                        HStack {
                            Text(statsText)
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .padding(14)
                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(40)
                }

                if showMenu { menu }
            }
        }
        .ignoresSafeArea()
        .onAppear { session.resume() }
        .onDisappear { session.shutdown() }
        .onReceive(session.$menuRequestToken.dropFirst()) { _ in showMenu = true }
        .onReceive(session.$state) { state in handle(state) }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in updateStats() }
    }

    /// The Siri Remote drives UIKit only while something on screen needs it.
    private var needsRemote: Bool {
        switch session.state {
        case .connected: return false
        default: return true
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch session.state {
        case .idle, .connecting:
            VStack(spacing: 18) {
                ProgressView()
                Text("Connecting to \(console.name)…")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                if !session.connectionPhase.isEmpty {
                    Text(session.connectionPhase).foregroundStyle(.secondary)
                }
                Button("Cancel") { exit() }
            }
        case .connected:
            EmptyView()
        case .loginPinRequest(let incorrect):
            VStack(spacing: 18) {
                Text(incorrect ? "Wrong PIN. Try again." : "This console asks for its login passcode.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                TextField("Passcode", text: $pin).keyboardType(.numberPad).frame(width: 400)
                HStack {
                    Button("Send") { session.sendLoginPin(pin); pin = "" }
                    Button("Cancel") { exit() }
                }
            }
            .padding(40)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
        case .createError(let code, let message):
            failure("Couldn't start the stream", detail: message ?? String(cString: chiaki_session_bridge_error_string(code)))
        case .quit(let reason, let reasonString):
            if chiaki_session_bridge_quit_reason_is_error(reason) {
                failure("The stream ended", detail: reasonString ?? String(cString: chiaki_session_bridge_quit_reason_string(reason)))
            } else {
                EmptyView()
            }
        }
    }

    private func failure(_ title: String, detail: String) -> some View {
        VStack(spacing: 18) {
            Text(title).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(detail).font(.system(size: 22, weight: .medium, design: .rounded)).multilineTextAlignment(.center)
            Text("If the console is in rest mode, wake it first. If it was paired from another app or reset, pair it again.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Back") { exit() }
        }
        .frame(maxWidth: 1100)
        .padding(40)
        .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 20))
    }

    private var menu: some View {
        VStack(spacing: 22) {
            Text(console.name).font(.system(size: 34, weight: .heavy, design: .rounded))
            Button("Resume") { showMenu = false }
            Button(showStats ? "Hide stream stats" : "Show stream stats") { showStats.toggle(); showMenu = false }
            Button("Quit stream", role: .destructive) { exit() }
            Text("Play/Pause on the Siri Remote, or OPTIONS + SHARE on the controller, opens this menu.")
                .font(.system(size: 18, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
        }
        .padding(48)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
    }

    private func handle(_ state: StreamState) {
        if case .quit(let reason, _) = state, !chiaki_session_bridge_quit_reason_is_error(reason) {
            exit()
        }
    }

    private func updateStats() {
        guard showStats, let m = session.metrics() else { return }
        let dropped = lastDropped.map { m.droppedFrames >= $0 ? m.droppedFrames - $0 : 0 } ?? 0
        lastDropped = m.droppedFrames
        statsText = String(format: "%ldx%ld  %.0f fps  %.1f Mbps  %.0f ms  loss %.1f%%  dropped %llu/s",
                           m.width, m.height, m.fps, m.bitrateMbps, m.rttMs, m.packetLoss * 100, dropped)
    }

    private func exit() {
        guard !exited else { return }
        exited = true
        session.shutdown()
        onExit()
    }
}

// MARK: - Controller routing

/// Hosts the stream so game-controller buttons go only to the console (Circle/B doesn't close the screen).
/// Play/Pause on the Siri Remote toggles Anyroom's menu; `interactive` hands the remote back to UIKit
/// while a menu or prompt is on screen.
struct PSControllerInputHost<Content: View>: UIViewControllerRepresentable {
    let interactive: Bool
    let onMenuButton: () -> Void
    let content: Content

    init(interactive: Bool, onMenuButton: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.interactive = interactive
        self.onMenuButton = onMenuButton
        self.content = content()
    }

    func makeUIViewController(context: Context) -> PSControllerInputViewController<Content> {
        PSControllerInputViewController(rootView: content, onMenuButton: onMenuButton)
    }

    func updateUIViewController(_ controller: PSControllerInputViewController<Content>, context: Context) {
        controller.hostingController.rootView = content
        controller.onMenuButton = onMenuButton
        controller.controllerUserInteractionEnabled = interactive
    }
}

final class PSControllerInputViewController<Content: View>: GCEventViewController {
    let hostingController: UIHostingController<Content>
    var onMenuButton: () -> Void

    init(rootView: Content, onMenuButton: @escaping () -> Void) {
        hostingController = UIHostingController(rootView: rootView)
        self.onMenuButton = onMenuButton
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        controllerUserInteractionEnabled = false
        hostingController.view.backgroundColor = .clear
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = becomeFirstResponder()
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .playPause }) { onMenuButton(); return }
        // Menu/Back closes Anyroom's menu while it's open; during play it never leaves the stream.
        if presses.contains(where: { $0.type == .menu }) {
            if controllerUserInteractionEnabled { onMenuButton() }
            return
        }
        super.pressesEnded(presses, with: event)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .playPause || $0.type == .menu }) { return }
        super.pressesBegan(presses, with: event)
    }
}
