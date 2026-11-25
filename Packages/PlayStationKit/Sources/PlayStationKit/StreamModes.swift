// Anyroom's stream modes: one choice that sets both the PlayStation stream and the Xbox quality preset.
import Foundation

public enum AnyroomStreamMode: String, CaseIterable, Identifiable, Sendable {
    case quality = "Quality"
    case balanced = "Balanced"
    case lowLag = "Low Lag"
    case dataSaver = "Data Saver"

    public var id: String { rawValue }

    public var summary: String {
        switch self {
        case .quality: return "Sharpest picture. Xbox 1440p, PS5 1080p at the highest bitrate. Best on Ethernet."
        case .balanced: return "1080p at 60 fps with a moderate bitrate. Good on strong Wi-Fi."
        case .lowLag: return "720p at 60 fps, low bitrate and Xbox low-latency mode. Least input lag; best for shooters."
        case .dataSaver: return "720p, lowest bitrate. For weak Wi-Fi or a metered connection."
        }
    }

    /// The Xbox quality preset this mode maps to (see StratixCore's StreamConfigBuilder).
    public var xboxPreset: String {
        switch self {
        case .quality: return "High Quality"
        case .balanced: return "Balanced"
        case .lowLag: return "Competitive"
        case .dataSaver: return "Low Data"
        }
    }

    public init?(xboxPreset: String) {
        guard let mode = Self.allCases.first(where: { $0.xboxPreset == xboxPreset }) else { return nil }
        self = mode
    }

    /// PlayStation stream parameters for this mode. Bitrates in kbps; H.265 needs about 25% less than H.264.
    func playStation(hevc: Bool) -> (width: UInt32, height: UInt32, fps: UInt32, bitrate: UInt32) {
        switch self {
        case .quality: return (1920, 1080, 60, hevc ? 20_000 : 25_000)
        case .balanced: return (1920, 1080, 60, hevc ? 12_000 : 15_000)
        case .lowLag: return (1280, 720, 60, hevc ? 6_000 : 8_000)
        case .dataSaver: return (1280, 720, 30, hevc ? 3_000 : 4_000)
        }
    }
}
