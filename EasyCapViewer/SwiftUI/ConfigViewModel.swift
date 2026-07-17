import SwiftUI
import Observation
import Combine

@Observable
final class ConfigViewModel {
    private var session: ECVCaptureSession?
    private var cancellables = Set<AnyCancellable>()

    var selectedSourceIndex: Int = 0
    var sources: [ECVVideoSource] = []

    var selectedFormatIndex: Int = 0
    var formatMenuItems: [(title: String, representedObject: ECVVideoFormat)] = []

    var selectedDeinterlaceTag: Int = 5 // ECVLineDoubleHQ
    let deinterlaceOptions: [(title: String, tag: Int, isHeader: Bool)] = [
        (title: "Full Resolution", tag: -1, isHeader: true),
        (title: "Line Double", tag: 5, isHeader: false),
        (title: "Weave", tag: 0, isHeader: false),
        (title: "Alternate (LQ)", tag: 2, isHeader: false),
        (title: "Half Resolution", tag: -2, isHeader: true),
        (title: "Drop", tag: 6, isHeader: false),
        (title: "Line Double (LQ)", tag: 1, isHeader: false),
        (title: "Blur", tag: 3, isHeader: false),
    ]

    var brightness: Double = 0.5
    var contrast: Double = 0.5
    var saturation: Double = 0.5
    var tint: Double = 0.5

    var brightnessEnabled: Bool = false
    var contrastEnabled: Bool = false
    var saturationEnabled: Bool = false
    var tintEnabled: Bool = false

    var volume: Double = 0.5
    var volumeEnabled: Bool = false

    var selectedAudioIndex: Int = 0
    var audioInputs: [(name: String, input: ECVAudioInput?)] = []

    var upconvertsFromMono: Bool = false
    var upconvertEnabled: Bool = false

    var autoPlay: Bool {
        didSet {
            UserDefaults.standard.set(autoPlay, forKey: "ECVAutoPlay")
        }
    }

    init() {
        self.autoPlay = UserDefaults.standard.bool(forKey: "ECVAutoPlay")
    }

    func setSession(_ session: ECVCaptureSession?) {
        cancellables.removeAll()
        self.session = session

        guard let device = session?.videoDevice() else { return }

        refreshSources(device: device)
        refreshFormats(device: device)
        refreshDeinterlace(device: device)
        refreshVideoControls(device: device)
        refreshAudio(session: session)

        NotificationCenter.default
            .publisher(for: Notification.Name.ECVAudioHardwareDevicesDidChange)
            .sink { [weak self] _ in self?.refreshAudio(session: session) }
            .store(in: &cancellables)
    }

    // MARK: - Refresh

    private func refreshSources(device: ECVCaptureDevice) {
        sources = device.supportedVideoSources() as? [ECVVideoSource] ?? []
        if let current = device.videoSource(), let idx = sources.firstIndex(of: current) {
            selectedSourceIndex = idx
        }
    }

    private func refreshFormats(device: ECVCaptureDevice) {
        let formats = device.supportedVideoFormats() as? Set<ECVVideoFormat> ?? []
        let sorted = formats.sorted { $0.compare($1) == .orderedAscending }
        formatMenuItems = sorted.map { (localizedName: $0.localizedName() ?? "Unknown", representedObject: $0) }
        if let current = device.videoFormat(), let idx = sorted.firstIndex(of: current) {
            selectedFormatIndex = idx
        }
    }

    private func refreshDeinterlace(device: ECVCaptureDevice) {
        selectedDeinterlaceTag = device.deinterlacingMode()?.deinterlacingModeType() ?? 5
    }

    private func refreshVideoControls(device: ECVCaptureDevice) {
        brightnessEnabled = device.responds(to: #selector(ECVCaptureDevice.brightness))
        contrastEnabled = device.responds(to: #selector(ECVCaptureDevice.contrast))
        saturationEnabled = device.responds(to: #selector(ECVCaptureDevice.saturation))
        tintEnabled = device.responds(to: #selector(ECVCaptureDevice.hue))

        if brightnessEnabled { brightness = device.brightness() }
        if contrastEnabled { contrast = device.contrast() }
        if saturationEnabled { saturation = device.saturation() }
        if tintEnabled { tint = device.hue() }
    }

    private func refreshAudio(session: ECVCaptureSession?) {
        guard let session else { return }
        let preferred = session.videoDevice()?.builtInAudioInput()

        var items: [(String, ECVAudioInput?)] = [("No Input", nil)]
        if let preferred {
            items.append((preferred.name ?? "Built-in", preferred))
        }
        for input in ECVAudioInput.allDevices() as? [ECVAudioInput] ?? [] {
            if input == preferred { continue }
            items.append((input.name ?? "Unknown", input))
        }
        audioInputs = items

        let currentAudio = session.audioDevice()
        if let currentAudio, let idx = items.firstIndex(where: { $0.1 == currentAudio }) {
            selectedAudioIndex = idx
        } else {
            selectedAudioIndex = 0
        }

        if let target = session.audioTarget() {
            volumeEnabled = true
            volume = target.isMuted() ? 0 : target.volume()
            upconvertEnabled = true
            upconvertsFromMono = target.upconvertsFromMono()
        } else {
            volumeEnabled = false
            upconvertEnabled = false
        }
    }

    // MARK: - Actions

    func changeSource() {
        guard selectedSourceIndex < sources.count else { return }
        session?.videoDevice()?.setVideoSource(sources[selectedSourceIndex])
    }

    func changeFormat() {
        guard selectedFormatIndex < formatMenuItems.count else { return }
        session?.videoDevice()?.setVideoFormat(formatMenuItems[selectedFormatIndex].representedObject)
    }

    func changeDeinterlace() {
        guard let modeClass = ECVDeinterlacingMode.deinterlacingMode(withType: selectedDeinterlaceTag) else { return }
        session?.videoDevice()?.setDeinterlacingMode(modeClass)
    }

    func changeBrightness() {
        snapSlider(&brightness)
        session?.videoDevice()?.setBrightness(CGFloat(brightness))
    }

    func changeContrast() {
        snapSlider(&contrast)
        session?.videoDevice()?.setContrast(CGFloat(contrast))
    }

    func changeSaturation() {
        snapSlider(&saturation)
        session?.videoDevice()?.setSaturation(CGFloat(saturation))
    }

    func changeTint() {
        snapSlider(&tint)
        session?.videoDevice()?.setHue(CGFloat(tint))
    }

    func changeVolume() {
        let target = session?.audioTarget()
        target?.setVolume(CGFloat(volume))
        target?.setMuted(false)
    }

    func changeAudioInput() {
        guard selectedAudioIndex < audioInputs.count else { return }
        session?.setAudioDevice(audioInputs[selectedAudioIndex].input)
    }

    func changeUpconvertsFromMono() {
        session?.audioTarget()?.setUpconvertsFromMono(upconvertsFromMono)
    }

    private func snapSlider(_ value: inout Double) {
        if abs(value - 0.5) < 0.03 { value = 0.5 }
    }
}
