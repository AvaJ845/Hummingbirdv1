import XCTest
@testable import Hummingbird

final class ExplainItEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Prompt selection

    func testNilWhenNothingInteresting() {
        let result = ExplainItEngine.prompt(
            disagreementSpread: 0.005, macroActive: false, macroHorizonBias: 0,
            lastPromptedAt: nil, now: now
        )
        XCTAssertNil(result)
    }

    func testDisagreementAboveThresholdPrompts() {
        let result = ExplainItEngine.prompt(
            disagreementSpread: 0.03, macroActive: false, macroHorizonBias: 0,
            lastPromptedAt: nil, now: now
        )
        XCTAssertEqual(result, .disagreement(spread: 0.03))
    }

    func testMacroActiveWithLowDisagreementPrompts() {
        let result = ExplainItEngine.prompt(
            disagreementSpread: 0.001, macroActive: true, macroHorizonBias: 0.01,
            lastPromptedAt: nil, now: now
        )
        XCTAssertEqual(result, .macro(horizonBias: 0.01))
    }

    func testDisagreementTakesPriorityOverMacro() {
        let result = ExplainItEngine.prompt(
            disagreementSpread: 0.03, macroActive: true, macroHorizonBias: 0.01,
            lastPromptedAt: nil, now: now
        )
        XCTAssertEqual(result, .disagreement(spread: 0.03))
    }

    func testThrottleBlocksAnotherPromptTooSoon() {
        let recent = now.addingTimeInterval(-3600) // 1 hour ago, gap is 6 hours
        let result = ExplainItEngine.prompt(
            disagreementSpread: 0.05, macroActive: false, macroHorizonBias: 0,
            lastPromptedAt: recent, now: now
        )
        XCTAssertNil(result)
    }

    func testThrottleAllowsPromptAfterGap() {
        let longAgo = now.addingTimeInterval(-7 * 3600) // 7 hours ago
        let result = ExplainItEngine.prompt(
            disagreementSpread: 0.05, macroActive: false, macroHorizonBias: 0,
            lastPromptedAt: longAgo, now: now
        )
        XCTAssertNotNil(result)
    }

    // MARK: - Disagreement correctness

    func testDisagreementCorrectAnswerIsTrustLess() {
        let prompt = ExplainItPrompt.disagreement(spread: 0.04)
        XCTAssertTrue(prompt.isCorrect("Trust it less"))
        XCTAssertFalse(prompt.isCorrect("Trust it more"))
        XCTAssertFalse(prompt.isCorrect("Doesn't matter"))
    }

    // MARK: - Macro correctness

    func testMacroPositiveBiasMeansUpIsCorrect() {
        let prompt = ExplainItPrompt.macro(horizonBias: 0.02)
        XCTAssertTrue(prompt.isCorrect("Up"))
        XCTAssertFalse(prompt.isCorrect("Down"))
        XCTAssertFalse(prompt.isCorrect("Barely any effect"))
    }

    func testMacroNegativeBiasMeansDownIsCorrect() {
        let prompt = ExplainItPrompt.macro(horizonBias: -0.02)
        XCTAssertTrue(prompt.isCorrect("Down"))
        XCTAssertFalse(prompt.isCorrect("Up"))
    }

    func testMacroNegligibleBiasMeansBarelyAnyEffectIsCorrect() {
        let prompt = ExplainItPrompt.macro(horizonBias: 0.001)
        XCTAssertTrue(prompt.isCorrect("Barely any effect"))
        XCTAssertFalse(prompt.isCorrect("Up"))
        XCTAssertFalse(prompt.isCorrect("Down"))
    }

    func testMacroBoundaryMatchesRetailExplainerThreshold() {
        // RetailExplainer.scenarioNudgePlain treats 0.005 as the "almost
        // unchanged" boundary — this must agree with it, not invent a second
        // definition of negligible.
        let justBelow = ExplainItPrompt.macro(horizonBias: 0.0049)
        XCTAssertTrue(justBelow.isCorrect("Barely any effect"))

        let justAbove = ExplainItPrompt.macro(horizonBias: 0.0051)
        XCTAssertTrue(justAbove.isCorrect("Up"))
    }

    // MARK: - Explanation copy stays honest

    func testExplanationsNeverImplyAdvice() {
        let cases: [ExplainItPrompt] = [.disagreement(spread: 0.04), .macro(horizonBias: 0.02), .macro(horizonBias: 0)]
        for prompt in cases {
            XCTAssertFalse(prompt.explanation.lowercased().contains("buy"))
            XCTAssertFalse(prompt.explanation.lowercased().contains("sell"))
        }
    }
}
