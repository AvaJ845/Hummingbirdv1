import XCTest
@testable import Hummingbird

final class WeeklyLiteracyStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "hummingbird.tests.weeklyLiteracy"

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    // A Wednesday.
    private let weekOne = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    @MainActor func testAssignsAQuestionOnFirstCall() {
        let store = WeeklyLiteracyStore(defaults: defaults)
        XCTAssertNotNil(store.questionForThisWeek(now: weekOne, calendar: calendar))
    }

    @MainActor func testSameQuestionWithinTheSameWeek() {
        let store = WeeklyLiteracyStore(defaults: defaults)
        let first = store.questionForThisWeek(now: weekOne, calendar: calendar)
        let laterSameWeek = calendar.date(byAdding: .day, value: 2, to: weekOne)!
        let second = store.questionForThisWeek(now: laterSameWeek, calendar: calendar)
        XCTAssertEqual(first?.id, second?.id)
    }

    @MainActor func testNewQuestionNextWeekAfterAnswering() {
        let store = WeeklyLiteracyStore(defaults: defaults)
        let first = store.questionForThisWeek(now: weekOne, calendar: calendar)
        store.recordShown()

        let nextWeek = calendar.date(byAdding: .day, value: 8, to: weekOne)!
        let second = store.questionForThisWeek(now: nextWeek, calendar: calendar)
        XCTAssertNotEqual(first?.id, second?.id)
    }

    @MainActor func testDismissingAdvancesRotationJustLikeAnswering() {
        // Declining is treated the same as completing it, matching the rest
        // of the app's "never nagged back" discipline.
        let store = WeeklyLiteracyStore(defaults: defaults)
        let first = store.questionForThisWeek(now: weekOne, calendar: calendar)
        store.recordShown()
        XCTAssertTrue(store.shownIDs.contains(first!.id))
    }

    @MainActor func testAnsweredFlagResetsOnNewWeek() {
        let store = WeeklyLiteracyStore(defaults: defaults)
        _ = store.questionForThisWeek(now: weekOne, calendar: calendar)
        store.recordShown()
        XCTAssertTrue(store.answered)

        let nextWeek = calendar.date(byAdding: .day, value: 8, to: weekOne)!
        _ = store.questionForThisWeek(now: nextWeek, calendar: calendar)
        XCTAssertFalse(store.answered)
    }

    @MainActor func testGoesSilentAfterAnsweringWithinSameWeek() {
        // The reported bug: "This week's question" re-appeared every time Home
        // came forward, and answering never silenced it. Once answered (or
        // dismissed), re-asking within the same week must return nil.
        let store = WeeklyLiteracyStore(defaults: defaults)
        XCTAssertNotNil(store.questionForThisWeek(now: weekOne, calendar: calendar))
        store.recordShown()
        let laterSameWeek = calendar.date(byAdding: .day, value: 2, to: weekOne)!
        XCTAssertNil(store.questionForThisWeek(now: laterSameWeek, calendar: calendar))
    }

    @MainActor func testPersistsAcrossInstances() {
        let first = WeeklyLiteracyStore(defaults: defaults)
        let question = first.questionForThisWeek(now: weekOne, calendar: calendar)
        first.recordShown()

        // A fresh instance in the same week honors the persisted answered
        // state: still silent, and the id is remembered as shown.
        let second = WeeklyLiteracyStore(defaults: defaults)
        XCTAssertNil(second.questionForThisWeek(now: weekOne, calendar: calendar))
        XCTAssertTrue(second.shownIDs.contains(question!.id))
    }
}
