import Testing
import Foundation
@testable import MustDoCore

@Test func noteDefaultsContainTextStyle() {
    let note = Note()

    #expect(note.title == "새 스티커")
    #expect(note.fontSize == 12)
    #expect(note.textColorHex == "#000000")
    #expect(note.colorHex == "#FBE7C6")
    #expect(note.isClosed == false)
}

@Test func legacyBodyDecodesIntoText() throws {
    let json = """
    {
      "id": "11111111-1111-1111-1111-111111111111",
      "body": "기존 메모",
      "colorHex": "#FFF4A5",
      "x": 20,
      "y": 20,
      "width": 260,
      "height": 220
    }
    """.data(using: .utf8)!

    let decoded = try JSONDecoder().decode(Note.self, from: json)

    #expect(decoded.text == "기존 메모")
    #expect(decoded.title == "새 스티커")
    #expect(decoded.fontSize == 12)
    #expect(decoded.textColorHex == "#000000")
    #expect(decoded.isClosed == false)
}
