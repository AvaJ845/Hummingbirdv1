import XCTest
import SwiftUI
@testable import Hummingbird

@MainActor
final class ShareCardTests: XCTestCase {
    func testProjectionCardRendersToImage() {
        let card = ProjectionShareCard(
            symbol: "bitcoin",
            price: 64_900,
            projectedChange: -0.012,
            methodName: "Mean reversion",
            horizonDays: 30,
            historySpark: (0..<24).map { 0.5 + 0.35 * sin(Double($0) / 3) },
            projectionSpark: (0..<30).map { max(0, 0.5 - Double($0) * 0.006) }
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        let image = renderer.uiImage
        XCTAssertNotNil(image, "Share card must rasterize")
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
    }
}
