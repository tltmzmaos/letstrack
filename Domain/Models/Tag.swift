import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF"
    var usageCount: Int = 0
    var createdAt: Date = Date()

    init(name: String, colorHex: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.usageCount = 0
        self.createdAt = Date()
    }

    // MARK: - Computed Properties

    var displayName: String {
        "#\(name)"
    }

    var color: String {
        colorHex
    }

    // MARK: - Methods

    func incrementUsage() {
        usageCount += 1
    }
}

// MARK: - Preset Colors
extension Tag {
    static let presetColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF2D55", "#AF52DE",
        "#5856D6", "#00C7BE", "#FF3B30", "#FFCC00", "#8E8E93",
        "#5AC8FA", "#4CD964", "#FF6B6B", "#C44569", "#546DE5"
    ]

    static let suggestedTags = [
        "travel", "date", "business", "family", "emergency",
        "subscription", "gift", "health", "education", "hobby"
    ]
}
