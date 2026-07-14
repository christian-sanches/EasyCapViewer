import Cocoa
import SwiftUI

@objc class ECVSwiftConfigController: NSWindowController {
    private let viewModel = ConfigViewModel()

    @objc static let sharedSwiftConfigController = ECVSwiftConfigController()

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 370),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: true
        )
        panel.title = "Configure Device"
        panel.hidesOnDeactivate = true
        panel.isFloatingPanel = false
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.titlebarAppearsTransparent = false
        panel.titleVisibility = .visible

        super.init(window: panel)

        let contentView = NSHostingView(rootView: ConfigView(viewModel: viewModel))
        panel.contentView = contentView

        panel.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var _captureDocument: ECVCaptureDocument?

    @objc var captureDocument: ECVCaptureDocument? {
        return _captureDocument
    }

    @objc func setCaptureDocument(_ doc: ECVCaptureDocument?) {
        _captureDocument = doc
        viewModel.setDocument(doc)
    }

    @objc func showConfig(_ sender: Any?) {
        guard let window = self.window else { return }
        if window.isVisible {
            window.close()
        } else {
            window.center()
            window.makeKeyAndOrderFront(sender)
        }
    }
}
