import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var viewModel: UsageViewModel

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
                Text("\(viewModel.s5hPct)% (\(formatMins(viewModel.s5hMins)))")
            }
        }
    }
}
