import XCTest
@testable import Hummingbird

final class NotificationBudgetTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private var defaults: UserDefaults!
    private let today = Date(timeIntervalSince1970: 1_700_000_000)

    private let suiteName = "hummingbird.tests.notificationBudget"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testAllowsSendsUpToTheDailyCap() {
        for _ in 0..<NotificationBudget.dailyDiscretionaryCap {
            XCTAssertTrue(NotificationBudget.canSendDiscretionary(defaults: defaults, now: today, calendar: calendar))
            NotificationBudget.recordSent(defaults: defaults, now: today, calendar: calendar)
        }
        XCTAssertFalse(NotificationBudget.canSendDiscretionary(defaults: defaults, now: today, calendar: calendar))
    }

    func testResetsOnANewCalendarDay() {
        for _ in 0..<NotificationBudget.dailyDiscretionaryCap {
            NotificationBudget.recordSent(defaults: defaults, now: today, calendar: calendar)
        }
        XCTAssertFalse(NotificationBudget.canSendDiscretionary(defaults: defaults, now: today, calendar: calendar))

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        XCTAssertTrue(NotificationBudget.canSendDiscretionary(defaults: defaults, now: tomorrow, calendar: calendar))
    }

    func testFreshBudgetAllowsSending() {
        XCTAssertTrue(NotificationBudget.canSendDiscretionary(defaults: defaults, now: today, calendar: calendar))
    }
}
