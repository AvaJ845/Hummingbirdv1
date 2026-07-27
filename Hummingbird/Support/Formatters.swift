import Foundation

extension Double {
    /// USD currency using Foundation `FormatStyle` (allocation-free, locale-aware).
    func asCurrency(maximumFractionDigits: Int = 2) -> String {
        let digits = self >= 1_000 ? 0 : maximumFractionDigits
        return formatted(
            .currency(code: "USD")
                .precision(.fractionLength(digits))
        )
    }

    /// Percent with an explicit leading `+` for positive moves.
    func asSignedPercent() -> String {
        let body = formatted(.percent.precision(.fractionLength(1)))
        if self > 0 { return "+\(body)" }
        return body
    }

    /// Unsigned percent (e.g. for error magnitudes).
    func asPercent(maximumFractionDigits: Int = 1) -> String {
        formatted(.percent.precision(.fractionLength(maximumFractionDigits)))
    }
}
