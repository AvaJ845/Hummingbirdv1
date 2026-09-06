import XCTest
@testable import Hummingbird

/// Post-update data-migration safety net.
///
/// Every on-disk store loads with `try? JSONDecoder().decode(...)` and swallows
/// a failure into an empty value — so a `Codable` shape change that breaks an
/// *old* payload would silently wipe the user's history on first launch of the
/// new build. These tests decode hand-written "old shape" fixtures (payloads as
/// they looked before fields added this development cycle) into the CURRENT
/// types and assert they still decode.
final class DataMigrationTests: XCTestCase {

    private let decoder = JSONDecoder()

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try decoder.decode(T.self, from: Data(json.utf8))
    }

    // MARK: - SketchRecord / SketchProjection

    /// Old record: no `reliabilityAtCreation`, no `regimeAtCreation`,
    /// projections with no `projectedBandHalfWidth`.
    func testOldSketchRecordStillDecodes() throws {
        let json = """
        [{
          "id": "1B4E28BA-2FA1-11D2-883F-0016D3CCA427",
          "symbol": "AAPL",
          "assetClass": "Stock",
          "modelId": "drift",
          "modelName": "Drift",
          "createdAt": 750000000,
          "spotAtCreation": 180.5,
          "projections": [
            { "targetDate": 751000000, "projectedMean": 182.0 },
            { "targetDate": 752000000, "projectedMean": 183.5, "actualClose": 181.2, "resolvedAt": 752500000 }
          ]
        }]
        """
        let records = try decode([SketchRecord].self, json)
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records[0].reliabilityAtCreation)
        XCTAssertNil(records[0].regimeAtCreation)
        XCTAssertNil(records[0].projections[0].projectedBandHalfWidth)
        XCTAssertEqual(records[0].projections[1].actualClose, 181.2)
        XCTAssertTrue(records[0].isResolved)
    }

    func testCurrentSketchRecordRoundTrips() throws {
        let record = SketchRecord(
            id: UUID(), symbol: "bitcoin", assetClass: .crypto,
            modelId: "holt", modelName: "Holt", createdAt: Date(),
            spotAtCreation: 65000,
            projections: [SketchProjection(targetDate: Date(), projectedMean: 66000,
                                           projectedBandHalfWidth: 1500,
                                           actualClose: nil, resolvedAt: nil)],
            reliabilityAtCreation: 62, regimeAtCreation: .elevated
        )
        let data = try JSONEncoder().encode([record])
        let back = try decoder.decode([SketchRecord].self, from: data)
        XCTAssertEqual(back.first?.regimeAtCreation, .elevated)
    }

    // MARK: - UserCall

    /// Old call: no `reason`, no `methodDirections` (both added this cycle).
    func testOldUserCallStillDecodes() throws {
        let json = """
        [{
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
          "symbol": "MSFT",
          "assetClass": "Stock",
          "createdAt": 750000000,
          "horizonDays": 7,
          "spotAtCall": 400.0,
          "direction": "higher",
          "confidence": "fairlySure"
        }]
        """
        let calls = try decode([UserCall].self, json)
        XCTAssertEqual(calls.count, 1)
        XCTAssertNil(calls[0].reason)
        XCTAssertNil(calls[0].methodDirections)
        XCTAssertEqual(calls[0].direction, .higher)
        XCTAssertFalse(calls[0].isResolved)
    }

    /// A slightly newer old call: has `reason` but still no `methodDirections`.
    func testMidVersionUserCallDecodes() throws {
        let json = """
        [{
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3302",
          "symbol": "NVDA", "assetClass": "Stock", "createdAt": 750000000,
          "horizonDays": 14, "spotAtCall": 120.0, "direction": "lower",
          "confidence": "confident", "reason": "earnings",
          "actualClose": 110.0, "resolvedAt": 751200000
        }]
        """
        let calls = try decode([UserCall].self, json)
        XCTAssertEqual(calls[0].reason, .earnings)
        XCTAssertEqual(calls[0].wasCorrect, true)
    }

    // MARK: - PaperPortfolio / PaperPosition

    /// Old portfolio: positions with no `methodDirections`, no `reason`.
    func testOldPaperPortfolioStillDecodes() throws {
        let json = """
        {
          "id": "9B2CF9C0-0000-0000-0000-000000000001",
          "createdAt": 740000000,
          "startingCash": 10000,
          "cash": 4200.5,
          "positions": [
            {
              "id": "9B2CF9C0-0000-0000-0000-000000000002",
              "symbol": "AAPL", "assetClass": "Stock",
              "openedAt": 740500000, "entryPrice": 180.0, "shares": 10,
              "direction": "higher"
            },
            {
              "id": "9B2CF9C0-0000-0000-0000-000000000003",
              "symbol": "bitcoin", "assetClass": "Crypto",
              "openedAt": 741000000, "entryPrice": 60000, "shares": 0.05,
              "direction": "higher", "closedAt": 742000000, "exitPrice": 65000
            }
          ]
        }
        """
        let portfolio = try decode(PaperPortfolio.self, json)
        XCTAssertEqual(portfolio.positions.count, 2)
        XCTAssertNil(portfolio.positions[0].methodDirections)
        XCTAssertNil(portfolio.positions[0].reason)
        XCTAssertEqual(portfolio.openPositions.count, 1)
        XCTAssertEqual(portfolio.positions[1].realizedReturn ?? 0, (65000.0 - 60000) / 60000, accuracy: 1e-9)
    }

    // MARK: - WatchlistItem / WatchlistSnapshot

    func testOldWatchlistItemDecodesWithoutAddedAt() throws {
        // `addedAt` has a default; an old payload without it must still decode.
        let json = """
        [{ "symbol": "AAPL", "assetClass": "Stock" },
         { "symbol": "ethereum", "assetClass": "Crypto", "displayName": "Ether" }]
        """
        let items = try decode([WatchlistItem].self, json)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "AAPL")
        XCTAssertEqual(items[1].displayName, "Ether")
    }

    // MARK: - Widget snapshots (App Group)

    func testTrackRecordSnapshotDecodesWithNullHitRate() throws {
        let json = #"{ "streak": 3, "hitRate": null, "decided": 0, "updatedAt": 750000000 }"#
        let snap = try decode(TrackRecordSnapshot.self, json)
        XCTAssertEqual(snap.streak, 3)
        XCTAssertNil(snap.hitRate)
    }

    func testPortfolioSnapshotDecodes() throws {
        let json = #"{ "value": 10250.0, "edge": 0.012, "tradeCount": 4, "updatedAt": 750000000 }"#
        let snap = try decode(PortfolioSnapshot.self, json)
        XCTAssertEqual(snap.tradeCount, 4)
    }

    // MARK: - End-to-end: the store load path must not wipe old data

    @MainActor
    func testUserCallStoreLoadsPreShapePayloadWithoutWiping() throws {
        let suite = "migration.calls.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let oldJSON = """
        [{
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3399",
          "symbol": "TSLA", "assetClass": "Stock", "createdAt": 750000000,
          "horizonDays": 7, "spotAtCall": 250.0, "direction": "higher", "confidence": "hunch"
        }]
        """
        defaults.set(Data(oldJSON.utf8), forKey: "hummingbird.calls")

        let store = UserCallStore(defaults: defaults)
        XCTAssertEqual(store.calls.count, 1, "old call payload must survive the load, not reset to empty")
        XCTAssertEqual(store.calls.first?.symbol, "TSLA")
    }

    @MainActor
    func testSketchScorecardStoreLoadsPreShapePayloadWithoutWiping() throws {
        let suite = "migration.scorecard.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let oldJSON = """
        [{
          "id": "1B4E28BA-2FA1-11D2-883F-0016D3CCA499",
          "symbol": "AAPL", "assetClass": "Stock", "modelId": "drift", "modelName": "Drift",
          "createdAt": 750000000, "spotAtCreation": 180.5,
          "projections": [{ "targetDate": 751000000, "projectedMean": 182.0 }]
        }]
        """
        defaults.set(Data(oldJSON.utf8), forKey: "hummingbird.scorecard.records")

        let store = SketchScorecardStore(defaults: defaults)
        XCTAssertEqual(store.records.count, 1, "old sketch record must survive the load")
    }

    @MainActor
    func testPaperPortfolioStoreLoadsPreShapePayloadWithoutWiping() throws {
        let suite = "migration.paper.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let oldJSON = """
        {
          "id": "9B2CF9C0-0000-0000-0000-0000000000AA",
          "createdAt": 740000000, "startingCash": 10000, "cash": 8000,
          "positions": [{
            "id": "9B2CF9C0-0000-0000-0000-0000000000AB",
            "symbol": "AAPL", "assetClass": "Stock", "openedAt": 740500000,
            "entryPrice": 180.0, "shares": 11.11, "direction": "higher"
          }]
        }
        """
        defaults.set(Data(oldJSON.utf8), forKey: "hummingbird.paperPortfolio")

        let store = PaperPortfolioStore(defaults: defaults)
        XCTAssertTrue(store.hasStarted, "old portfolio must survive the load")
        XCTAssertEqual(store.portfolio.positions.count, 1)
    }

    @MainActor
    func testWatchlistStoreLoadsPreShapePayloadWithoutWiping() throws {
        let suite = "migration.watchlist.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(Data(#"[{ "symbol": "AAPL", "assetClass": "Stock" }]"#.utf8),
                     forKey: "hummingbird.watchlist.items")

        let store = WatchlistStore(defaults: defaults)
        XCTAssertEqual(store.items.count, 1, "old watchlist payload must survive the load")
    }
}
