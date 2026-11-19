import DavatKit
import Foundation
import Observation

@MainActor @Observable final class EditorModel {
    private(set) var design: Design
    var selection: UUID?
    private(set) var canUndo = false
    private(set) var canRedo = false
    @ObservationIgnored let undoManager = UndoManager()
    @ObservationIgnored private var lastEdit = Date.distantPast
    @ObservationIgnored private var stepStart: Design?
    static let scaleRange = 0.1...8.0

    init(design: Design) { self.design = design }

    var selected: Layer? { design.layers.first { $0.id == selection } }

    /// Every change goes through here. Inside a begin/endStep pair (a gesture) nothing registers until
    /// the end; otherwise edits less than 0.6s apart (a slider) share one undo step.
    func edit(_ change: (inout Design) -> Void) {
        let old = design
        change(&design)
        guard design != old else { return }
        if stepStart == nil, Date.now.timeIntervalSince(lastEdit) > 0.6 { registerUndo(old) }
        lastEdit = .now
        refresh()
    }

    func editSelected(_ change: (inout Layer) -> Void) {
        guard let id = selection else { return }
        edit { d in if let i = d.layers.firstIndex(where: { $0.id == id }) { change(&d.layers[i]) } }
    }

    func beginStep() { if stepStart == nil { stepStart = design } }
    func endStep() {
        if let start = stepStart, start != design { registerUndo(start); refresh() }
        stepStart = nil
        lastEdit = .distantPast
    }

    /// A discrete action is always its own undo step.
    private func action(_ change: (inout Design) -> Void) {
        stepStart = nil   // a gesture that never ended must not swallow later undo steps
        lastEdit = .distantPast
        edit(change)
        lastEdit = .distantPast
    }

    private func registerUndo(_ old: Design) {
        undoManager.registerUndo(withTarget: self) { m in
            MainActor.assumeIsolated {
                m.registerUndo(m.design)          // registered while undoing, so it becomes the redo
                m.design = old
                if let s = m.selection, !old.layers.contains(where: { $0.id == s }) { m.selection = nil }
                m.lastEdit = .distantPast
                m.refresh()
            }
        }
    }

    private func refresh() { canUndo = undoManager.canUndo; canRedo = undoManager.canRedo }

    func undo() { undoManager.undo(); refresh() }
    func redo() { undoManager.redo(); refresh() }

    func add(_ kind: LayerKind) {
        var id: UUID?
        action { id = $0.addLayer(kind).id }
        selection = id
    }
    func delete(_ id: UUID) {
        action { $0.layers.removeAll { $0.id == id } }
        if selection == id { selection = nil }
    }
    func bringForward(_ id: UUID) { action { $0.moveLayer(id: id, by: 1) } }
    func sendBackward(_ id: UUID) { action { $0.moveLayer(id: id, by: -1) } }
    func duplicate(_ id: UUID) {
        var copy: UUID?
        action { copy = $0.duplicateLayer(id: id) }
        selection = copy
    }
}
