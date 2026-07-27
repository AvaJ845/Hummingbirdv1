import SwiftUI

enum Theme {
    static let accent = Color(red: 0.30, green: 0.78, blue: 0.55)      // hummingbird green
    static let accentAlt = Color(red: 0.16, green: 0.55, blue: 0.90)   // iridescent blue
    static let up = Color(red: 0.20, green: 0.78, blue: 0.50)
    static let down = Color(red: 0.95, green: 0.36, blue: 0.38)

    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [accentAlt, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func changeColor(_ change: Double?) -> Color {
        guard let change else { return .secondary }
        return change >= 0 ? up : down
    }
}

extension Double {
    func asCurrency(maximumFractionDigits: Int = 2) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = self >= 1000 ? 0 : maximumFractionDigits
        return f.string(from: NSNumber(value: self)) ?? "$\(self)"
    }

    func asSignedPercent() -> String {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        f.positivePrefix = "+"
        return f.string(from: NSNumber(value: self)) ?? "\(self * 100)%"
    }
}
