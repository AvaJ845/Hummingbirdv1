import Foundation

protocol EconomicDataProviding: Sendable {
    func fetchSnapshots() async -> [EconomicSnapshot]
}

/// Loads daily rate what-ifs from free, key-less Yahoo chart APIs:
/// - ^IRX (fed proxy), ^TNX (10Y)
///
/// Failed fetches are omitted (no silent sample stand-ins).
/// Annual World Bank macros were removed — too stale for ≤90-day sketches.
actor EconomicDataService: EconomicDataProviding {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchSnapshots() async -> [EconomicSnapshot] {
        await withTaskGroup(of: (EconomicIndicatorKind, EconomicSnapshot?).self) { group in
            for kind in EconomicIndicatorKind.allCases {
                group.addTask {
                    (kind, await self.fetch(kind))
                }
            }

            var byKind: [EconomicIndicatorKind: EconomicSnapshot] = [:]
            for await (kind, snapshot) in group {
                guard let snapshot, !snapshot.isSample else { continue }
                byKind[kind] = snapshot
            }

            return EconomicIndicatorKind.allCases.compactMap { byKind[$0] }
        }
    }

    private func fetch(_ kind: EconomicIndicatorKind) async -> EconomicSnapshot? {
        switch kind {
        case .fedFunds:
            return await yahooPercent(symbol: "^IRX", kind: kind)
        case .treasury10Y:
            return await yahooPercent(symbol: "^TNX", kind: kind)
        }
    }

    private func yahooPercent(symbol: String, kind: EconomicIndicatorKind) async -> EconomicSnapshot? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "query1.finance.yahoo.com"
        components.percentEncodedPath = "/v8/finance/chart/\(symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol)"
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "3mo")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(AppNetwork.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            return try EconomicParsing.parseYahooPercent(data, kind: kind)
        } catch {
            return nil
        }
    }
}

// MARK: - Test / offline helpers

enum SampleMacro {
    /// Deterministic stand-ins for unit tests only — never shown as live economy data.
    static func snapshot(for kind: EconomicIndicatorKind) -> EconomicSnapshot {
        switch kind {
        case .fedFunds:
            EconomicSnapshot(kind: kind, value: 4.25, previousValue: 4.35, asOf: .now, source: "Sample", isSample: true)
        case .treasury10Y:
            EconomicSnapshot(kind: kind, value: 4.35, previousValue: 4.20, asOf: .now, source: "Sample", isSample: true)
        }
    }
}
