import XCTest
@testable import LetsTrack

@MainActor
final class VoiceTransactionServiceTests: XCTestCase {
    var service: VoiceTransactionService!

    override func setUpWithError() throws {
        service = VoiceTransactionService.shared
    }

    override func tearDownWithError() throws {
        service = nil
    }

    // MARK: - Transaction Type Detection Tests

    func testParseVoiceInput_Expense_Default() {
        let result = service.parseVoiceInput("스타벅스에서 커피 5000원")
        XCTAssertEqual(result.type, .expense)
    }

    func testParseVoiceInput_Income_Korean_수입() {
        let result = service.parseVoiceInput("수입 100만원")
        XCTAssertEqual(result.type, .income)
    }

    func testParseVoiceInput_Income_Korean_월급() {
        let result = service.parseVoiceInput("월급 300만원 받았다")
        XCTAssertEqual(result.type, .income)
    }

    func testParseVoiceInput_Income_Korean_용돈() {
        let result = service.parseVoiceInput("용돈 5만원")
        XCTAssertEqual(result.type, .income)
    }

    func testParseVoiceInput_Income_English() {
        let result = service.parseVoiceInput("income 5000 dollars")
        XCTAssertEqual(result.type, .income)
    }

    // MARK: - Korean Amount Extraction Tests

    func testParseVoiceInput_Amount_Korean_만원() {
        let result = service.parseVoiceInput("점심 1만원")
        XCTAssertEqual(result.amount, 10000)
    }

    func testParseVoiceInput_Amount_Korean_천원() {
        let result = service.parseVoiceInput("커피 5천원")
        XCTAssertEqual(result.amount, 5000)
    }

    func testParseVoiceInput_Amount_Korean_Combined() {
        let result = service.parseVoiceInput("10만5천원 썼어")
        XCTAssertEqual(result.amount, 105000)
    }

    func testParseVoiceInput_Amount_Korean_백만() {
        let result = service.parseVoiceInput("월급 3백만원")
        XCTAssertEqual(result.amount, 3000000)
    }

    func testParseVoiceInput_Amount_Korean_천만() {
        let result = service.parseVoiceInput("차량 구매 2천만원")
        XCTAssertEqual(result.amount, 20000000)
    }

    func testParseVoiceInput_Amount_Korean_억() {
        let result = service.parseVoiceInput("집 계약금 1억원")
        XCTAssertEqual(result.amount, 100000000)
    }

    func testParseVoiceInput_Amount_Simple_Number() {
        let result = service.parseVoiceInput("5000원 사용")
        XCTAssertEqual(result.amount, 5000)
    }

    func testParseVoiceInput_Amount_English_Number() {
        let result = service.parseVoiceInput("spent 50 dollars")
        XCTAssertEqual(result.amount, 50)
    }

    func testParseVoiceInput_Amount_NoAmount() {
        let result = service.parseVoiceInput("카페에서 커피 마심")
        XCTAssertNil(result.amount)
    }

    // MARK: - Date Extraction Tests

    func testParseVoiceInput_Date_오늘() {
        let result = service.parseVoiceInput("오늘 점심 1만원")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(result.date!))
    }

    func testParseVoiceInput_Date_어제() {
        let result = service.parseVoiceInput("어제 저녁 2만원")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInYesterday(result.date!))
    }

    func testParseVoiceInput_Date_그제() {
        let result = service.parseVoiceInput("그제 커피 5천원")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertTrue(calendar.isDate(result.date!, inSameDayAs: twoDaysAgo))
    }

    func testParseVoiceInput_Date_일주일전() {
        let result = service.parseVoiceInput("일주일전 쇼핑 10만원")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        XCTAssertTrue(calendar.isDate(result.date!, inSameDayAs: weekAgo))
    }

    func testParseVoiceInput_Date_English_Today() {
        let result = service.parseVoiceInput("today spent 50 dollars")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(result.date!))
    }

    func testParseVoiceInput_Date_English_Yesterday() {
        let result = service.parseVoiceInput("yesterday lunch 15 dollars")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInYesterday(result.date!))
    }

    func testParseVoiceInput_Date_Default_Today() {
        let result = service.parseVoiceInput("커피 5천원")
        XCTAssertNotNil(result.date)

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInToday(result.date!))
    }

    // MARK: - Category Keyword Extraction Tests

    func testParseVoiceInput_Category_Korean_Food() {
        let foodKeywords = ["커피", "카페", "밥", "점심", "저녁", "치킨", "피자", "편의점", "마트", "배달"]

        for keyword in foodKeywords {
            let result = service.parseVoiceInput("\(keyword) 1만원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "food", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_Korean_Transport() {
        let transportKeywords = ["택시", "버스", "지하철", "교통", "주유"]

        for keyword in transportKeywords {
            let result = service.parseVoiceInput("\(keyword) 5천원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "transport", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_Korean_Shopping() {
        let result = service.parseVoiceInput("백화점에서 쇼핑 10만원")
        XCTAssertEqual(result.suggestedCategoryKeyword, "shopping")
    }

    func testParseVoiceInput_Category_Korean_Housing() {
        let housingKeywords = ["월세", "관리비", "전기세", "가스"]

        for keyword in housingKeywords {
            let result = service.parseVoiceInput("\(keyword) 50만원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "housing", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_Korean_Medical() {
        let medicalKeywords = ["병원", "약", "의료"]

        for keyword in medicalKeywords {
            let result = service.parseVoiceInput("\(keyword) 3만원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "medical", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_Korean_Education() {
        let educationKeywords = ["학원", "교육", "책"]

        for keyword in educationKeywords {
            let result = service.parseVoiceInput("\(keyword) 10만원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "education", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_Korean_Entertainment() {
        let entertainmentKeywords = ["영화", "게임", "노래방"]

        for keyword in entertainmentKeywords {
            let result = service.parseVoiceInput("\(keyword) 2만원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "entertainment", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_Korean_Salary() {
        let salaryKeywords = ["월급", "급여", "보너스"]

        for keyword in salaryKeywords {
            let result = service.parseVoiceInput("\(keyword) 300만원")
            XCTAssertEqual(result.suggestedCategoryKeyword, "salary", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_English_Food() {
        let foodKeywords = ["coffee", "cafe", "lunch", "dinner", "breakfast", "grocery"]

        for keyword in foodKeywords {
            let result = service.parseVoiceInput("\(keyword) 50 dollars")
            XCTAssertEqual(result.suggestedCategoryKeyword, "food", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_English_Transport() {
        let transportKeywords = ["taxi", "bus", "subway", "gas"]

        for keyword in transportKeywords {
            let result = service.parseVoiceInput("\(keyword) 30 dollars")
            XCTAssertEqual(result.suggestedCategoryKeyword, "transport", "Failed for keyword: \(keyword)")
        }
    }

    func testParseVoiceInput_Category_English_Shopping() {
        let result = service.parseVoiceInput("shopping at mall 100 dollars")
        XCTAssertEqual(result.suggestedCategoryKeyword, "shopping")
    }

    func testParseVoiceInput_Category_NoMatch() {
        let result = service.parseVoiceInput("random text 5000")
        XCTAssertNil(result.suggestedCategoryKeyword)
    }

    // MARK: - Note Extraction Tests

    func testParseVoiceInput_Note_ContainsOriginalText() {
        let result = service.parseVoiceInput("스타벅스 아메리카노")
        XCTAssertNotNil(result.note)
        XCTAssertTrue(result.note!.contains("스타벅스"))
    }

    func testParseVoiceInput_Note_RemovesDateWords() {
        let result = service.parseVoiceInput("오늘 스타벅스 커피")
        XCTAssertNotNil(result.note)
        XCTAssertFalse(result.note!.contains("오늘"))
    }

    // MARK: - Validation Tests

    func testParsedTransaction_IsValid_WithAmount() {
        let result = service.parseVoiceInput("커피 5천원")
        XCTAssertTrue(result.isValid)
    }

    func testParsedTransaction_IsInvalid_WithoutAmount() {
        let result = service.parseVoiceInput("커피 마심")
        XCTAssertFalse(result.isValid)
    }

    func testParsedTransaction_IsInvalid_ZeroAmount() {
        let result = service.parseVoiceInput("커피 0원")
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Complex Input Tests

    func testParseVoiceInput_ComplexKorean() {
        let result = service.parseVoiceInput("어제 친구랑 치킨 배달시켜서 2만5천원 썼어")

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 25000)
        XCTAssertEqual(result.suggestedCategoryKeyword, "food")

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInYesterday(result.date!))
    }

    func testParseVoiceInput_ComplexEnglish() {
        let result = service.parseVoiceInput("yesterday had lunch with team for 75 dollars")

        XCTAssertEqual(result.type, .expense)
        XCTAssertEqual(result.amount, 75)
        XCTAssertEqual(result.suggestedCategoryKeyword, "food")

        let calendar = Calendar.current
        XCTAssertTrue(calendar.isDateInYesterday(result.date!))
    }

    func testParseVoiceInput_Income_Complex() {
        let result = service.parseVoiceInput("이번 달 월급 받아서 수입 350만원")

        XCTAssertEqual(result.type, .income)
        XCTAssertEqual(result.amount, 3500000)
        XCTAssertEqual(result.suggestedCategoryKeyword, "salary")
    }
}

// MARK: - Voice Error Tests

final class VoiceErrorTests: XCTestCase {
    func testVoiceError_NotAvailable_HasDescription() {
        let error = VoiceError.notAvailable
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testVoiceError_NotAuthorized_HasDescription() {
        let error = VoiceError.notAuthorized
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testVoiceError_RequestCreationFailed_HasDescription() {
        let error = VoiceError.requestCreationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testVoiceError_RecognitionFailed_HasDescription() {
        let error = VoiceError.recognitionFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }
}

// MARK: - Parsed Transaction Tests

final class ParsedTransactionTests: XCTestCase {
    func testParsedTransaction_DefaultType_IsExpense() {
        let transaction = ParsedTransaction()
        XCTAssertEqual(transaction.type, .expense)
    }

    func testParsedTransaction_IsValid_RequiresPositiveAmount() {
        var transaction = ParsedTransaction()
        transaction.amount = 1000
        XCTAssertTrue(transaction.isValid)

        transaction.amount = 0
        XCTAssertFalse(transaction.isValid)

        transaction.amount = -100
        XCTAssertFalse(transaction.isValid)

        transaction.amount = nil
        XCTAssertFalse(transaction.isValid)
    }
}
