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

    init(design: Design) { self.design = design }

    var selected: Layer? { design.layers.first { $0.id == selection } }

    /// Every change goes through here. Edits less than 0.6s apart (a drag, a slider) share one undo step.
    func edit(_ change: (inout Design) -> Void) {
        let old = design
        change(&design)
        guard design != old else { return }
        if Date.now.timeIntervalSince(lastEdit) > 0.6 { registerUndo(old) }
        lastEdit = .now
        refresh()
    }

    func editSelected(_ change: (inout Layer) -> Void) {
        guard let id = selection else { return }
        edit { d in if let i = d.layers.firstIndex(where: { $0.id == id }) { change(&d.layers[i]) } }
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
        edit { id = $0.addLayer(kind).id }
        selection = id
        lastEdit = .distantPast   // adding is its own undo step
    }
    func delete(_ id: UUID) {
        edit { $0.layers.removeAll { $0.id == id } }
        if selection == id { selection = nil }
    }
    func bringForward(_ id: UUID) { edit { $0.moveLayer(id: id, by: 1) } }
    func sendBackward(_ id: UUID) { edit { $0.moveLayer(id: id, by: -1) } }
    func duplicate(_ id: UUID) {
        var copy: UUID?
        edit { copy = $0.duplicateLayer(id: id) }
        selection = copy
    }
}
