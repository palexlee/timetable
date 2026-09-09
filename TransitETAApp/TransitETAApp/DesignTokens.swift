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
