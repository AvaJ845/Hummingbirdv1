import XCTest
@testable import Hummingbird

final class LiteracyQuestionEngineTests: XCTestCase {
    private let bank: [LiteracyQuestion] = [
        LiteracyQuestion(id: "a", question: "Q1", options: ["x", "y"], correctIndex: 0, explanation: "e1"),
        LiteracyQuestion(id: "b", question: "Q2", options: ["x", "y"], correctIndex: 1, explanation: "e2"),
        LiteracyQuestion(id: "c", question: "Q3", options: ["x", "y"], correctIndex: 0, explanation: "e3"),
    ]

    func testFirstQuestionWhenNoneShown() {
        XCTAssertEqual(LiteracyQuestionEngine.next(shown: [], bank: bank)?.id, "a")
    }

    func testSkipsAlreadyShown() {
        XCTAssertEqual(LiteracyQuestionEngine.next(shown: ["a"], bank: bank)?.id, "b")
    }

    func testCyclesBackToStartOnceBankExhausted() {
        XCTAssertEqual(LiteracyQuestionEngine.next(shown: ["a", "b", "c"], bank: bank)?.id, "a")
    }

    func testNilForEmptyBank() {
        XCTAssertNil(LiteracyQuestionEngine.next(shown: [], bank: []))
    }

    // MARK: - Content bank sanity

    func testBankHasNoDuplicateIDs() {
        let ids = LiteracyQuestionBank.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryQuestionHasAValidCorrectIndex() {
        for question in LiteracyQuestionBank.all {
            XCTAssertTrue(question.options.indices.contains(question.correctIndex),
                          "\(question.id) has an out-of-range correctIndex")
        }
    }

    func testEveryQuestionHasAtLeastTwoOptions() {
        for question in LiteracyQuestionBank.all {
            XCTAssertGreaterThanOrEqual(question.options.count, 2, "\(question.id) needs at least 2 options")
        }
    }

    func testNoQuestionPredictsASpecificAssetDirection() {
        // Precise advice-directive phrases only — plain financial vocabulary
        // like "buyers and sellers" or "a dollar buys less" is legitimate
        // definitional content, not a recommendation.
        let bannedPhrases = ["should buy", "should sell", "buy now", "sell now", "will rise", "will fall", "should invest"]
        for question in LiteracyQuestionBank.all {
            let text = (question.question + " " + question.explanation).lowercased()
            for phrase in bannedPhrases {
                XCTAssertFalse(text.contains(phrase), "\(question.id) contains advice-adjacent language: \(phrase)")
            }
        }
    }

    func testBankHasSubstantialContent() {
        // Enough variety that weekly rotation doesn't repeat within a season.
        XCTAssertGreaterThanOrEqual(LiteracyQuestionBank.all.count, 12)
    }
}
