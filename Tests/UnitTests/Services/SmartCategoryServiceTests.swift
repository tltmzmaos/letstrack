import XCTest
import SwiftData
@testable import LetsTrack

typealias TestCategory = LetsTrack.Category

@MainActor
final class SmartCategoryServiceTests: XCTestCase {
    var service: SmartCategoryService!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testCategories: [TestCategory]!

    override func setUpWithError() throws {
        service = SmartCategoryService.shared
        service.clearLearnedPatterns()

        let schema = Schema([TestCategory.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = modelContainer.mainContext

        // Create test categories
        testCategories = [
            TestCategory(name: "Food", icon: "fork.knife", colorHex: "#FF9500", type: .expense),
            TestCategory(name: "Transport", icon: "car.fill", colorHex: "#007AFF", type: .expense),
            TestCategory(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", type: .expense),
            TestCategory(name: "Entertainment", icon: "gamecontroller.fill", colorHex: "#5856D6", type: .expense),
            TestCategory(name: "Medical", icon: "cross.case.fill", colorHex: "#34C759", type: .expense),
            TestCategory(name: "Salary", icon: "banknote.fill", colorHex: "#00C853", type: .income)
        ]
        testCategories.forEach { modelContext.insert($0) }
        try modelContext.save()
    }

    override func tearDownWithError() throws {
        service.clearLearnedPatterns()
        testCategories = nil
        modelContainer = nil
        modelContext = nil
    }

    // MARK: - Korean Keyword Tests

    func testSuggestCategory_KoreanFoodKeyword_Starbucks() {
        let result = service.suggestCategory(for: "스타벅스 아메리카노", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Food")
    }

    func testSuggestCategory_KoreanFoodKeyword_Cafe() {
        let result = service.suggestCategory(for: "카페에서 커피", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.icon, "fork.knife")
    }

    func testSuggestCategory_KoreanFoodKeyword_Delivery() {
        let result = service.suggestCategory(for: "배달의민족 치킨", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Food")
    }

    func testSuggestCategory_KoreanTransportKeyword_Taxi() {
        let result = service.suggestCategory(for: "카카오택시", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Transport")
    }

    func testSuggestCategory_KoreanTransportKeyword_Subway() {
        let result = service.suggestCategory(for: "지하철 요금", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.icon, "car.fill")
    }

    func testSuggestCategory_KoreanShoppingKeyword() {
        let result = service.suggestCategory(for: "쿠팡에서 쇼핑", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Shopping")
    }

    func testSuggestCategory_KoreanEntertainmentKeyword_Netflix() {
        let result = service.suggestCategory(for: "넷플릭스 구독", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Entertainment")
    }

    func testSuggestCategory_KoreanMedicalKeyword() {
        let result = service.suggestCategory(for: "병원 진료비", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Medical")
    }

    func testSuggestCategory_KoreanIncomeKeyword() {
        let result = service.suggestCategory(for: "12월 급여", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Salary")
    }

    // MARK: - English Keyword Tests

    func testSuggestCategory_EnglishFoodKeyword_Starbucks() {
        let result = service.suggestCategory(for: "Starbucks coffee", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Food")
    }

    func testSuggestCategory_EnglishFoodKeyword_Lunch() {
        let result = service.suggestCategory(for: "Lunch with team", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.icon, "fork.knife")
    }

    func testSuggestCategory_EnglishTransportKeyword_Uber() {
        let result = service.suggestCategory(for: "Uber ride", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Transport")
    }

    func testSuggestCategory_EnglishShoppingKeyword_Amazon() {
        let result = service.suggestCategory(for: "Amazon order", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Shopping")
    }

    func testSuggestCategory_EnglishEntertainmentKeyword_Netflix() {
        let result = service.suggestCategory(for: "Netflix subscription", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Entertainment")
    }

    func testSuggestCategory_EnglishIncomeKeyword_Salary() {
        let result = service.suggestCategory(for: "Monthly salary", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Salary")
    }

    // MARK: - Case Insensitivity Tests

    func testSuggestCategory_CaseInsensitive_Uppercase() {
        let result = service.suggestCategory(for: "STARBUCKS", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Food")
    }

    func testSuggestCategory_CaseInsensitive_MixedCase() {
        let result = service.suggestCategory(for: "NetFlix Premium", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Entertainment")
    }

    // MARK: - No Match Tests

    func testSuggestCategory_NoMatch_ReturnsNil() {
        let result = service.suggestCategory(for: "random text here", from: testCategories)
        XCTAssertNil(result)
    }

    func testSuggestCategory_EmptyNote_ReturnsNil() {
        let result = service.suggestCategory(for: "", from: testCategories)
        XCTAssertNil(result)
    }

    func testSuggestCategory_EmptyCategories_ReturnsNil() {
        let result = service.suggestCategory(for: "스타벅스", from: [])
        XCTAssertNil(result)
    }

    // MARK: - Learning Tests

    func testLearnFromSelection_AddsPattern() {
        let category = testCategories.first { $0.name == "Food" }!

        service.learnFromSelection(note: "점심회식", category: category)

        let patterns = service.getLearnedPatterns()
        XCTAssertTrue(patterns.keys.contains("점심회식"))
        XCTAssertEqual(patterns["점심회식"], "fork.knife")
    }

    func testLearnFromSelection_MultipleWords() {
        let category = testCategories.first { $0.name == "Entertainment" }!

        service.learnFromSelection(note: "monthly gym membership", category: category)

        let patterns = service.getLearnedPatterns()
        XCTAssertTrue(patterns.keys.contains("monthly"))
        XCTAssertTrue(patterns.keys.contains("membership"))
    }

    func testLearnFromSelection_IgnoresShortWords() {
        let category = testCategories.first { $0.name == "Food" }!

        service.learnFromSelection(note: "a", category: category)

        let patterns = service.getLearnedPatterns()
        XCTAssertFalse(patterns.keys.contains("a"))
    }

    func testLearnFromSelection_DoesNotOverrideBuiltIn() {
        let transportCategory = testCategories.first { $0.name == "Transport" }!
        let originalCategory = service.suggestCategory(for: "스타벅스", from: testCategories)

        service.learnFromSelection(note: "스타벅스", category: transportCategory)

        // Should still suggest Food (built-in) not Transport (learned)
        let afterLearning = service.suggestCategory(for: "스타벅스", from: testCategories)
        XCTAssertEqual(originalCategory?.name, afterLearning?.name)
    }

    func testLearnedPatternHasPriority() {
        let shoppingCategory = testCategories.first { $0.name == "Shopping" }!

        // Learn that "mystore" is shopping
        service.learnFromSelection(note: "mystore purchase", category: shoppingCategory)

        let result = service.suggestCategory(for: "mystore", from: testCategories)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.name, "Shopping")
    }

    // MARK: - Clear Patterns Tests

    func testClearLearnedPatterns() {
        let category = testCategories.first { $0.name == "Food" }!

        service.learnFromSelection(note: "testpattern", category: category)
        XCTAssertFalse(service.getLearnedPatterns().isEmpty)

        service.clearLearnedPatterns()
        XCTAssertTrue(service.getLearnedPatterns().isEmpty)
    }

    // MARK: - Persistence Tests

    func testUserPatternsPersistence() {
        let category = testCategories.first { $0.name == "Food" }!

        service.learnFromSelection(note: "persisttest", category: category)

        // Reload patterns
        service.loadUserPatterns()

        let patterns = service.getLearnedPatterns()
        XCTAssertTrue(patterns.keys.contains("persisttest"))
    }
}
