// Lag test: measures how this Apple TV reaches the console (home network) and Xbox's servers (internet),
// then recommends a stream mode. Uses TCP handshake times, which track network round-trip time closely.
import Foundation
import Network

public struct ConnectionReport: Sendable, Equatable {
    public struct Sample: Sendable, Equatable {
        public var pingMs: Double
        public var jitterMs: Double
        public var loss: Double
    }
    public var linkName: String
    public var wired: Bool
    public var consoleName: String?
    public var console: Sample?
    public var internet: Sample?
    public var recommended: AnyroomStreamMode
    public var advice: [String]
}

@MainActor
public final class ConnectionTester: ObservableObject {
    @Published public private(set) var running = false
    @Published public private(set) var progress = ""
    @Published public private(set) var report: ConnectionReport?

    public init() {}

    /// Runs the test. `console` is a PlayStation to measure on the home network (PS5 port 9295, PS4 port 997).
    public func run(console: PSConsole?) async {
        guard !running else { return }
        running = true
        report = nil
        progress = "Checking the network link…"
        let link = await Self.currentLink()

        var consoleSample: ConnectionReport.Sample?
        if let console, !console.address.isEmpty {
            progress = "Measuring lag to \(console.name)…"
            consoleSample = await Self.measure(host: console.address, port: console.isPS5 ? 9295 : 997)
        }
        progress = "Measuring lag to Xbox servers…"
        let internetSample = await Self.measure(host: "xhome.gssv-play-prod.xboxlive.com", port: 443)

        let (mode, advice) = Self.recommend(wired: link.wired, console: consoleSample, internet: internetSample)
        report = ConnectionReport(linkName: link.name, wired: link.wired, consoleName: console?.name,
                                  console: consoleSample, internet: internetSample,
                                  recommended: mode, advice: advice)
        progress = ""
        running = false
    }

    nonisolated static func recommend(wired: Bool,
                                      console: ConnectionReport.Sample?,
                                      internet: ConnectionReport.Sample?) -> (AnyroomStreamMode, [String]) {
        var advice: [String] = []
        if !wired {
            advice.append("This Apple TV is on Wi-Fi. An Ethernet cable is the biggest single fix for lag and stutter.")
        }
        if let internet, internet.pingMs > 60 {
            advice.append(String(format: "Xbox servers are %.0f ms away, so cloud games will feel delayed. Remote Play to your own consoles isn't affected.", internet.pingMs))
        }
        // The home-network numbers decide the mode when there are any; otherwise use the internet numbers.
        guard let sample = console ?? internet else {
            advice.append("Couldn't reach the console or Xbox's servers. Check the network and that the console is on, then test again.")
            return (.balanced, advice)
        }
        let local = console != nil
        let slowPing = local ? 15.0 : 80.0
        let goodPing = local ? 6.0 : 40.0
        let mode: AnyroomStreamMode
        if sample.loss >= 0.15 || sample.jitterMs > 25 {
            mode = .dataSaver
            advice.append("The connection drops or wobbles a lot. Data Saver keeps the stream alive; move the router closer or use Ethernet.")
        } else if sample.loss > 0.03 || sample.jitterMs > 8 || sample.pingMs > slowPing {
            mode = .lowLag
        } else if wired && sample.pingMs <= goodPing && sample.jitterMs <= 3 {
            mode = .quality
        } else {
            mode = .balanced
        }
        if local, console?.loss ?? 0 > 0.5 {
            advice.append("The console barely answered. If it's in rest mode, wake it and test again for an accurate result.")
        }
        return (mode, advice)
    }

    // MARK: Measurement

    nonisolated static func measure(host: String, port: UInt16, samples: Int = 12) async -> ConnectionReport.Sample? {
        var times: [Double] = []
        var failures = 0
        for i in 0..<samples {
            if let ms = await handshakeTime(host: host, port: port, timeout: 1.5) {
                times.append(ms)
            } else {
                failures += 1
            }
            if i < samples - 1 { try? await Task.sleep(nanoseconds: 120_000_000) }
        }
        guard !times.isEmpty else { return nil }
        // The first handshake includes DNS and ARP lookups; drop it when there are enough others.
        let usable = times.count > 3 ? Array(times.dropFirst()) : times
        let sorted = usable.sorted()
        let median = sorted[sorted.count / 2]
        var jitter = 0.0
        if usable.count > 1 {
            jitter = zip(usable.dropFirst(), usable).map { abs($0 - $1) }.reduce(0, +) / Double(usable.count - 1)
        }
        return ConnectionReport.Sample(pingMs: median, jitterMs: jitter, loss: Double(failures) / Double(samples))
    }

    /// Time until the TCP handshake completes, or is refused (a refusal is still a full round trip), in ms.
    nonisolated static func handshakeTime(host: String, port: UInt16, timeout: TimeInterval) async -> Double? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: .tcp)
            let lock = NSLock()
            var finished = false
            let start = DispatchTime.now().uptimeNanoseconds
            func finish(_ value: Double?) {
                lock.lock()
                guard !finished else { lock.unlock(); return }
                finished = true
                lock.unlock()
                connection.stateUpdateHandler = nil
                connection.cancel()
                continuation.resume(returning: value)
            }
            func elapsed() -> Double { Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000 }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(elapsed())
                case .waiting(let error), .failed(let error):
                    if case .posix(let code) = error, code == .ECONNREFUSED {
                        finish(elapsed())
                    } else {
                        finish(nil)
                    }
                case .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }

    nonisolated static func currentLink() async -> (wired: Bool, name: String) {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let lock = NSLock()
            var done = false
            monitor.pathUpdateHandler = { path in
                lock.lock()
                guard !done else { lock.unlock(); return }
                done = true
                lock.unlock()
                monitor.cancel()
                let wired = path.usesInterfaceType(.wiredEthernet)
                let name = wired ? "Ethernet" : (path.usesInterfaceType(.wifi) ? "Wi-Fi" : (path.status == .satisfied ? "Other" : "Offline"))
                continuation.resume(returning: (wired, name))
            }
            monitor.start(queue: .global(qos: .userInitiated))
        }
    }
}
