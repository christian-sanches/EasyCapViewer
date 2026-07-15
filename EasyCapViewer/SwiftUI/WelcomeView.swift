import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(NSLocalizedString("No capture device found", comment: ""))
                .font(.system(size: 16, weight: .bold))
            Text(NSLocalizedString("Connect an EasyCap DC60 to your computer to begin.", comment: ""))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(minWidth: 420, minHeight: 200)
    }
}
