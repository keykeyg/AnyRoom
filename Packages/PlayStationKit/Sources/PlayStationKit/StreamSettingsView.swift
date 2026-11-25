// Anyroom's stream settings sheet: one stream mode for both consoles, the lag test, and PlayStation options.
import SwiftUI

public struct AnyroomStreamSettingsView: View {
    @ObservedObject private var hub = PlayStationHub.shared
    @StateObject private var tester = ConnectionTester()
    @State private var prefs = StreamPreferences.load()
    @AppStorage("anyroom.ps.stats") private var showStats = false
    @AppStorage("anyroom.ps.display") private var displayModeRaw = DisplayMode.fit.rawValue
    private let onApplyMode: (AnyroomStreamMode) -> Void
    private let onDone: () -> Void

    /// `onApplyMode` sets the matching Xbox quality preset in the app's settings.
    public init(onApplyMode: @escaping (AnyroomStreamMode) -> Void, onDone: @escaping () -> Void) {
        self.onApplyMode = onApplyMode
        self.onDone = onDone
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AnyroomStreamMode.allCases) { mode in
                        Button { apply(mode) } label: {
                            HStack(alignment: .top, spacing: 20) {
                                Image(systemName: hub.mode == mode ? "checkmark.circle.fill" : "circle")
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(mode.rawValue).font(.headline)
                                    Text(mode.summary).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Stream mode (Xbox and PlayStation)")
                }

                Section {
                    Button(tester.running ? tester.progress : "Run lag test") {
                        let target = hub.consoles.first { $0.isRegistered && $0.power == .awake }
                            ?? hub.consoles.first { $0.power == .awake }
                            ?? hub.consoles.first
                        Task { await tester.run(console: target) }
                    }
                    .disabled(tester.running)
                    if let report = tester.report {
                        LabeledContent("Connection", value: report.linkName)
                        if let name = report.consoleName {
                            LabeledContent(name, value: Self.describe(report.console))
                        }
                        LabeledContent("Xbox servers", value: Self.describe(report.internet))
                        ForEach(report.advice, id: \.self) { line in
                            Text(line).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Button("Use \(report.recommended.rawValue) (recommended)") { apply(report.recommended) }
                            .disabled(hub.mode == report.recommended)
                    }
                } header: {
                    Text("Lag test")
                } footer: {
                    Text("Measures delay, jitter and dropped replies to your PlayStation and to Xbox's servers, then suggests a mode.")
                }

                Section {
                    Toggle("Use H.265 on PS5 (sharper at the same bitrate)", isOn: $hub.preferHEVC)
                    Button("Picture: \(displayModeRaw)") { cycleDisplayMode() }
                    Toggle("Show stream stats", isOn: $showStats)
                    Toggle("Controller rumble", isOn: prefBinding(\.rumbleEnabled))
                    Button("Rumble strength: \(prefs.rumbleIntensity)%") { cycleRumble() }
                        .disabled(!prefs.rumbleEnabled)
                    Toggle("DualSense adaptive triggers", isOn: prefBinding(\.adaptiveTriggersEnabled))
                    Toggle("Swap Cross and Circle", isOn: prefBinding(\.swapCrossMoon))
                    if hub.isSignedIn {
                        Button("Sign out of PlayStation Network (\(hub.psnOnlineId))", role: .destructive) { hub.signOut() }
                    }
                } header: {
                    Text("PlayStation")
                }

                Section {
                    Text("Resolution, HDR, server region, deadzone, rumble and party chat for Xbox are under Settings > Stream and Controller.")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Xbox")
                }
            }
            .navigationTitle("Stream settings")
            .toolbar { Button("Done", action: onDone) }
        }
    }

    private func apply(_ mode: AnyroomStreamMode) {
        hub.mode = mode
        onApplyMode(mode)
    }

    private func prefBinding(_ keyPath: WritableKeyPath<StreamPreferences, Bool>) -> Binding<Bool> {
        Binding(
            get: { prefs[keyPath: keyPath] },
            set: { prefs[keyPath: keyPath] = $0; prefs.save() }
        )
    }

    private func cycleRumble() {
        let steps = [25, 50, 75, 100]
        let next = steps.first { $0 > prefs.rumbleIntensity } ?? steps[0]
        prefs.rumbleIntensity = next
        prefs.save()
    }

    private func cycleDisplayMode() {
        let all = DisplayMode.allCases
        let current = all.firstIndex { $0.rawValue == displayModeRaw } ?? 0
        displayModeRaw = all[(current + 1) % all.count].rawValue
    }

    static func describe(_ sample: ConnectionReport.Sample?) -> String {
        guard let s = sample else { return "No reply" }
        return String(format: "%.0f ms, jitter %.0f ms, %.0f%% lost", s.pingMs, s.jitterMs, s.loss * 100)
    }
}
