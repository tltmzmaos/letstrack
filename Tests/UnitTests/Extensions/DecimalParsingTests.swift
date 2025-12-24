import XCTest
@testable import LetsTrack

final class DecimalParsingTests: XCTestCase {
    func testParseLocalized_UsesCurrentLocale() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.maximumFractionDigits = 2

        let number = NSDecimalNumber(string: "1234.56")
        let localized = formatter.string(from: number)

        XCTAssertNotNil(localized)

        if let localizedString = localized {
            let parsed = Decimal.parseLocalized(localizedString)
            XCTAssertEqual(parsed, number.decimalValue)
        }
    }

    func testParseLocalized_FallbacksToDecimalString() {
        let parsed = Decimal.parseLocalized("9999")
        XCTAssertEqual(parsed, Decimal(9999))
    }
}
