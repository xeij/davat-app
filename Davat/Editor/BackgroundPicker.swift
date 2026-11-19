import DavatKit
import PhotosUI
import SwiftUI

struct BackgroundPicker: View {
    let model: EditorModel
    let onPhoto: (Data) async -> Void
    enum Mode: String, CaseIterable { case color, gradient, pattern, photo }
    @State private var mode: Mode = .color
    @State private var photo: PhotosPickerItem?

    private static let gradients: [[RGBA]] = [
        [0x1A0533, 0x5B1A8C, 0xD62AD0], [0xFF5F6D, 0xFFC371], [0x00C9FF, 0x92FE9D], [0xFBC2EB, 0xA6C1EE],
        [0x0F2027, 0x2C5364], [0xF6D365, 0xFDA085], [0xD4FC79, 0x96E6A1], [0x6A9BD8, 0xFFFFFF],
        [0x000000, 0x434343], [0xFF9A9E, 0xFECFEF, 0xFFFFFF],
    ].map { $0.map { RGBA.hex($0) } }
    private static let patterns: [Background] = [
        .pattern(.flowers, .hex(0xFBEFF2), .hex(0xF4C6D3)), .pattern(.checker, .hex(0xFFE600), .hex(0xFF2BD6)),
        .pattern(.hearts, .hex(0xFFD6E0), .hex(0xFFB3C6)), .pattern(.dots, .hex(0xEEF6F3), .hex(0xCFE5DD)),
        .pattern(.stars, .hex(0x0A1F44), .hex(0x1C3A70)), .pattern(.grid, .hex(0x14213D), .hex(0x22396B)),
        .pattern(.waves, .hex(0x00B4D8), .hex(0x48CAE4)), .pattern(.stripes, .hex(0xFFF1E6), .hex(0xFFD6BA)),
        .pattern(.checker, .hex(0x111111), .hex(0xFFFFFF)), .pattern(.dots, .hex(0x111111), .hex(0xD4AF37)),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("background", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                switch mode {
                case .color: Swatches(title: "color", color: colorBinding)
                case .gradient: gradient
                case .pattern: pattern
                case .photo:
                    PhotosPicker(selection: $photo, matching: .images) {
                        Label("choose a photo", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent).controlSize(.large)
                }
            }
            .padding(20)
        }
        .onAppear {
            switch model.design.background {
            case .color: mode = .color
            case .gradient: mode = .gradient
            case .pattern: mode = .pattern
            case .image: mode = .photo
            }
        }
        .onChange(of: photo) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) { await onPhoto(data) }
                photo = nil
            }
        }
    }

    private func set(_ b: Background) { model.edit { $0.background = b } }

    private func preview(_ b: Background) -> some View {
        Button { set(b) } label: {
            CanvasView(design: Design(background: b), imageLoader: { _ in nil }, showsEffect: false)
                .frame(width: 56).clipShape(.rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary, lineWidth: model.design.background == b ? 2 : 0))
        }
    }

    private var colorBinding: Binding<RGBA> {
        Binding(get: { if case .color(let c) = model.design.background { c } else { .hex(0xFFFFFF) } },
                set: { set(.color($0)) })
    }

    @ViewBuilder private var gradient: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack { ForEach(Self.gradients, id: \.self) { preview(.gradient($0, angle: 180)) } }
        }
        if case .gradient(let stops, let angle) = model.design.background {
            HStack {
                Text("stops").font(.subheadline).foregroundStyle(.secondary)
                ForEach(stops.indices, id: \.self) { i in
                    ColorPicker("", selection: Binding<RGBA>(get: { stops[safe: i] ?? stops[0] }, set: { c in
                        var s = stops; s[i] = c; set(.gradient(s, angle: angle))
                    }).color).labelsHidden()
                }
                Button("Add stop", systemImage: "plus") { set(.gradient(stops + [stops.last!], angle: angle)) }
                    .labelStyle(.iconOnly).buttonStyle(.glass).disabled(stops.count >= 6)
                if stops.count > 2 {
                    Button("Remove stop", systemImage: "minus") { set(.gradient(Array(stops.dropLast()), angle: angle)) }
                        .labelStyle(.iconOnly).buttonStyle(.glass)
                }
            }
            LabeledSlider(label: "angle", value: Binding(get: { angle }, set: { set(.gradient(stops, angle: $0)) }), range: 0...360)
        }
    }

    @ViewBuilder private var pattern: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack { ForEach(Self.patterns, id: \.self) { preview($0) } }
        }
        if case .pattern(let kind, let bg, let fg) = model.design.background {
            Picker("pattern", selection: Binding(get: { kind }, set: { set(.pattern($0, bg, fg)) })) {
                ForEach(PatternKind.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.menu)
            Swatches(title: "base", color: Binding(get: { bg }, set: { set(.pattern(kind, $0, fg)) }))
            Swatches(title: "pattern", color: Binding(get: { fg }, set: { set(.pattern(kind, bg, $0)) }))
        }
    }
}

struct EffectPicker: View {
    let model: EditorModel
    private static let symbols: [Effect: String] = [
        .none: "circle.slash", .confetti: "party.popper", .snow: "snowflake", .sparkle: "sparkles",
        .hearts: "heart.fill", .bubbles: "bubbles.and.sparkles", .petals: "leaf",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                ForEach(Effect.allCases, id: \.self) { e in
                    Button { model.edit { $0.effect = e } } label: {
                        VStack(spacing: 4) {
                            Image(systemName: Self.symbols[e] ?? "sparkles").font(.title2)
                            Text(e.rawValue).font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.glass)
                    .tint(model.design.effect == e ? .accentColor : nil)
                }
            }
            Toggle("open like an envelope", isOn: Binding(get: { model.design.envelope }, set: { v in model.edit { $0.envelope = v } }))
        }
        .padding(20)
    }
}
