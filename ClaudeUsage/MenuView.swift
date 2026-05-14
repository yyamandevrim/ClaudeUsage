import SwiftUI

struct MenuView: View {
    @ObservedObject var viewModel: UsageViewModel

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }

    var body: some View {
        if let err = viewModel.errorMessage {
            if err == "credentials_missing" {
                Text("Claude Code not found")
                    .foregroundColor(.secondary)
            } else {
                Text("Error: \(err)")
                    .foregroundColor(.red)
            }
        } else {
            Text("Status: \(viewModel.status)")

            if let warning = viewModel.tokenExpiryWarning {
                Text("⚠️ \(warning)")
                    .foregroundColor(.orange)
            }

            Divider()

            HStack {
                Text("5h window:")
                Spacer()
                Text("\(viewModel.s5hPct)%")
                    .foregroundColor(usageColor(viewModel.s5hPct))
                Text("— resets in \(formatMins(viewModel.s5hMins))")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("7d window:")
                Spacer()
                Text("\(viewModel.s7dPct)%")
                    .foregroundColor(usageColor(viewModel.s7dPct))
                Text("— resets in \(formatMins(viewModel.s7dMins))")
                    .foregroundColor(.secondary)
            }

            Divider()

            SparklineView(
                history: viewModel.history,
                useSevenDay: viewModel.sparklineMode == .sevenDay
            )
            .padding(.horizontal, 8)

            Picker("", selection: $viewModel.sparklineMode) {
                Text("5h").tag(SparklineMode.fiveHour)
                Text("7d").tag(SparklineMode.sevenDay)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 8)

            Divider()

            if let lu = viewModel.lastUpdate {
                Text("Last update: \(timeFormatter.string(from: lu))")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }

        Divider()

        Button("Refresh Now") {
            Task { await viewModel.refresh() }
        }

        Divider()

        Picker("Poll interval", selection: Binding(
            get: { viewModel.pollIntervalSecs },
            set: { viewModel.setPollInterval($0) }
        )) {
            Text("30s").tag(30)
            Text("1m").tag(60)
            Text("5m").tag(300)
        }
        .pickerStyle(.inline)

        Toggle("Launch at Login", isOn: Binding(
            get: { viewModel.isLaunchAtLoginEnabled },
            set: { viewModel.setLaunchAtLogin($0) }
        ))

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
