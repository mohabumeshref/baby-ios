//
//  BabyAgeTests.swift
//  BabyTrackerTests
//
//  Pins the age arithmetic against the Android implementation, including the
//  8.111-days-per-entry content index that looks like a bug but isn't.
//

import XCTest
@testable import BabyTracker

final class BabyAgeTests: XCTestCase {

    private let calendar = Calendar.current

    private func age(daysOld: Int) -> BabyAge {
        let now = Date()
        let birth = calendar.date(byAdding: .day, value: -daysOld, to: now)!
        return BabyAge(birthDate: birth, now: now)
    }

    // MARK: - Days

    /// Android clamps a zero-day difference up to 1, so a baby born today
    /// reads as one day old rather than zero.
    func testNewbornReadsAsOneDay() {
        XCTAssertEqual(age(daysOld: 0).days, 1)
    }

    func testDayCount() {
        XCTAssertEqual(age(daysOld: 1).days, 1)
        XCTAssertEqual(age(daysOld: 45).days, 45)
        XCTAssertEqual(age(daysOld: 365).days, 365)
    }

    // MARK: - Weeks shown to the parent (days / 7)

    func testDisplayedWeeks() {
        XCTAssertEqual(age(daysOld: 6).weeks, 0)
        XCTAssertEqual(age(daysOld: 7).weeks, 1)
        XCTAssertEqual(age(daysOld: 13).weeks, 1)
        XCTAssertEqual(age(daysOld: 14).weeks, 2)
    }

    // MARK: - Content index (days / 8.111…)

    /// This divisor spreads 365 days across the 45 entries in weeks.json. It is
    /// deliberately NOT days/7 - see the note in BabyAge.
    func testContentWeekIndexUsesAndroidDivisor() {
        XCTAssertEqual(age(daysOld: 1).contentWeekIndex, 0)
        XCTAssertEqual(age(daysOld: 8).contentWeekIndex, 0)
        XCTAssertEqual(age(daysOld: 9).contentWeekIndex, 1)
        XCTAssertEqual(age(daysOld: 17).contentWeekIndex, 2)
        XCTAssertEqual(age(daysOld: 81).contentWeekIndex, 9)
    }

    /// A full year must land on the final entry, and nothing may exceed it.
    func testContentWeekIndexClampsToFinalEntry() {
        XCTAssertEqual(age(daysOld: 365).contentWeekIndex, 44)
        XCTAssertEqual(age(daysOld: 900).contentWeekIndex, 44)
        XCTAssertLessThanOrEqual(age(daysOld: 5000).contentWeekIndex, BabyAge.maxContentWeekIndex)
    }

    /// Every index the arithmetic can produce must exist in weeks.json.
    func testEveryReachableIndexHasContent() {
        let store = ContentStore.shared
        for days in stride(from: 1, through: 400, by: 1) {
            let index = age(daysOld: days).contentWeekIndex
            XCTAssertNotNil(store.week(at: index),
                            "day \(days) maps to missing week index \(index)")
        }
    }

    // MARK: - Months

    func testMonthsElapsed() {
        let now = Date()
        for expected in 0...11 {
            let birth = calendar.date(byAdding: .month, value: -expected, to: now)!
            XCTAssertEqual(BabyAge(birthDate: birth, now: now).months, expected)
        }
    }

    /// The month must not tick over until the birth day-of-month is reached -
    /// the behaviour Android's `if (a > 0 && _day > d) a -= 1` implemented.
    func testMonthDoesNotAdvanceEarly() {
        let birth = DateComponents(calendar: calendar, year: 2026, month: 1, day: 20).date!
        let dayBefore = DateComponents(calendar: calendar, year: 2026, month: 2, day: 19).date!
        let onTheDay = DateComponents(calendar: calendar, year: 2026, month: 2, day: 20).date!

        XCTAssertEqual(BabyAge(birthDate: birth, now: dayBefore).months, 0)
        XCTAssertEqual(BabyAge(birthDate: birth, now: onTheDay).months, 1)
    }

    func testMilestoneMonthStaysInRange() {
        let birth = calendar.date(byAdding: .year, value: -4, to: Date())!
        let age = BabyAge(birthDate: birth)
        XCTAssertFalse(age.hasMilestones)
        XCTAssertEqual(age.milestoneMonth, 11, "must clamp into the 0...11 skills range")
    }

    // MARK: - Numerals

    /// Arabic UI, Western digits - and never Eastern Arabic numerals, which is
    /// what a locale-following formatter would emit on an Arabic device.
    func testNumbersUseWesternDigits() {
        XCTAssertEqual(String.number(0), "0")
        XCTAssertEqual(String.number(45), "45")
        XCTAssertEqual(String.number(1234), "1234")
    }
}
