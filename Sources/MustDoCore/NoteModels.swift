import Foundation
import SwiftUI

public struct ChecklistTask: Identifiable, Codable, Hashable {
    public var id: UUID
    public var text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String = "", isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

public struct Note: Identifiable, Codable, Hashable {
    public var id: UUID
    public var title: String
    public var text: String
    public var colorHex: String
    public var textColorHex: String
    public var fontSize: Double
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var updatedAt: Date
    public var checklist: [ChecklistTask]
    public var isClosed: Bool

    public init(
        id: UUID = UUID(),
        title: String = "새 스티커",
        text: String = "",
        colorHex: String = "#FBE7C6",
        textColorHex: String = "#000000",
        fontSize: Double = 12,
        x: Double = 40,
        y: Double = 40,
        width: Double = 280,
        height: Double = 250,
        updatedAt: Date = .now,
        checklist: [ChecklistTask] = [],
        isClosed: Bool = false
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.colorHex = colorHex
        self.textColorHex = textColorHex
        self.fontSize = fontSize
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.updatedAt = updatedAt
        self.checklist = checklist
        self.isClosed = isClosed
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case text
        case body
        case colorHex
        case textColorHex
        case fontSize
        case x
        case y
        case width
        case height
        case updatedAt
        case checklist
        case isClosed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "새 스티커"
        text = try container.decodeIfPresent(String.self, forKey: .text)
            ?? container.decodeIfPresent(String.self, forKey: .body)
            ?? ""
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "#FBE7C6"
        textColorHex = try container.decodeIfPresent(String.self, forKey: .textColorHex) ?? "#000000"
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 12
        x = try container.decodeIfPresent(Double.self, forKey: .x) ?? 40
        y = try container.decodeIfPresent(Double.self, forKey: .y) ?? 40
        width = try container.decodeIfPresent(Double.self, forKey: .width) ?? 280
        height = try container.decodeIfPresent(Double.self, forKey: .height) ?? 250
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .now
        checklist = try container.decodeIfPresent([ChecklistTask].self, forKey: .checklist) ?? []
        isClosed = try container.decodeIfPresent(Bool.self, forKey: .isClosed) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(text, forKey: .text)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(textColorHex, forKey: .textColorHex)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(checklist, forKey: .checklist)
        try container.encode(isClosed, forKey: .isClosed)
    }
}

extension Color {
    public init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (251, 231, 198)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}

public enum NoteColors {
    public static let presets = [
        "#FBE7C6",
        "#DFF7E2",
        "#DDEBFF",
        "#FADDE1",
        "#E7DDF9",
        "#FFF4BF"
    ]
}

public enum TextColors {
    public static let presets = [
        "#374151",
        "#334E68",
        "#6B4F4F",
        "#3F5C4A",
        "#5A4B81"
    ]
}
