import Foundation
import Testing
@testable import DavatKit

@Suite struct ModelsTests {
    @Test func designRoundTrips() throws {
        let d = Design(
            background: .gradient([RGBA(r: 1, g: 0.5, b: 0, a: 1), RGBA(r: 0, g: 0, b: 0, a: 1)], angle: 45),
            layers: [
                Layer(id: UUID(), kind: .emoji("🎂"), x: 0.5, y: 0.3, scale: 1, rotation: 10, opacity: 1),
                Layer(id: UUID(), kind: .shape(ShapeLayer(kind: .star, fill: RGBA(r: 1, g: 1, b: 1, a: 1), stroke: nil, size: CGSize(width: 40, height: 40))),
                      x: 0.2, y: 0.8, scale: 1, rotation: 0, opacity: 0.8),
            ],
            effect: .confetti,
            envelope: true
        )
        let back = try JSONDecoder().decode(Design.self, from: JSONEncoder().encode(d))
        #expect(back == d)
    }

    @Test func unknownLayerKindIsSkipped() throws {
        let id = UUID().uuidString
        let json = """
        {"background":{"color":{"_0":{"r":0,"g":0,"b":0,"a":1}}},
         "layers":[
           {"id":"\(id)","kind":{"hologram":{}},"x":0.5,"y":0.5,"scale":1,"rotation":0,"opacity":1},
           {"id":"\(id)","kind":{"emoji":{"_0":"x"}},"x":0.5,"y":0.5,"scale":1,"rotation":0,"opacity":1}],
         "effect":"none","envelope":false}
        """
        let d = try JSONDecoder().decode(Design.self, from: Data(json.utf8))
        #expect(d.layers.count == 1)
        #expect(d.layers[0].kind == .emoji("x"))
    }

    @Test func inviteRowWritesNulls() throws {
        let i = Invite(id: UUID(), hostID: UUID(), title: "t", design: Design(background: .color(RGBA(r: 1, g: 1, b: 1))),
                       updatedAt: Date(), timeZone: "America/Chicago")
        let json = String(decoding: try JSONEncoder().encode(SupabaseBackend.InviteRow(i)), as: UTF8.self)
        for key in ["price_cents", "starts_at", "poster_path"] { #expect(json.contains("\"\(key)\":null")) }
        #expect(json.contains("\"host_pays\":false"))
        #expect(json.contains(#""time_zone":"America\/Chicago""#))
    }

    @Test func inviteDecodesWithoutTimeZone() throws {
        let i = Invite(id: UUID(), hostID: UUID(), title: "t", design: Design(background: .color(RGBA(r: 1, g: 1, b: 1))),
                       updatedAt: Date(timeIntervalSince1970: 0))
        var obj = try JSONSerialization.jsonObject(with: JSONEncoder().encode(i)) as! [String: Any]
        obj["timeZone"] = nil
        let back = try JSONDecoder().decode(Invite.self, from: JSONSerialization.data(withJSONObject: obj))
        #expect(back == i && back.timeZone == nil)
    }
}
