//
//  ContentStoreTests.swift
//  BabyTrackerTests
//
//  Guards the ported content against silent regressions. The porter
//  (tools/port_content.py) had to repair two malformed spots in the Android
//  source markup, so these assertions pin the expected shape.
//

import XCTest
@testable import BabyTracker

final class ContentStoreTests: XCTestCase {

    func testWeeksDecodeWithExpectedShape() {
        let weeks = ContentStore.shared.weeks
        XCTAssertEqual(weeks.count, 45, "months.xml ported 45 week entries")

        for (i, week) in weeks.enumerated() {
            XCTAssertEqual(week.index, i, "week indices must be contiguous")
            XCTAssertFalse(week.title.isEmpty, "week \(i) lost its title")
            XCTAssertFalse(week.babyGrowth.isEmpty, "week \(i) has no growth article")
        }
    }

    /// Weeks 0...43 are four to a month; index 44 stands alone.
    func testWeekToMonthMapping() {
        let weeks = ContentStore.shared.weeks
        XCTAssertEqual(weeks[0].month, 0)
        XCTAssertEqual(weeks[3].month, 0)
        XCTAssertEqual(weeks[4].month, 1)
        XCTAssertEqual(weeks[43].month, 10)
        XCTAssertEqual(weeks[43].weeksInMonth, 4)
        XCTAssertTrue(weeks[44].isFinalEntry)
        XCTAssertEqual(weeks[44].weeksInMonth, 1)
    }

    /// Week 2's heading lost its opening <b> in the Android source; the porter
    /// restores it. Android renders it unbolded, so this is a deliberate fix.
    func testWeek2HeadingWasRepaired() {
        let headings = ContentStore.shared.weeks[2].babyGrowth
            .filter { $0.kind == .heading }
            .map(\.text)
        XCTAssertTrue(headings.contains("أمور جديرة بالانتباه"),
                      "the repaired heading should survive the port")
    }

    func testEveryMonthHasThreeTiers() {
        let skills = ContentStore.shared.skills
        XCTAssertEqual(skills.count, 12)

        for month in skills {
            XCTAssertEqual(month.tiers.count, 3,
                           "month \(month.month) must have three tiers")
            for tier in month.tiers {
                XCTAssertFalse(tier.title.isEmpty)
                XCTAssertFalse(tier.items.isEmpty,
                               "month \(month.month) tier '\(tier.title)' has no chips")
            }
        }
    }

    /// Month 7's middle tier is the one the stricter parser originally dropped.
    func testMonth7MiddleTierSurvived() {
        let month7 = ContentStore.shared.skills(forMonth: 7)
        XCTAssertNotNil(month7)
        XCTAssertEqual(month7?.tiers.count, 3)
        XCTAssertEqual(month7?.tiers[1].items.count, 3)
    }
}
