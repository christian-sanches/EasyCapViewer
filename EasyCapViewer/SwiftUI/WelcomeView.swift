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
        .frame(width: 420, height: 200)
    }
}

@objc class ECVWelcomeSwiftHelper: NSObject {
    @objc static func createWelcomeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "EasyCapViewer"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 200)
        window.contentView = NSHostingView(rootView: WelcomeView())
        return window
    }
}
