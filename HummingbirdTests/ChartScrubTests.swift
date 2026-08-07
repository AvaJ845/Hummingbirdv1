import XCTest
@testable import Hummingbird

final class ChartScrubTests: XCTestCase {
    private func dates(_ offsets: [Int]) -> [Date] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return offsets.map { base.addingTimeInterval(Double($0) * 86_400) }
    }

    func testNilForEmpty() {
        XCTAssertNil(ChartScrub.nearestIndex(to: Date(), in: []))
    }

    func testPicksClosest() {
        let ds = dates([0, 1, 2, 3, 4])
        // Target 2.4 days in → closest is index 2.
        let target = ds[0].addingTimeInterval(2.4 * 86_400)
        XCTAssertEqual(ChartScrub.nearestIndex(to: target, in: ds), 2)
        // Exactly on a point.
        XCTAssertEqual(ChartScrub.nearestIndex(to: ds[3], in: ds), 3)
        // Before the first → clamps to 0.
        XCTAssertEqual(ChartScrub.nearestIndex(to: ds[0].addingTimeInterval(-10_000), in: ds), 0)
        // After the last → clamps to last.
        XCTAssertEqual(ChartScrub.nearestIndex(to: ds[4].addingTimeInterval(10_000), in: ds), 4)
    }
}
