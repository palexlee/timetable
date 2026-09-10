import SwiftUI

extension Color {
    static let sbbRed = Color(red: 0xEB / 255, green: 0x00 / 255, blue: 0x00 / 255)
    static let inkPrimary = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let inkSecondary = Color(red: 0x8A / 255, green: 0x8A / 255, blue: 0x8A / 255)
    static let dividerLight = Color(red: 0xE7 / 255, green: 0xE7 / 255, blue: 0xE7 / 255)
    static let dividerFaint = Color(white: 0.94)
    static let fieldBackground = Color(red: 0xF2 / 255, green: 0xF2 / 255, blue: 0xF2 / 255)
    static let pinnedTint = Color(red: 0xFD / 255, green: 0xEC / 255, blue: 0xEC / 255)
}

extension Font {
    static func sbb(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", size: size).weight(weight)
    }
}

/// Approximate line-badge color by category, matching common Swiss rail
/// conventions (IC/EC red, IR/RJ violet, RE green, S-Bahn blue) and mode
/// for everything else. Not each line's exact official color -- that data
/// (GTFS route_color) isn't in the OJP responses this app parses.
func lineBadgeColor(mode: String, lineName: String) -> Color {
    let name = lineName.trimmingCharacters(in: .whitespaces).uppercased()
    if name.hasPrefix("IC") || name.hasPrefix("EC") {
        return Color(red: 0xEB / 255, green: 0x00 / 255, blue: 0x00 / 255) // red
    }
    if name.hasPrefix("IR") || name.hasPrefix("RJ") {
        return Color(red: 0xB0 / 255, green: 0x00 / 255, blue: 0x63 / 255) // violet
    }
    if name.hasPrefix("RE") {
        return Color(red: 0x00 / 255, green: 0x8A / 255, blue: 0x3A / 255) // green
    }
    if name.hasPrefix("S"), let second = name.dropFirst().first, second.isNumber {
        return Color(red: 0x00 / 255, green: 0x5E / 255, blue: 0xA6 / 255) // blue
    }
    switch mode.trimmingCharacters(in: .whitespaces).lowercased() {
    case "bus", "coach":
        return Color(red: 0x6A / 255, green: 0x1B / 255, blue: 0x9A / 255) // violet
    case "tram":
        return Color(red: 0xE1 / 255, green: 0x5C / 255, blue: 0x00 / 255) // orange
    case "metro", "underground":
        return Color(red: 0x00 / 255, green: 0x59 / 255, blue: 0x5C / 255) // teal
    case "water":
        return Color(red: 0x00 / 255, green: 0x6C / 255, blue: 0x9E / 255) // ferry blue
    case "cableway", "funicular":
        return Color(red: 0x5C / 255, green: 0x5C / 255, blue: 0x5C / 255) // gray
    default:
        return Color(red: 0x4A / 255, green: 0x4A / 255, blue: 0x4A / 255) // neutral gray
    }
}
