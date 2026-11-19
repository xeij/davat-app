import DavatKit
import ImagePlayground
import PhotosUI
import SwiftUI

struct EditorView: View {
    let onDone: (Design) -> Void
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var model: EditorModel

    enum Panel: String, Identifiable { case background, sticker, effect, layer; var id: String { rawValue } }
    @State private var panel: Panel?
    @State private var editingText = false
    @FocusState private var textFocused: Bool
    @State private var canvasSize = CGSize(width: 1, height: 1)
    @State private var confirmCancel = false
    @State private var error: String?

    // Gestures act on the selected layer; starts are captured on the first change.
    @State private var dragStart: CGPoint?
    @State private var scaleStart: Double?
    @State private var rotationStart: Double?
    @State private var snapX = false
    @State private var snapY = false
    @State private var snapTick = 0

    // Photos and Image Playground
    @State private var pickingPhoto = false
    @State private var photo: PhotosPickerItem?
    @State private var playground = false
    @State private var aiImage: Data?

    init(design: Design, onDone: @escaping (Design) -> Void) {
        self.onDone = onDone
        _model = State(initialValue: EditorModel(design: design))
    }

    var body: some View {
        VStack(spacing: 12) {
            topBar
            canvas
            Spacer(minLength: 0)
        }
        .background(Color(white: 0.08).ignoresSafeArea())
        .overlay(alignment: .bottom) { toolbar }
        .overlay { if editingText { textEditor } }
        .sheet(item: $panel) { p in
            Group {
                switch p {
                case .background: BackgroundPicker(model: model) { await place($0, asBackground: true) }
                case .sticker: StickerPicker { model.add(.emoji($0)) }
                case .effect: EffectPicker(model: model)
                case .layer: LayerInspector(model: model)
                }
            }
            .presentationDetents(p == .effect ? [.height(330)] : [.height(320), .medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .onChange(of: model.selection) { _, sel in
            if sel != nil { panel = .layer } else if panel == .layer { panel = nil }
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $photo, matching: .images)
        .onChange(of: photo) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) { await place(data, asBackground: false) }
                photo = nil
            }
        }
        .imagePlaygroundSheet(isPresented: $playground, concept: "") { url in aiImage = try? Data(contentsOf: url) }
        .confirmationDialog("use it as", isPresented: Binding(get: { aiImage != nil }, set: { if !$0 { aiImage = nil } })) {
            Button("background") { let d = aiImage; Task { if let d { await place(d, asBackground: true) } } }
            Button("sticker") { let d = aiImage; Task { if let d { await place(d, asBackground: false) } } }
        }
        .confirmationDialog("throw away your changes?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Discard", role: .destructive) { dismiss() }
        }
        .alert("that didn't work", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
        } message: { Text(error ?? "") }
        .sensoryFeedback(.impact(weight: .light), trigger: snapTick)
        .preferredColorScheme(.dark)
        #if DEBUG
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-demoEditor") {
                model.selection = model.design.layers.first { if case .text = $0.kind { true } else { false } }?.id
            }
        }
        #endif
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { model.canUndo ? (confirmCancel = true) : dismiss() }.buttonStyle(.glass)
            Spacer()
            Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }.disabled(!model.canUndo)
            Button("Redo", systemImage: "arrow.uturn.forward") { model.redo() }.disabled(!model.canRedo)
            Spacer()
            Button("Done") { model.selection = nil; onDone(model.design) }.buttonStyle(.glassProminent)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .padding(.horizontal, 16)
    }

    private var canvas: some View {
        let images = session.images
        return CanvasView(design: model.design, imageLoader: images.image, selection: $model.selection)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
            .overlay { guides }
            .clipShape(.rect(cornerRadius: 22))
            .simultaneousGesture(transform)
            .simultaneousGesture(TapGesture(count: 2).onEnded {
                if model.selectedText != nil { editingText = true; textFocused = true }
            })
            .padding(.horizontal, 8)
    }

    private var guides: some View {
        ZStack {
            Rectangle().fill(.yellow).frame(width: 1).opacity(snapX ? 1 : 0)
            Rectangle().fill(.yellow).frame(height: 1).opacity(snapY ? 1 : 0)
        }
        .allowsHitTesting(false)
    }

    private var transform: some Gesture {
        let drag = DragGesture(minimumDistance: 4)
            .onChanged { v in
                guard let l = model.selected else { return }
                let start = dragStart ?? CGPoint(x: l.x, y: l.y)
                dragStart = start
                var x = min(max(start.x + v.translation.width / canvasSize.width, -0.2), 1.2)
                var y = min(max(start.y + v.translation.height / canvasSize.height, -0.2), 1.2)
                let sx = abs(x - 0.5) < 0.012, sy = abs(y - 0.5) < 0.012
                if sx { x = 0.5 }
                if sy { y = 0.5 }
                if (sx && !snapX) || (sy && !snapY) { snapTick += 1 }
                snapX = sx; snapY = sy
                model.editSelected { $0.x = x; $0.y = y }
            }
            .onEnded { _ in dragStart = nil; snapX = false; snapY = false }
        let pinch = MagnifyGesture()
            .onChanged { v in
                guard let l = model.selected else { return }
                let start = scaleStart ?? l.scale
                scaleStart = start
                model.editSelected { $0.scale = min(max(start * v.magnification, 0.1), 12) }
            }
            .onEnded { _ in scaleStart = nil }
        let rotate = RotateGesture()
            .onChanged { v in
                guard let l = model.selected else { return }
                let start = rotationStart ?? l.rotation
                rotationStart = start
                var r = start + v.rotation.degrees
                let nearest = (r / 45).rounded() * 45
                if abs(r - nearest) < 3 { r = nearest }
                model.editSelected { $0.rotation = r }
            }
            .onEnded { _ in rotationStart = nil }
        return drag.simultaneously(with: pinch).simultaneously(with: rotate)
    }

    private var toolbar: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                tool("bg", "paintpalette") { panel = .background }
                tool("text", "textformat") {
                    model.add(.text(TextLayer(text: "your text", size: 44, weight: 0.3, color: .hex(0xFFFFFF), shadow: true)))
                    editingText = true; textFocused = true
                }
                tool("sticker", "face.smiling") { panel = .sticker }
                tool("photo", "photo") { pickingPhoto = true }
                Menu {
                    ForEach(ShapeLayer.Kind.allCases, id: \.self) { k in
                        Button(k.rawValue) {
                            model.add(.shape(ShapeLayer(kind: k, fill: .hex(0xFF4D6D), stroke: nil, size: CGSize(width: 140, height: 140))))
                        }
                    }
                } label: { toolLabel("shape", "star.square.on.square") }
                tool("effect", "sparkles") { panel = .effect }
                if ImagePlaygroundViewController.isAvailable { tool("ai", "apple.image.playground") { playground = true } }
            }
            .padding(6)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .padding(.bottom, 8)
        .opacity(editingText ? 0 : 1)
    }

    private func tool(_ name: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { toolLabel(name, symbol) }.buttonStyle(.plain)
    }

    private func toolLabel(_ name: String, _ symbol: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 19))
            Text(name).font(.system(size: 10))
        }
        .frame(width: 50, height: 48)
        .contentShape(Rectangle())
    }

    @ViewBuilder private var textEditor: some View {
        if let t = model.selectedText {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { editingText = false }
                TextField("", text: model.textBinding(\.text), axis: .vertical)
                    .font(t.fontName == "system" ? .system(size: 36) : .custom(t.fontName, fixedSize: 36))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(t.color.color)
                    .focused($textFocused)
                    .padding(24)
            }
            .overlay(alignment: .topTrailing) {
                Button("Done") { editingText = false }.buttonStyle(.glassProminent).padding()
            }
        }
    }

    /// Uploads an image and puts it on the canvas as the background or a new layer.
    private func place(_ data: Data, asBackground: Bool) async {
        guard let uid = session.userID else { return }
        do {
            let path = try await session.images.upload(data, userID: uid)
            if asBackground { model.edit { $0.background = .image(path: path) } } else { model.add(.image(path: path)) }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
