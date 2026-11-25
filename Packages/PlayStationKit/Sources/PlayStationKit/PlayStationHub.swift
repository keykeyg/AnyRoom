// PlayStationHub: Anyroom's public entry point to PS4/PS5 Remote Play.
// Wraps Pylux's HostStore (discovery, registered consoles, wake), PSN sign-in and registration,
// and builds the stream screen. Everything here runs on the main actor.
import Combine
import Foundation
import SwiftUI
import ChiakiBridge

/// A PlayStation console as the app shows it: found on the network, added by address, or both.
public struct PSConsole: Identifiable, Equatable, Sendable {
    public enum Power: Sendable, Equatable { case awake, standby, unknown }
    public let id: String
    public let name: String
    public let address: String
    public let isPS5: Bool
    public let power: Power
    public let isRegistered: Bool
    public let runningApp: String?

    public var kindName: String { isPS5 ? "PS5" : "PS4" }
}

@MainActor
public final class PlayStationHub: ObservableObject {
    public static let shared = PlayStationHub()

    @Published public private(set) var consoles: [PSConsole] = []
    @Published public private(set) var isSignedIn = false
    @Published public private(set) var psnOnlineId = ""
    @Published public private(set) var isSearching = false

    /// Stream settings, kept in UserDefaults. `mode` is shared with the Xbox side through the app.
    @Published public var mode: AnyroomStreamMode =
        AnyroomStreamMode(rawValue: UserDefaults.standard.string(forKey: "anyroom.mode") ?? "") ?? .quality {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "anyroom.mode") }
    }
    @Published public var preferHEVC: Bool = UserDefaults.standard.object(forKey: "anyroom.ps.hevc") as? Bool ?? true {
        didSet { UserDefaults.standard.set(preferHEVC, forKey: "anyroom.ps.hevc") }
    }

    let hostStore: HostStore
    private var displayHosts: [String: DisplayHost] = [:]
    private var bag = Set<AnyCancellable>()
    private var registService: PyluxRegistService?

    /// Sony's page that shows the "npsso" sign-in code once you're signed in to playstation.com.
    public static let npssoURL = URL(string: "https://ca.account.sony.com/api/v1/ssocookie")!
    public static let signInURL = URL(string: "https://www.playstation.com/")!

    private init() {
        _ = chiaki_session_bridge_init()
        hostStore = HostStore()
        // objectWillChange fires before the store's change lands, so rebuild on the next turn.
        hostStore.objectWillChange
            .sink { [weak self] _ in DispatchQueue.main.async { self?.rebuild() } }
            .store(in: &bag)
        refreshAccount()
        rebuild()
    }

    // MARK: Discovery

    /// Starts looking for consoles on the local network (call when the Consoles screen appears).
    public func startDiscovery() {
        isSearching = true
        hostStore.startDiscovery()
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.isSearching = false }
    }

    public func stopDiscovery() {
        hostStore.stopDiscovery()
        isSearching = false
    }

    /// Adds a console by IP address or host name, for networks where discovery can't see it.
    public func addConsole(address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        hostStore.addManualHost(ManualHost(host: trimmed))
    }

    /// Wakes a registered console from rest mode.
    public func wake(_ console: PSConsole) {
        guard let host = displayHosts[console.id] else { return }
        hostStore.wakeupHost(host)
        // Discovery picks up the new state within a few seconds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in self?.startDiscovery() }
    }

    /// Removes the pairing for a console. It can be registered again with a new PIN.
    public func forget(_ console: PSConsole) {
        guard let registered = displayHosts[console.id]?.registeredHost else { return }
        hostStore.deleteRegisteredHost(registered)
    }

    private func rebuild() {
        var map: [String: DisplayHost] = [:]
        var list: [PSConsole] = []
        for host in hostStore.displayHosts {
            // PSN-only entries need internet Remote Play, which isn't wired into the TV app yet.
            if case .psn = host { continue }
            map[host.id] = host
            var power = PSConsole.Power.unknown
            var running: String?
            if case .discovered(let d) = host {
                switch d.discoveredHost.state {
                case .ready: power = .awake
                case .standby: power = .standby
                default: power = .unknown
                }
                running = d.discoveredHost.runningAppName
            }
            list.append(PSConsole(
                id: host.id,
                name: host.name ?? (host.isPS5 ? "PS5" : "PS4"),
                address: host.hostAddress,
                isPS5: host.isPS5,
                power: power,
                isRegistered: host.isRegistered,
                runningApp: running
            ))
        }
        displayHosts = map
        if list != consoles { consoles = list }
    }

    // MARK: PSN account

    /// Signs in with the npsso code from Sony's page. Accepts the bare code or the whole JSON the page shows.
    public func signIn(npsso pasted: String) async -> Bool {
        let code = Self.extractNpsso(pasted)
        guard !code.isEmpty else { return false }
        let ok = await Task.detached(priority: .userInitiated) {
            PsnTokenManager.shared.exchangeNpssoForTokens(code)
        }.value
        refreshAccount()
        return ok && isSignedIn
    }

    public func signOut() {
        PsnTokenStore.shared.clearTokens()
        refreshAccount()
    }

    private func refreshAccount() {
        let store = PsnTokenStore.shared
        isSignedIn = store.hasTokens && !store.accountId.isEmpty
        psnOnlineId = store.onlineId
    }

    nonisolated static func extractNpsso(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let value = json["npsso"] as? String {
            return value
        }
        if let range = trimmed.range(of: #"[A-Za-z0-9]{64}"#, options: .regularExpression) {
            return String(trimmed[range])
        }
        return trimmed
    }

    // MARK: Registration

    public enum RegistrationError: LocalizedError, Equatable {
        case notSignedIn
        case badPin
        case consoleGone
        case failed(String)
        case canceled

        public var errorDescription: String? {
            switch self {
            case .notSignedIn: return "Sign in to PlayStation Network first. Pairing a PS5 needs your account ID."
            case .badPin: return "The PIN is the 8 digits shown on your console."
            case .consoleGone: return "That console isn't on the network any more. Check it's on and try again."
            case .failed(let log): return log.isEmpty ? "The console refused the pairing. Get a new PIN and try again." : log
            case .canceled: return "Pairing was canceled."
            }
        }
    }

    /// Pairs Anyroom with a console using the 8-digit PIN from
    /// PS5: Settings > System > Remote Play > Pair Device (PS4: Settings > Remote Play Connection Settings > Add Device).
    public func register(_ console: PSConsole, pin: String) async throws {
        let digits = pin.filter(\.isNumber)
        guard digits.count == 8, let pinValue = UInt32(digits) else { throw RegistrationError.badPin }
        guard let host = displayHosts[console.id], !host.hostAddress.isEmpty else { throw RegistrationError.consoleGone }
        let accountId = PsnTokenStore.shared.accountId
        guard let account = Data(base64Encoded: accountId), account.count == 8 else { throw RegistrationError.notSignedIn }

        let info = PyluxRegistInfo()
        info.target = console.isPS5 ? .PS5 : .PS4_GE8
        info.host = host.hostAddress
        info.broadcast = false
        info.pin = pinValue
        info.psnAccountId = account

        registService?.stop()
        let registered: RegisteredHost = try await withCheckedThrowingContinuation { continuation in
            var finished = false
            registService = PyluxRegistService(info: info) { result, hostData, log in
                DispatchQueue.main.async {
                    guard !finished else { return }
                    finished = true
                    switch result {
                    case .success:
                        guard let hd = hostData else {
                            continuation.resume(throwing: RegistrationError.failed(log ?? ""))
                            return
                        }
                        continuation.resume(returning: RegisteredHost(
                            target: Int(hd.target),
                            apSsid: hd.apSsid,
                            apBssid: hd.apBssid,
                            apKey: hd.apKey,
                            apName: hd.apName,
                            serverMac: hd.serverMac,
                            serverNickname: hd.serverNickname,
                            rpRegistKey: hd.rpRegistKey,
                            rpKeyType: Int(hd.rpKeyType),
                            rpKey: hd.rpKey
                        ))
                    case .canceled:
                        continuation.resume(throwing: RegistrationError.canceled)
                    default:
                        continuation.resume(throwing: RegistrationError.failed(log ?? ""))
                    }
                }
            }
        }
        registService = nil
        hostStore.addRegisteredHost(registered)
        // Remember which address the pairing belongs to when the console was added by hand.
        if case .manual(let m) = host {
            var manual = m.manualHost
            manual.registeredHostId = registered.id
            hostStore.updateManualHost(manual)
        }
    }

    // MARK: Streaming

    func connectInfo(for console: PSConsole) -> StreamConnectInfo? {
        guard let host = displayHosts[console.id], let registered = host.registeredHost, !host.hostAddress.isEmpty else {
            return nil
        }
        // H.265 halves the bitrate for the same picture; PS4 only speaks H.264.
        let hevc = console.isPS5 && preferHEVC
        let params = mode.playStation(hevc: hevc)
        return StreamConnectInfo(
            host: host.hostAddress,
            ps5: console.isPS5,
            registKey: registered.rpRegistKey,
            morning: registered.rpKey,
            videoWidth: params.width,
            videoHeight: params.height,
            videoMaxFps: params.fps,
            videoBitrate: params.bitrate,
            videoCodec: hevc ? 1 : 0
        )
    }

    /// The full-screen stream for a registered console, or nil if it isn't paired.
    public func streamView(for console: PSConsole, onExit: @escaping @MainActor () -> Void) -> AnyView? {
        guard let info = connectInfo(for: console) else { return nil }
        return AnyView(PSStreamScreen(console: console, connectInfo: info, onExit: onExit))
    }
}
