import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        if let err = viewModel.errorMessage {
            if err == "credentials_missing" {
                Text("☁ ?")
            } else {
                Text("☁ !")
            }
        } else {
            HStack(spacing: 3) {
                Image(systemName: "circle.fill")
                    .foregroundColor(usageColor(viewModel.s5hPct))
                    .font(.system(size: 8))
                    .opacity(pulseOpacity)
                Text("\(viewModel.s5hPct)% (\(formatMins(viewModel.s5hMins)))")
            }
            .onChange(of: viewModel.s5hPct) { newVal in
                updatePulse(pct: newVal)
            }
            .onAppear {
                updatePulse(pct: viewModel.s5hPct)
            }
        }
    }

    private func updatePulse(pct: Int) {
        if pct >= 90 {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.25
            }
        } else {
            withAnimation(.default) {
                pulseOpacity = 1.0
            }
        }
    }
}
