import Foundation
import Testing
@testable import DavatKit

@Suite struct DesignTests {
    private func blank() -> Design { Design(background: .color(RGBA(r: 1, g: 1, b: 1))) }

    @Test func testAddBringForwardSendBackward() {
        var d = blank()
        let a = d.addLayer(.emoji("🎉")).id
        let b = d.addLayer(.emoji("🎂")).id
        let c = d.addLayer(.emoji("🪩")).id
        #expect(d.layers.map(\.id) == [a, b, c])
        d.moveLayer(id: a, by: 1)
        #expect(d.layers.map(\.id) == [b, a, c])
        d.moveLayer(id: c, by: -2)
        #expect(d.layers.map(\.id) == [c, b, a])
        d.moveLayer(id: a, by: 5)       // already on top: clamps, no crash
        d.moveLayer(id: c, by: -1)      // already at bottom
        #expect(d.layers.map(\.id) == [c, b, a])
    }

    @Test func testDuplicateOffsetsLayer() throws {
        var d = blank()
        let a = d.addLayer(.emoji("💖"))
        let b = d.addLayer(.emoji("🌸"))
        let dup = d.duplicateLayer(id: a.id)
        let copyID = try #require(dup)
        #expect(d.layers.count == 3)
        #expect(d.layers[1].id == copyID)          // right above the original
        #expect(d.layers[2].id == b.id)
        let copy = d.layers[1]
        #expect(copy.kind == a.kind)
        #expect(copy.x > a.x && copy.y > a.y)
        let none = d.duplicateLayer(id: UUID())
        #expect(none == nil)
    }

    @Test func testTemplatesAllEncode() throws {
        #expect(Templates.all.count >= 12)
        #expect(Set(Templates.all.map(\.name)).count == Templates.all.count)
        for t in Templates.all {
            let back = try JSONDecoder().decode(Design.self, from: JSONEncoder().encode(t.design))
            #expect(back == t.design, "\(t.name)")
            #expect(!t.design.layers.isEmpty, "\(t.name)")
        }
    }

    @Test func testCurveClamped() {
        var t = TextLayer(text: "hi", color: RGBA(r: 0, g: 0, b: 0), curve: 3)
        #expect(t.curve == 1)
        t.curve = -7
        #expect(t.curve == -1)
        t.curve = 0.4
        #expect(t.curve == 0.4)
    }
}
