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
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(model.entries) { entry in
                            HStack(alignment: .top, spacing: 4) {
                                Text(formatDate(entry.date))
                                    .foregroundStyle(.secondary)
                                Text(entry.message)
                                    .foregroundStyle(colorForLevel(entry.level))
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: model.entries.count) { _, _ in
                    if let last = model.entries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
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
