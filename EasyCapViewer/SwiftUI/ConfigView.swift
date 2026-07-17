import SwiftUI

struct ConfigView: View {
    @Bindable var viewModel: ConfigViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Video Section
            Text("Video")
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            PickerRow(label: "Format:", selection: $viewModel.selectedFormatIndex) {
                ForEach(Array(viewModel.formatMenuItems.enumerated()), id: \.offset) { index, item in
                    Text(item.title).tag(index)
                }
            }
            .onChange(of: viewModel.selectedFormatIndex) { _, _ in viewModel.changeFormat() }

            PickerRow(label: "Deinterlace:", selection: $viewModel.selectedDeinterlaceTag) {
                ForEach(viewModel.deinterlaceOptions, id: \.tag) { option in
                    if option.isHeader {
                        Text(option.title).tag(option.tag).disabled(true)
                    } else {
                        Text(option.title).tag(option.tag)
                    }
                }
            }
            .onChange(of: viewModel.selectedDeinterlaceTag) { _, _ in viewModel.changeDeinterlace() }

            PickerRow(label: "Source:", selection: $viewModel.selectedSourceIndex) {
                ForEach(Array(viewModel.sources.enumerated()), id: \.offset) { index, source in
                    Text(source.localizedName() ?? "Unknown").tag(index)
                }
            }
            .onChange(of: viewModel.selectedSourceIndex) { _, _ in viewModel.changeSource() }

            SliderRow(label: "Brightness:", value: $viewModel.brightness, enabled: viewModel.brightnessEnabled)
                .onChange(of: viewModel.brightness) { _, _ in viewModel.changeBrightness() }

            SliderRow(label: "Contrast:", value: $viewModel.contrast, enabled: viewModel.contrastEnabled)
                .onChange(of: viewModel.contrast) { _, _ in viewModel.changeContrast() }

            SliderRow(label: "Saturation:", value: $viewModel.saturation, enabled: viewModel.saturationEnabled)
                .onChange(of: viewModel.saturation) { _, _ in viewModel.changeSaturation() }

            SliderRow(label: "Tint:", value: $viewModel.tint, enabled: viewModel.tintEnabled)
                .onChange(of: viewModel.tint) { _, _ in viewModel.changeTint() }

            Divider()
                .padding(.vertical, 10)

            // MARK: - Audio Section
            Text("Audio")
                .font(.system(size: 11, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)

            PickerRow(label: "Volume:", selection: Binding(
                get: { 0 },
                set: { _ in }
            )) {
                Text("Hidden").tag(0)
            }
            .opacity(0)
            .frame(height: 0)

            HStack {
                Text("Volume:")
                    .font(.system(size: 11))
                    .frame(width: 80, alignment: .trailing)
                Slider(value: $viewModel.volume, in: 0...1)
                    .disabled(!viewModel.volumeEnabled)
                    .controlSize(.small)
                    .onChange(of: viewModel.volume) { _, _ in viewModel.changeVolume() }
            }

            PickerRow(label: "Source:", selection: $viewModel.selectedAudioIndex) {
                ForEach(Array(viewModel.audioInputs.enumerated()), id: \.offset) { index, item in
                    Text(item.name).tag(index)
                }
            }
            .onChange(of: viewModel.selectedAudioIndex) { _, _ in viewModel.changeAudioInput() }

            Toggle("Upconvert from mono", isOn: $viewModel.upconvertsFromMono)
                .font(.system(size: 11))
                .controlSize(.small)
                .disabled(!viewModel.upconvertEnabled)
                .onChange(of: viewModel.upconvertsFromMono) { _, _ in viewModel.changeUpconvertsFromMono() }
                .padding(.leading, 83)

            Divider()
                .padding(.vertical, 10)

            // MARK: - General
            Toggle("Auto-play when device connects", isOn: $viewModel.autoPlay)
                .font(.system(size: 11))
                .controlSize(.small)
                .padding(.leading, 8)
        }
        .padding(16)
        .frame(width: 290)
    }
}

// MARK: - Reusable Row Components

private struct PickerRow<Content: View>: View {
    let label: String
    @Binding var selection: Int
    @ViewBuilder let content: Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 80, alignment: .trailing)
            Picker("", selection: $selection) {
                content
            }
            .controlSize(.small)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 4)
    }
}

private struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let enabled: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 80, alignment: .trailing)
            Slider(value: $value, in: 0...1)
                .disabled(!enabled)
                .controlSize(.small)
        }
        .padding(.bottom, 4)
    }
}
