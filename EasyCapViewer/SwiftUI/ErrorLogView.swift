import SwiftUI
import Observation

@MainActor
@Observable
@objc final class ErrorLogModel: NSObject {
    struct Entry: Identifiable {
        let id = UUID()
        let level: UInt
        let message: String
        let date: Date
    }

    private(set) var entries: [Entry] = []

    var hasContent: Bool { !entries.isEmpty }

    @objc(appendLevel:message:) func append(level: UInt, message: String) {
        entries.append(Entry(level: level, message: message, date: Date()))
    }

    func clear() {
        entries.removeAll()
    }
}

struct ErrorLogView: View {
    var model: ErrorLogModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(attributedEntries)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .textSelection(.enabled)
                        .id("bottom")
                }
                .onChange(of: model.entries.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear Log") { model.clear() }
                    .disabled(!model.hasContent)
            }
        }
    }

    private var attributedEntries: AttributedString {
        var result = AttributedString()
        for entry in model.entries {
            let timestamp = formatDate(entry.date)
            let line = "\(timestamp) \(entry.message)\n"
            var attr = AttributedString(line)
            attr.foregroundColor = colorForLevel(entry.level)
            if let range = attr.range(of: timestamp) {
                attr[range].foregroundColor = .secondary
            }
            result.append(attr)
        }
        return result
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date) + ":"
    }

    private func colorForLevel(_ level: UInt) -> Color {
        switch level {
        case 1:     return .orange   // ECVWarning
        case 2:     return .red      // ECVError
        case 3:     return .red      // ECVCritical
        default:    return .primary  // ECVNotice
        }
    }
}

@objc class ECVErrorLogSwiftHelper: NSObject {
    @objc static func createErrorLogWindow(model: ErrorLogModel) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 350),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: true
        )
        window.title = "Error Log"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 200)
        window.contentView = NSHostingView(rootView: ErrorLogView(model: model))
        window.center()
        return window
    }
}
