import Foundation

/// The honest, *shown-not-rewarded* connection between the weekly lessons and
/// the user's record: did engaging with the lessons track with better calls?
/// Splits the user's decided calls at the date they first engaged with a weekly
/// lesson and compares directional hit rate before vs. after. Deliberately
/// conservative — nil unless there's a real sample on both sides — so it never
/// dresses noise up as a trend. Correlation, a record of the past, never advice
/// and never a claim the lessons *caused* the change.
struct LessonsCalibrationInsight: Equatable, Sendable {
    let beforeRate: Double
    let afterRate: Double
    let beforeDecided: Int
    let afterDecided: Int

    /// Change in hit rate after first engaging with the lessons.
    var delta: Double { afterRate - beforeRate }
    var improved: Bool { afterRate > beforeRate }
}

enum LessonsCalibrationEngine {
    /// - Parameters:
    ///   - calls: the user's calls (only resolved, decidable ones are scored).
    ///   - lessonsStartedAt: when they first engaged a weekly lesson (nil = never).
    ///   - minEachSide: minimum decided calls required on *each* side to report.
    static func insight(calls: [UserCall], lessonsStartedAt: Date?,
                        minEachSide: Int = 5) -> LessonsCalibrationInsight? {
        guard let start = lessonsStartedAt else { return nil }
        let decided = calls.filter { $0.wasCorrect != nil }
        let before = decided.filter { $0.createdAt < start }
        let after = decided.filter { $0.createdAt >= start }
        guard before.count >= minEachSide, after.count >= minEachSide else { return nil }

        func rate(_ group: [UserCall]) -> Double {
            Double(group.filter { $0.wasCorrect == true }.count) / Double(group.count)
        }
        return LessonsCalibrationInsight(
            beforeRate: rate(before), afterRate: rate(after),
            beforeDecided: before.count, afterDecided: after.count
        )
    }
}
