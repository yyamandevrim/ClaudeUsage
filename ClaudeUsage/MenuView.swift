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

            SparklineView(history: viewModel.history)
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

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
    }
}
