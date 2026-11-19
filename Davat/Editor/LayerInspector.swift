import DavatKit
import SwiftUI

struct LayerInspector: View {
    let model: EditorModel

    var body: some View {
        if let layer = model.selected {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    actions(layer.id)
                    switch layer.kind {
                    case .text: TextControls(model: model)
                    case .shape: ShapeControls(model: model)
                    case .emoji:
                        TextField("emoji", text: model.emojiBinding()).font(.system(size: 40)).multilineTextAlignment(.center)
                    case .image: EmptyView()
                    }
                    Group {
                        LabeledSlider(label: "size", value: model.layerBinding(\.scale), range: EditorModel.scaleRange)
                        LabeledSlider(label: "rotate", value: model.layerBinding(\.rotation), range: -180...180)
                        LabeledSlider(label: "opacity", value: model.layerBinding(\.opacity), range: 0.05...1)
                    }
                }
                .padding(20)
            }
        }
    }

    private func actions(_ id: UUID) -> some View {
        HStack {
            Button("Forward", systemImage: "square.2.layers.3d.top.filled") { model.bringForward(id) }
            Button("Backward", systemImage: "square.2.layers.3d.bottom.filled") { model.sendBackward(id) }
            Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(id) }
            Spacer()
            Button("Delete", systemImage: "trash", role: .destructive) { model.delete(id) }
        }
        .labelStyle(.iconOnly).buttonStyle(.glass).font(.title3)
    }
}

private struct TextControls: View {
    let model: EditorModel
    private static let fills: [(String, [RGBA])] = [
        ("chrome", [.hex(0xFFFFFF), .hex(0xB9B9CC), .hex(0xF7F7FF), .hex(0x6E6E86), .hex(0xFFFFFF)]),
        ("gold", [.hex(0xFFF4C2), .hex(0xD4AF37), .hex(0xF9E79F), .hex(0xB8860B)]),
        ("sunset", [.hex(0xFFD86F), .hex(0xFC6262)]),
        ("candy", [.hex(0xFF9CE6), .hex(0x8EC5FC)]),
        ("toxic", [.hex(0xD4FC79), .hex(0x00F0FF)]),
    ]

    var body: some View {
        if let t = model.selectedText { controls(t) }
    }

    private func controls(_ t: TextLayer) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("text", text: model.textBinding(\.text), axis: .vertical)
                .padding(12).glassEffect(in: .rect(cornerRadius: 14))
            FontPicker(fontName: model.textBinding(\.fontName))
            LabeledSlider(label: "font size", value: model.textBinding(\.size), range: 10...220)
            if t.fontName == "system" {
                LabeledSlider(label: "weight", value: model.textBinding(\.weight), range: 0...1, step: 0.125)
            }
            LabeledSlider(label: "spacing", value: model.textBinding(\.letterSpacing), range: -4...30)
            LabeledSlider(label: "curve", value: model.textBinding(\.curve), range: -1...1)
            Picker("align", selection: model.textBinding(\.alignment)) {
                Image(systemName: "text.alignleft").tag(TextLayer.Alignment.leading)
                Image(systemName: "text.aligncenter").tag(TextLayer.Alignment.center)
                Image(systemName: "text.alignright").tag(TextLayer.Alignment.trailing)
            }
            .pickerStyle(.segmented)

            Swatches(title: "color", color: model.textBinding(\.color))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    chip("solid", on: t.gradient == nil) { model.editText { $0.gradient = nil } }
                    ForEach(Self.fills, id: \.0) { name, stops in
                        chip(name, on: t.gradient == stops) { model.editText { $0.gradient = stops } }
                    }
                }
            }
            if let g = t.gradient {
                HStack {
                    Text("fill").font(.subheadline).foregroundStyle(.secondary)
                    ForEach(g.indices, id: \.self) { i in
                        ColorPicker("", selection: Binding(get: { model.selectedText?.gradient?[safe: i] ?? g[i] }, set: { c in
                            model.editText { if $0.gradient?.indices.contains(i) == true { $0.gradient?[i] = c } }
                        }).color).labelsHidden()
                    }
                }
            }

            Toggle("outline", isOn: Binding(get: { t.outline != nil }, set: { on in
                model.editText { $0.outline = on ? .hex(0x000000) : nil; $0.outlineWidth = on ? 3 : 0 }
            }))
            if t.outline != nil {
                Swatches(title: "outline color", color: model.optionalBinding(text: \.outline))
                LabeledSlider(label: "outline width", value: model.textBinding(\.outlineWidth), range: 0.5...12)
            }
            Toggle("shadow", isOn: model.textBinding(\.shadow))
        }
    }

    private func chip(_ name: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(name, action: action).buttonStyle(.glass).tint(on ? .accentColor : nil)
    }
}

private struct ShapeControls: View {
    let model: EditorModel

    var body: some View {
        if let s = model.selectedShape {
            VStack(alignment: .leading, spacing: 18) {
                Picker("shape", selection: model.shapeBinding(\.kind)) {
                    Image(systemName: "circle.fill").tag(ShapeLayer.Kind.circle)
                    Image(systemName: "square.fill").tag(ShapeLayer.Kind.rect)
                    Image(systemName: "star.fill").tag(ShapeLayer.Kind.star)
                    Image(systemName: "heart.fill").tag(ShapeLayer.Kind.heart)
                    Image(systemName: "cloud.fill").tag(ShapeLayer.Kind.blob)
                }
                .pickerStyle(.segmented)
                Swatches(title: "fill", color: model.shapeBinding(\.fill))
                Toggle("border", isOn: Binding(get: { s.stroke != nil }, set: { on in
                    model.editShape { $0.stroke = on ? .hex(0xFFFFFF) : nil }
                }))
                if s.stroke != nil { Swatches(title: "border color", color: model.optionalBinding(shape: \.stroke)) }
                LabeledSlider(label: "width", value: model.shapeBinding(\.size.width), range: 1...700)
                LabeledSlider(label: "height", value: model.shapeBinding(\.size.height), range: 1...1200)
            }
        }
    }
}

struct LabeledSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    let label: String
    @Binding var value: V
    let range: ClosedRange<V>
    var step: V.Stride?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            if let step { Slider(value: $value, in: range, step: step) } else { Slider(value: $value, in: range) }
        }
    }
}

/// Quick palette plus the full system color picker.
struct Swatches: View {
    let title: String
    @Binding var color: RGBA
    static let palette: [RGBA] = [0xFFFFFF, 0x111111, 0xFF4D6D, 0xFFB3C6, 0xFCA311, 0xFFE600, 0x2E7D32, 0x00B4D8,
                                  0x3A86FF, 0x8338EC, 0xB5657B, 0xD4AF37, 0xF3EBDD, 0x0B2545].map { RGBA.hex($0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ColorPicker(title, selection: $color.color).labelsHidden()
                    ForEach(Self.palette, id: \.self) { c in
                        Circle().fill(c.color).frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(.secondary.opacity(0.4)))
                            .overlay(Circle().strokeBorder(.primary, lineWidth: 2).padding(-4).opacity(c == color ? 1 : 0))
                            .onTapGesture { color = c }
                            .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(4)
            }
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

extension Binding where Value == RGBA {
    var color: Binding<Color> { Binding<Color>(get: { wrappedValue.color }, set: { wrappedValue = RGBA($0) }) }
}

// Bindings into the selected layer. Each captures a fallback so a binding read during a dismiss
// transition (after the layer is gone) doesn't crash.
extension EditorModel {
    var selectedText: TextLayer? { if case .text(let t) = selected?.kind { t } else { nil } }
    var selectedShape: ShapeLayer? { if case .shape(let s) = selected?.kind { s } else { nil } }

    func editText(_ f: @escaping (inout TextLayer) -> Void) {
        editSelected { l in if case .text(var t) = l.kind { f(&t); l.kind = .text(t) } }
    }
    func editShape(_ f: @escaping (inout ShapeLayer) -> Void) {
        editSelected { l in if case .shape(var s) = l.kind { f(&s); l.kind = .shape(s) } }
    }

    func layerBinding<V>(_ kp: WritableKeyPath<Layer, V>) -> Binding<V> {
        let fallback = selected![keyPath: kp]
        return Binding(get: { self.selected?[keyPath: kp] ?? fallback }, set: { v in self.editSelected { $0[keyPath: kp] = v } })
    }
    func textBinding<V>(_ kp: WritableKeyPath<TextLayer, V>) -> Binding<V> {
        let fallback = selectedText![keyPath: kp]
        return Binding(get: { self.selectedText?[keyPath: kp] ?? fallback }, set: { v in self.editText { $0[keyPath: kp] = v } })
    }
    func shapeBinding<V>(_ kp: WritableKeyPath<ShapeLayer, V>) -> Binding<V> {
        let fallback = selectedShape![keyPath: kp]
        return Binding(get: { self.selectedShape?[keyPath: kp] ?? fallback }, set: { v in self.editShape { $0[keyPath: kp] = v } })
    }
    /// For optional colors (outline, border): only shown while set, writes ignored once cleared.
    func optionalBinding(text kp: WritableKeyPath<TextLayer, RGBA?>) -> Binding<RGBA> {
        Binding(get: { self.selectedText?[keyPath: kp] ?? .hex(0) },
                set: { v in self.editText { if $0[keyPath: kp] != nil { $0[keyPath: kp] = v } } })
    }
    func optionalBinding(shape kp: WritableKeyPath<ShapeLayer, RGBA?>) -> Binding<RGBA> {
        Binding(get: { self.selectedShape?[keyPath: kp] ?? .hex(0) },
                set: { v in self.editShape { if $0[keyPath: kp] != nil { $0[keyPath: kp] = v } } })
    }
    func emojiBinding() -> Binding<String> {
        Binding(get: { if case .emoji(let e) = self.selected?.kind { e } else { "" } },
                set: { v in if !v.isEmpty { self.editSelected { $0.kind = .emoji(String(v.suffix(1))) } } })
    }
}
