import Cocoa
import SwiftUI

@objc class MainWindowController: NSWindowController, NSWindowDelegate, ECVVideoViewDelegate {

    // MARK: - Properties

    private var splitViewController: NSSplitViewController!
    private var sidebarItem: NSSplitViewItem!
    private var contentItem: NSSplitViewItem!
    private var inspectorItem: NSSplitViewItem!

    private var configViewModel: ConfigViewModel!
    private var errorLogModel: ErrorLogModel!

    private var videoView: ECVVideoView?
    private var currentContentType: ContentType = .welcome

    private var captureSession: ECVCaptureSession?
    private var playButtonCell: ECVPlayButtonCell?
    private var movieRecorder: ECVMovieRecorder?

    private var sleepAssertionID: IOPMAssertionID = 0

    // MARK: - Content Types

    private enum ContentType {
        case welcome
        case video
    }

    // MARK: - Initialization

    init() {
        let window = MPLWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.title = "EasyCapViewer"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 300)
        window.setFrameAutosaveName("ECVCaptureWindowFrame")
        window.identifier = NSUserInterfaceItemIdentifier("ECVCaptureWindow")
        window.collectionBehavior = [.fullScreenPrimary]

        super.init(window: window)

        window.delegate = self
        setupSplitView()
        setupInitialState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupSplitView() {
        splitViewController = NSSplitViewController()
        splitViewController.splitView.isVertical = true
        splitViewController.splitView.dividerStyle = .thin

        // Left sidebar: Settings
        configViewModel = ConfigViewModel()
        let configView = ConfigView(viewModel: configViewModel)
        let configHostingView = NSHostingView(rootView: configView)
        let configViewController = NSViewController()
        configViewController.view = configHostingView

        sidebarItem = NSSplitViewItem(sidebarWithViewController: configViewController)
        sidebarItem.minimumThickness = 290
        sidebarItem.maximumThickness = 350
        sidebarItem.holdingPriority = .defaultHigh + 1
        sidebarItem.canCollapse = true
        sidebarItem.isCollapsed = true

        // Center: Content (welcome or video)
        let centerViewController = NSViewController()
        centerViewController.view = NSView()
        contentItem = NSSplitViewItem(contentListWithViewController: centerViewController)

        // Right sidebar: Error log
        errorLogModel = ErrorLogModel()
        let errorLogView = ErrorLogView(model: errorLogModel)
        let errorLogHostingView = NSHostingView(rootView: errorLogView)
        let errorLogViewController = NSViewController()
        errorLogViewController.view = errorLogHostingView

        inspectorItem = NSSplitViewItem(inspectorWithViewController: errorLogViewController)
        inspectorItem.minimumThickness = 350
        inspectorItem.maximumThickness = 450
        inspectorItem.canCollapse = true
        inspectorItem.isCollapsed = true

        splitViewController.addSplitViewItem(sidebarItem)
        splitViewController.addSplitViewItem(contentItem)
        splitViewController.addSplitViewItem(inspectorItem)

        window?.contentViewController = splitViewController
    }

    private func setupInitialState() {
        showWelcomeView()
    }

    // MARK: - Sidebar Toggling

    @objc func toggleSettingsSidebar() {
        sidebarItem.animator().isCollapsed = !sidebarItem.isCollapsed
    }

    @objc func toggleErrorLogSidebar() {
        inspectorItem.animator().isCollapsed = !inspectorItem.isCollapsed
    }

    @IBAction func configureDevice(_ sender: Any?) {
        toggleSettingsSidebar()
    }

    @IBAction func showErrorLog(_ sender: Any?) {
        toggleErrorLogSidebar()
    }

    // MARK: - Content Switching

    private func showWelcomeView() {
        let centerView = contentItem.viewController.view

        centerView.subviews.forEach { $0.removeFromSuperview() }

        let hostingView = NSHostingView(rootView: WelcomeView())
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        centerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: centerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: centerView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: centerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: centerView.trailingAnchor)
        ])

        currentContentType = .welcome
    }

    private func showVideoView() {
        let centerView = contentItem.viewController.view

        centerView.subviews.forEach { $0.removeFromSuperview() }

        let videoView = createVideoView()
        self.videoView = videoView
        videoView.translatesAutoresizingMaskIntoConstraints = false
        centerView.addSubview(videoView)

        NSLayoutConstraint.activate([
            videoView.topAnchor.constraint(equalTo: centerView.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: centerView.bottomAnchor),
            videoView.leadingAnchor.constraint(equalTo: centerView.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: centerView.trailingAnchor)
        ])

        currentContentType = .video
    }

    private func createVideoView() -> ECVVideoView {
        let videoView = ECVVideoView(frame: .zero)
        videoView.ecvDelegate = self

        let renderer = ECVMetalRenderer(view: videoView)
        NSLog("[ECV-TRACE] createVideoView: renderer=\(renderer)")
        videoView.setValue(renderer, forKey: "_renderer")

        playButtonCell = ECVPlayButtonCell()
        playButtonCell?.image = ECVPlayButtonCell.playButtonImage()
        playButtonCell?.target = self
        playButtonCell?.action = #selector(togglePlaying(_:))
        videoView.cell = playButtonCell

        let defaults = UserDefaults.standard
        videoView.vsync = defaults.bool(forKey: "ECVVsync")
        videoView.showDroppedFrames = defaults.bool(forKey: "ECVShowDroppedFrames")

        let cropString = defaults.string(forKey: "ECVCropRectKey") ?? NSStringFromRect(.zero)
        videoView.cropRect = NSRectFromString(cropString)

        return videoView
    }

    // MARK: - Device Connection

    @objc func connectDevice(_ device: ECVCaptureDevice) {
        NSLog("[ECV-TRACE] connectDevice: name=\(device.name)")
        let session = ECVCaptureSession()
        session.setVideoDevice(device)
        session.delegate = self
        self.captureSession = session

        showVideoView()

        guard let window = self.window else { return }

        let videoStorage = device.videoStorage()
        NSLog("[ECV-TRACE] connectDevice: videoStorage=\(videoStorage)")
        if let videoStorage = videoStorage {
            videoView?.setVideoStorage(videoStorage)
            NSLog("[ECV-TRACE] connectDevice: setVideoStorage done, videoView=\(videoView as Any)")
            if let videoFormat = videoStorage.videoFormat() {
                let videoSize = videoFormat.displaySize(withAspectRatio: NSSize(width: 4, height: 3))
                let contentSize = NSSize(width: videoSize.width, height: videoSize.height)

                var newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
                newFrame.origin.y = window.frame.maxY - newFrame.size.height
                newFrame.origin.x = window.frame.midX - newFrame.size.width / 2

                window.setFrame(newFrame, display: true, animate: true)
            }
        } else {
            NSLog("[ECV-TRACE] connectDevice: WARNING - videoStorage is NIL")
        }

        configViewModel.setSession(session)

        if UserDefaults.standard.bool(forKey: "ECVAutoPlay") {
            NSLog("[ECV-TRACE] connectDevice: autoPlay=true, starting playback")
            session.setPausedFromUI(false)
        } else {
            NSLog("[ECV-TRACE] connectDevice: autoPlay=false, NOT starting playback")
        }
    }

    @objc func disconnectDevice() {
        captureSession?.setPausedFromUI(true)
        captureSession = nil
        videoView?.stopDrawing()
        videoView = nil
        playButtonCell = nil

        showWelcomeView()

        guard let window = self.window else { return }
        let welcomeSize = NSSize(width: 600, height: 400)
        var newFrame = window.frameRect(forContentRect: NSRect(origin: .zero, size: welcomeSize))
        newFrame.origin.y = window.frame.maxY - newFrame.size.height
        newFrame.origin.x = window.frame.midX - newFrame.size.width / 2

        window.setFrame(newFrame, display: true, animate: true)

        configViewModel.setSession(nil)
    }

    // MARK: - Playback Control

    @IBAction func play(_ sender: Any?) {
        captureSession?.setPausedFromUI(false)
    }

    @IBAction func pause(_ sender: Any?) {
        captureSession?.setPausedFromUI(true)
    }

    @IBAction func togglePlaying(_ sender: Any?) {
        guard let session = captureSession else { return }
        session.setPausedFromUI(!session.isPausedFromUI())
    }

    // MARK: - Recording

    @IBAction func startRecording(_ sender: Any?) {
        guard let session = captureSession,
              let device = session.videoDevice(),
              let videoStorage = device.videoStorage() else { return }

        guard let videoFormat = videoStorage.videoFormat() else { return }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.movie]
        savePanel.canCreateDirectories = true
        savePanel.canSelectHiddenExtension = true
        savePanel.prompt = NSLocalizedString("Record", comment: "")
        savePanel.nameFieldStringValue = NSLocalizedString("untitled", comment: "")

        let returnCode = savePanel.runModal()
        guard returnCode == .OK, let url = savePanel.url else { return }

        let options = ECVMovieRecordingOptions()
        options.url = url
        options.videoStorage = videoStorage
        options.audioInput = session.audioDevice()
        options.videoCodec = 0
        options.videoQuality = 0.5
        if let videoView = videoView {
            let size = videoView.bounds.size
            options.outputSize = ECVIntegerSizeFromNSSize(size)
            options.cropRect = videoView.cropRect
        }
        options.upconvertsFromMono = session.audioTarget()?.upconvertsFromMono() ?? false
        options.frameRate = videoFormat.frameRate()

        do {
            let recorder = try ECVMovieRecorder(options: options)
            self.movieRecorder = recorder
            window?.isDocumentEdited = true
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @IBAction func stopRecording(_ sender: Any?) {
        movieRecorder?.stopRecording()
        movieRecorder = nil
        window?.isDocumentEdited = false
    }

    // MARK: - Full Screen

    @IBAction func toggleFullScreen(_ sender: Any?) {
        window?.toggleFullScreen(sender)
    }

    // MARK: - Aspect Ratio

    @IBAction func changeAspectRatio(_ sender: NSMenuItem) {
        let ratio: NSSize
        switch sender.tag {
        case 0: ratio = NSSize(width: 4, height: 3)
        case 1: ratio = NSSize(width: 16, height: 9)
        case 2: ratio = NSSize(width: 16, height: 10)
        case 3: ratio = NSSize(width: 1, height: 1)
        case 4: ratio = NSSize(width: 3, height: 2)
        default: return
        }

        videoView?.aspectRatio = ratio
        window?.contentAspectRatio = ratio

        guard let videoFormat = captureSession?.videoDevice()?.videoStorage()?.videoFormat() else { return }
        let displaySize = videoFormat.displaySize(withAspectRatio: ratio)
        var newFrame = window!.frameRect(forContentRect: NSRect(origin: .zero, size: displaySize))
        newFrame.origin.y = window!.frame.maxY - newFrame.size.height
        window?.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Scale

    @IBAction func changeScale(_ sender: NSMenuItem) {
        guard let videoFormat = captureSession?.videoDevice()?.videoStorage()?.videoFormat() else { return }
        let baseSize = videoFormat.displaySize(withAspectRatio: videoView?.aspectRatio ?? NSSize(width: 4, height: 3))
        let scale = pow(2.0, CGFloat(sender.tag))
        let newSize = NSSize(width: baseSize.width * scale, height: baseSize.height * scale)

        var newFrame = window!.frameRect(forContentRect: NSRect(origin: .zero, size: newSize))
        newFrame.origin.y = window!.frame.maxY - newFrame.size.height
        window?.setFrame(newFrame, display: true, animate: true)
    }

    // MARK: - Crop

    @IBAction func uncrop(_ sender: Any?) {
        videoView?.cropRect = ECVUncroppedRect
    }

    // MARK: - Display Options

    @IBAction func toggleFloatOnTop(_ sender: Any?) {
        window?.level = window?.level == .floating ? .normal : .floating
    }

    @IBAction func toggleVsync(_ sender: Any?) {
        guard let videoView = videoView else { return }
        videoView.vsync = !videoView.vsync
        UserDefaults.standard.set(videoView.vsync, forKey: "ECVVsync")
    }

    @IBAction func toggleShowDroppedFrames(_ sender: Any?) {
        guard let videoView = videoView else { return }
        videoView.showDroppedFrames = !videoView.showDroppedFrames
        UserDefaults.standard.set(videoView.showDroppedFrames, forKey: "ECVShowDroppedFrames")
    }

    // MARK: - ECVVideoViewDelegate

    func videoView(_ sender: ECVVideoView, handleKeyDown event: NSEvent) -> Bool {
        guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return false }
        let character = characters.unicodeScalars.first?.value ?? 0
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])

        switch character {
        case UInt32(UnicodeScalar(" ").value):
            togglePlaying(nil)
            return true
        default:
            break
        }

        if modifiers == .command {
            switch Int(character) {
            case NSUpArrowFunctionKey:
                captureSession?.audioTarget()?.setVolume((captureSession?.audioTarget()?.volume() ?? 0) + 0.05)
                return true
            case NSDownArrowFunctionKey:
                captureSession?.audioTarget()?.setVolume((captureSession?.audioTarget()?.volume() ?? 0) - 0.05)
                return true
            default:
                break
            }
        }

        if modifiers == [.command, .option] {
            switch Int(character) {
            case NSUpArrowFunctionKey, NSDownArrowFunctionKey:
                if let target = captureSession?.audioTarget() {
                    target.setMuted(!target.isMuted())
                }
                return true
            default:
                break
            }
        }

        return false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        stopRecording(nil)
        captureSession?.setPausedFromUI(true)
        NSApp.terminate(nil)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        if let session = captureSession {
            configViewModel.setSession(session)
        }
    }

    func windowDidResignMain(_ notification: Notification) {
    }

    // MARK: - Menu Validation

    @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return false }

        switch action {
        case #selector(toggleFullScreen(_:)):
            menuItem.title = window?.styleMask.contains(.fullScreen) == true ? NSLocalizedString("Exit Full Screen", comment: "") : NSLocalizedString("Enter Full Screen", comment: "")
            return true

        case #selector(togglePlaying(_:)):
            menuItem.title = captureSession?.isPaused() == false ? NSLocalizedString("Pause", comment: "") : NSLocalizedString("Play", comment: "")
            return true

        case #selector(startRecording(_:)):
            return captureSession != nil && movieRecorder == nil && captureSession?.isPaused() == false

        case #selector(stopRecording(_:)):
            return movieRecorder != nil

        default:
            return responds(to: action)
        }
    }
}

// MARK: - ECVCaptureSessionDelegate

extension MainWindowController: ECVCaptureSessionDelegate {
    func captureSessionDidStartPlaying(_ session: ECVCaptureSession) {
        NSLog("[ECV-TRACE] captureSessionDidStartPlaying: session=\(session)")
        let videoStorage = session.videoDevice()?.videoStorage()
        NSLog("[ECV-TRACE]   device.videoStorage=\(videoStorage as Any)")
        if let videoStorage = videoStorage {
            videoView?.setVideoStorage(videoStorage)
            NSLog("[ECV-TRACE]   setVideoStorage done")
        } else {
            NSLog("[ECV-TRACE]   WARNING: no videoStorage on device")
        }
        NSLog("[ECV-TRACE]   videoView=\(videoView as Any)")
        videoView?.startDrawing()

        if sleepAssertionID == 0 {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "EasyCapViewer is capturing video" as CFString,
                &sleepAssertionID
            )
        }
    }

    func captureSessionDidStopPlaying(_ session: ECVCaptureSession) {
        NSLog("[ECV-TRACE] captureSessionDidStopPlaying")
        videoView?.stopDrawing()
        stopRecording(nil)

        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }

    @objc(captureSession:didReceiveVideoFrame:)
    func captureSession(_ session: ECVCaptureSession, didReceive frame: ECVVideoFrame) {
        NSLog("[ECV-TRACE] didReceiveVideoFrame: frame=\(frame) videoView=\(videoView as Any)")
        videoView?.pushFrame(frame)
        if let recorder = movieRecorder {
            recorder.add(frame)
        }
    }

    func captureSession(_ session: ECVCaptureSession, didReceiveAudioBuffer bufferList: NSValue) {
        if let recorder = movieRecorder, let pointer = bufferList.pointerValue {
            let audioBufferList = pointer.assumingMemoryBound(to: AudioBufferList.self)
            recorder.add(audioBufferList)
        }
    }
}
