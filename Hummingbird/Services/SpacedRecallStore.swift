import Foundation
import Observation

/// Tracks which (call, interval) pairs the user has already been tested on
/// for spaced-retrieval review — on-device only, alongside the calls
/// themselves. Deliberately just a set of opaque keys, not a score or a
/// count: recording that a review happened is all this needs to remember.
@MainActor
@Observable
final class SpacedRecallStore {
    private(set) var reviewedKeys: Set<String> = []

    private let defaults: UserDefaults
    private static let storageKey = "hummingbird.spacedRecall.reviewed"

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        reviewedKeys = Set(defaults.stringArray(forKey: Self.storageKey) ?? [])
    }

    func isReviewed(_ call: UserCall, intervalIndex: Int) -> Bool {
        reviewedKeys.contains(key(call.id, intervalIndex))
    }

    func recordReviewed(_ call: UserCall, intervalIndex: Int) {
        reviewedKeys.insert(key(call.id, intervalIndex))
        defaults.set(Array(reviewedKeys), forKey: Self.storageKey)
    }

    private func key(_ id: UUID, _ intervalIndex: Int) -> String { "\(id.uuidString)-\(intervalIndex)" }
}
