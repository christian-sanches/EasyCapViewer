import SwiftUI

/// SwiftUI menu definitions for EasyCapViewer.
///
/// This file defines the menu structure declaratively using SwiftUI.
/// It is currently used as a reference for the menu layout and for
/// future migration via NSHostingMenu when the First Responder
/// dependencies are resolved.
///
/// For now, the actual menu is still loaded from ECVMenu.xib.
/// This file will be activated in a future iteration when the
/// app lifecycle is restructured.
struct AppMenuBody: View {
    var body: some View {
        // App Menu
        Group {
            Button("About EasyCapViewer") { NSApplication.shared.orderFrontStandardAboutPanel(nil) }
            Divider()
            Button("Preferences...") { ECVSwiftConfigController.sharedSwiftConfigController()?.showConfig(nil) }
                .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button("Services") { NSApplication.shared.servicesMenu?.popUp(menuPosition: NSPoint.zero, for: nil, with: nil) }
            Divider()
            Button("Hide EasyCapViewer") { NSApplication.shared.hide(nil) }
                .keyboardShortcut("h", modifiers: .command)
            Button("Hide Others") { NSApplication.shared.hideOtherApplications(nil) }
                .keyboardShortcut("h", modifiers: [.command, .option])
            Button("Show All") { NSApplication.shared.unhideAllApplications(nil) }
            Divider()
            Button("Quit EasyCapViewer") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }

        // File Menu
        Group {
            Button("New Capture Window") { NSDocumentController.shared.newDocument(nil) }
                .keyboardShortcut("n", modifiers: .command)
            Divider()
            Button("Close") { NSApplication.shared.keyWindow?.close() }
                .keyboardShortcut("w", modifiers: .command)
        }

        // Edit Menu
        Group {
            Button("Undo") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                .keyboardShortcut("z", modifiers: .command)
            Button("Redo") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            Divider()
            Button("Cut") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                .keyboardShortcut("x", modifiers: .command)
            Button("Copy") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                .keyboardShortcut("c", modifiers: .command)
            Button("Paste") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                .keyboardShortcut("v", modifiers: .command)
            Button("Select All") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                .keyboardShortcut("a", modifiers: .command)
        }

        // Capture Menu (First Responder actions - these forward through the responder chain)
        Group {
            Button("Play") { NSApp.sendAction(#selector(ECVCaptureController.play(_:)), to: nil, from: nil) }
                .keyboardShortcut(" ", modifiers: [])
            Button("Pause") { NSApp.sendAction(#selector(ECVCaptureController.pause(_:)), to: nil, from: nil) }
            Divider()
            Button("Configure Device...") { ECVSwiftConfigController.sharedSwiftConfigController()?.showConfig(nil) }
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}
