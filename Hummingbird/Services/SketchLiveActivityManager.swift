import ActivityKit
import Foundation

/// Starts, updates, and ends the "tracking a sketch" Live Activity. Every entry
/// point no-ops gracefully when Live Activities are unsupported or disabled, so
/// callers never need to guard. Groundwork — not yet wired into the run flow;
/// activation + Dynamic Island layout are verified on a physical device.
enum SketchLiveActivityManager {
    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Begin a fresh activity for the loaded asset (ends any existing one first).
    @discardableResult
    static func start(symbol: String, title: String, horizonDays: Int,
                      price: Double, projectedChange: Double) -> Bool {
        guard isSupported else { return false }
        endAll()
        let attributes = SketchActivityAttributes(symbol: symbol, title: title, horizonDays: horizonDays)
        let state = SketchActivityAttributes.ContentState(
            price: price, projectedChange: projectedChange, updatedAt: Date()
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            return true
        } catch {
            return false
        }
    }

    /// Push a fresh price/projection into any running activity.
    static func update(price: Double, projectedChange: Double) {
        let state = SketchActivityAttributes.ContentState(
            price: price, projectedChange: projectedChange, updatedAt: Date()
        )
        Task {
            for activity in Activity<SketchActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
    }

    static func endAll() {
        Task {
            for activity in Activity<SketchActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
