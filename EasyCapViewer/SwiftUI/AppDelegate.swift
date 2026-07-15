import Cocoa

@objc class ECVAppDelegate: NSObject, NSApplicationDelegate {

    private static let _shared = ECVAppDelegate()

    @objc static func shared() -> ECVAppDelegate {
        return _shared
    }

    @objc private(set) var mainWindowController: MainWindowController!

    // MARK: - NSApplicationDelegate

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Window Management

    @objc func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        mainWindowController.showWindow(nil)
    }
}
