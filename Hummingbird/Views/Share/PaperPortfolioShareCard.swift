import SwiftUI

/// A self-contained, brandable card for sharing how the user's practice trading
/// compared to simply holding their first picks — same fixed dark look and
/// caveat-always-travels precedent as `ScorecardShareCard`. Deliberately frames
/// the *edge vs. buy-and-hold*, never a raw balance, and there is no comparison
/// against other users anywhere on the card.
struct PaperPortfolioShareCard: View {
    let report: PaperReport
    /// Return of the same starting cash in the market (S&P), if available.
    var marketReturn: Double? = nil
    /// When the practice began (earliest buy), for the period line.
    var startDate: Date? = nil

    private var comparison: BuyAndHoldComparison { report.comparison }

    private var periodText: String? {
        guard let startDate else { return nil }
        let days = max(1, Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0)
        return "over \(days) day\(days == 1 ? "" : "s") · since \(startDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var isHolding: Bool { comparison.tradeCount == 0 || abs(comparison.edge) < 0.0005 }

    private var accentColor: Color {
        if isHolding { return .white }
        return comparison.isBeatingHold ? Color(red: 0.35, green: 0.85, blue: 0.55)
                                        : Color(red: 0.98, green: 0.45, blue: 0.45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image("BrandMark")
                    .resizable().scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Hummingbird").font(.headline.weight(.bold)).foregroundStyle(.white)
                    Text("practice vs. buy-and-hold").font(.caption2).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(heroValue)
                    .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(accentColor)
                Text(heroCaption)
                    .font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }

            HStack(alignment: .top, spacing: 0) {
                label("You", comparison.yourReturn.asSignedPercent())
                Spacer()
                label("Buy-and-hold", comparison.holdReturn.asSignedPercent())
                if let marketReturn {
                    Spacer()
                    label("Market (S&P)", marketReturn.asSignedPercent())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if comparison.tradeCount > 0 {
                    Text("\(comparison.tradeCount) trade\(comparison.tradeCount == 1 ? "" : "s") vs. 0 in the comparison.")
                        .font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                }
                if let periodText {
                    Text(periodText).font(.caption2).foregroundStyle(.white.opacity(0.5))
                }
            }

            Divider().overlay(.white.opacity(0.15))

            Text("Practice with virtual money, on-device · a record, not financial advice")
                .font(.caption2).foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 340)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.15, blue: 0.12), Color(red: 0.03, green: 0.08, blue: 0.07)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var heroValue: String {
        if isHolding { return "Holding" }
        return comparison.isBeatingHold ? comparison.edge.asSignedPercent() : "−\((-comparison.edge).asPercent())"
    }

    private var heroCaption: String {
        if isHolding { return "my first picks, untouched" }
        return comparison.isBeatingHold ? "ahead of just holding my first picks"
                                        : "behind just holding my first picks"
    }

    private func label(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.5))
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}
