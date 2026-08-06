import SwiftUI

struct PreferencesView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            Section("Long Screen") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Show after \(Int(settings.idleDelaySeconds)) seconds idle")
                    Slider(value: $settings.idleDelaySeconds, in: 10...1800, step: 10)
                }
                Text("Manual hotkey: ⌥⌘L")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}
