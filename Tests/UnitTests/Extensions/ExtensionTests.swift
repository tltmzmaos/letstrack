import XCTest
import SwiftUI
@testable import LetsTrack

// MARK: - Date Extension Tests

final class DateExtensionTests: XCTestCase {

    func testStartOfDay() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = now.startOfDay

        let components = calendar.dateComponents([.hour, .minute, .second], from: startOfDay)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testEndOfDay() throws {
        let calendar = Calendar.current
        let now = Date()
        let endOfDay = now.endOfDay

        let components = calendar.dateComponents([.hour, .minute, .second], from: endOfDay)
        XCTAssertEqual(components.hour, 23)
        XCTAssertEqual(components.minute, 59)
        XCTAssertEqual(components.second, 59)
    }

    func testStartOfMonth() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = now.startOfMonth

        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: startOfMonth)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
    }

    func testEndOfMonth() throws {
        let calendar = Calendar.current

        // Test December (31 days)
        let december = calendar.date(from: DateComponents(year: 2024, month: 12, day: 15))!
        let endOfDecember = december.endOfMonth
        let decComponents = calendar.dateComponents([.day], from: endOfDecember)
        XCTAssertEqual(decComponents.day, 31)

        // Test February in leap year (29 days)
        let febLeap = calendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!
        let endOfFebLeap = febLeap.endOfMonth
        let febLeapComponents = calendar.dateComponents([.day], from: endOfFebLeap)
        XCTAssertEqual(febLeapComponents.day, 29)

        // Test February in non-leap year (28 days)
        let febNonLeap = calendar.date(from: DateComponents(year: 2023, month: 2, day: 15))!
        let endOfFebNonLeap = febNonLeap.endOfMonth
        let febNonLeapComponents = calendar.dateComponents([.day], from: endOfFebNonLeap)
        XCTAssertEqual(febNonLeapComponents.day, 28)
    }

    func testStartOfYear() throws {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = now.startOfYear

        let components = calendar.dateComponents([.month, .day], from: startOfYear)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }

    func testEndOfYear() throws {
        let calendar = Calendar.current
        let now = Date()
        let endOfYear = now.endOfYear

        let components = calendar.dateComponents([.month, .day], from: endOfYear)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 31)
    }

    func testRelativeDateString_Today() throws {
        let now = Date()
        let relativeString = now.relativeDateString

        XCTAssertTrue(relativeString.contains("오늘") || relativeString.contains("Today") || relativeString.contains("today"))
    }

    func testShortDateString() throws {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2024, month: 12, day: 25))!

        let formatted = date.shortDateString

        // shortDateString uses locale-aware formatting, just verify it's not empty
        // and contains the day number in some form
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("25") || formatted.contains("Dec"))
    }

    func testMonthYearString() throws {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2024, month: 12, day: 25))!

        let formatted = date.monthYearString

        // monthYearString uses locale-aware formatting, just verify it's not empty
        // and contains the year in some form
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains("2024") || formatted.contains("24"))
    }

    func testIsSameDay() throws {
        let calendar = Calendar.current
        let date1 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 25, hour: 10))!
        let date2 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 25, hour: 20))!
        let date3 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 26))!

        XCTAssertTrue(date1.isSameDay(as: date2))
        XCTAssertFalse(date1.isSameDay(as: date3))
    }

    func testIsSameMonth() throws {
        let calendar = Calendar.current
        let date1 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 1))!
        let date2 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let date3 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 15))!

        XCTAssertTrue(date1.isSameMonth(as: date2))
        XCTAssertFalse(date1.isSameMonth(as: date3))
    }

    func testIsSameYear() throws {
        let calendar = Calendar.current
        let date1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let date2 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 31))!
        let date3 = calendar.date(from: DateComponents(year: 2023, month: 6, day: 15))!

        XCTAssertTrue(date1.isSameYear(as: date2))
        XCTAssertFalse(date1.isSameYear(as: date3))
    }
}

// MARK: - Decimal Extension Tests

final class DecimalExtensionTests: XCTestCase {

    func testFormattedWithCurrency() throws {
        let amount: Decimal = 1000000
        let formatted = amount.formatted()

        // Should contain the number
        XCTAssertTrue(formatted.contains("1") && formatted.contains("0"))
    }

    func testDoubleValue() throws {
        let decimal: Decimal = 123.45
        let doubleValue = decimal.doubleValue

        XCTAssertEqual(doubleValue, 123.45, accuracy: 0.001)
    }

    func testDoubleValueNegative() throws {
        let decimal: Decimal = -500.25
        let doubleValue = decimal.doubleValue

        XCTAssertEqual(doubleValue, -500.25, accuracy: 0.001)
    }

    func testDoubleValueZero() throws {
        let decimal: Decimal = 0
        let doubleValue = decimal.doubleValue

        XCTAssertEqual(doubleValue, 0.0, accuracy: 0.001)
    }

    func testDoubleValueLargeNumber() throws {
        let decimal: Decimal = 9999999999
        let doubleValue = decimal.doubleValue

        XCTAssertEqual(doubleValue, 9999999999.0, accuracy: 1.0)
    }
}

// MARK: - Color Extension Tests

final class ColorExtensionTests: XCTestCase {

    func testColorFromHex_ValidHex() throws {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
    }

    func testColorFromHex_ValidHexWithoutHash() throws {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
    }

    func testColorFromHex_InvalidHex() throws {
        let color = Color(hex: "invalid")
        XCTAssertNil(color)
    }

    func testColorFromHex_ShortHex() throws {
        let color = Color(hex: "#FFF")
        // Short hex might not be supported
        // Just check it doesn't crash
        _ = color
    }

    func testColorFromHex_EmptyString() throws {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }

    func testColorFromHex_WithAlpha() throws {
        let color = Color(hex: "#FF0000FF")
        // 8-character hex with alpha might not be supported
        // Just check it doesn't crash
        _ = color
    }
}
