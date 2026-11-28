//
//  ChildStoreTests.swift
//  BabyTrackerTests
//
//  Pins the two promises multi-child rests on: an existing single-child
//  install keeps its data, and one child's reset cannot reach another's.
//

import XCTest
@testable import BabyTracker

final class ChildStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suite = "ChildStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Migration

    func testMigrationWrapsAnExistingInstallWithoutMovingItsData() {
        let birth = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(birth.timeIntervalSince1970, forKey: ChildStore.Keys.liveBirthDate)
        // A tick written by the single-child version, under an unprefixed key.
        defaults.set(true, forKey: "VAX_JOR_bcg_1")

        ChildStore.migrateIfNeeded(defaults)

        let children = ChildStore.all(defaults)
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.id, ChildStore.legacyId)
        XCTAssertEqual(
            children.first?.birthDate.timeIntervalSince1970 ?? 0,
            birth.timeIntervalSince1970,
            accuracy: 1
        )
        // The point of the empty prefix: the old key is still the live one.
        XCTAssertEqual(ChildStore.activePrefix(defaults), "")
        XCTAssertTrue(defaults.bool(forKey: "VAX_JOR_bcg_1"))
    }

    func testMigrationDoesNothingForABrandNewInstall() {
        ChildStore.migrateIfNeeded(defaults)
        XCTAssertTrue(ChildStore.all(defaults).isEmpty)
    }

    func testMigrationDoesNothingOnceChildrenExist() {
        _ = ChildStore.add(name: "سارة", birthDate: Date(), in: defaults)
        defaults.set(Date().timeIntervalSince1970, forKey: ChildStore.Keys.liveBirthDate)

        ChildStore.migrateIfNeeded(defaults)

        XCTAssertEqual(ChildStore.all(defaults).count, 1)
        XCTAssertEqual(ChildStore.all(defaults).first?.name, "سارة")
    }

    // MARK: - Identity

    func testFirstChildTakesTheLegacyIdAndLaterOnesDoNot() {
        let first = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        let second = ChildStore.add(name: "", birthDate: Date(), in: defaults)

        XCTAssertEqual(first.id, ChildStore.legacyId)
        XCTAssertNotEqual(second.id, ChildStore.legacyId)
        XCTAssertEqual(ChildStore.prefix(for: first), "")
        XCTAssertEqual(ChildStore.prefix(for: second), "C\(second.id)_")
    }

    func testActiveFallsBackToTheFirstChildWhenThePointerIsStale() {
        let first = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        defaults.set("a-child-that-was-removed", forKey: ChildStore.Keys.active)

        XCTAssertEqual(ChildStore.active(defaults)?.id, first.id)
        XCTAssertEqual(defaults.string(forKey: ChildStore.Keys.active), first.id)
    }

    // MARK: - Scoping

    func testResettingOneChildLeavesSiblingsAndSharedSettingsAlone() {
        let legacy = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        let sibling = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        let siblingPrefix = ChildStore.prefix(for: sibling)

        defaults.set(true, forKey: "VAX_JOR_bcg_1")
        defaults.set(true, forKey: "WR_SKILL_3_1_2")
        defaults.set(true, forKey: siblingPrefix + "VAX_JOR_bcg_1")
        defaults.set(true, forKey: siblingPrefix + "WR_SKILL_3_1_2")
        defaults.set("JOR", forKey: "VAX_COUNTRY")
        defaults.set(true, forKey: "VAX_COUNTRY_USER")
        defaults.set("{}", forKey: "VAX_CUSTOM_JOR")

        ChildStore.clearScopedData(prefix: ChildStore.prefix(for: legacy), in: defaults)

        XCTAssertFalse(defaults.bool(forKey: "VAX_JOR_bcg_1"))
        XCTAssertFalse(defaults.bool(forKey: "WR_SKILL_3_1_2"))
        XCTAssertTrue(defaults.bool(forKey: siblingPrefix + "VAX_JOR_bcg_1"))
        XCTAssertTrue(defaults.bool(forKey: siblingPrefix + "WR_SKILL_3_1_2"))
        // Country and the custom-vaccine library are family-wide settings.
        XCTAssertEqual(defaults.string(forKey: "VAX_COUNTRY"), "JOR")
        XCTAssertTrue(defaults.bool(forKey: "VAX_COUNTRY_USER"))
        XCTAssertEqual(defaults.string(forKey: "VAX_CUSTOM_JOR"), "{}")
    }

    func testRemovingAChildTakesTheirDataAndRepointsActive() {
        let legacy = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        let sibling = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        let siblingPrefix = ChildStore.prefix(for: sibling)
        ChildStore.setActive(sibling.id, in: defaults)
        defaults.set(true, forKey: siblingPrefix + "VAX_JOR_bcg_1")

        let nowActive = ChildStore.remove(sibling.id, in: defaults)

        XCTAssertEqual(nowActive, legacy.id)
        XCTAssertEqual(ChildStore.all(defaults).count, 1)
        XCTAssertFalse(defaults.bool(forKey: siblingPrefix + "VAX_JOR_bcg_1"))
    }

    func testStartingOverClearsEveryChildButKeepsTheSharedSettings() {
        _ = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        let sibling = ChildStore.add(name: "", birthDate: Date(), in: defaults)
        defaults.set(true, forKey: "WR_SKILL_1_0_0")
        defaults.set(true, forKey: ChildStore.prefix(for: sibling) + "WR_SKILL_1_0_0")
        defaults.set("JOR", forKey: "VAX_COUNTRY")
        defaults.set("{}", forKey: "VAX_CUSTOM_JOR")

        ChildStore.removeAll(in: defaults)

        XCTAssertTrue(ChildStore.all(defaults).isEmpty)
        XCTAssertNil(defaults.string(forKey: ChildStore.Keys.active))
        XCTAssertEqual(defaults.double(forKey: ChildStore.Keys.liveBirthDate), 0)
        XCTAssertFalse(defaults.bool(forKey: "WR_SKILL_1_0_0"))
        XCTAssertFalse(defaults.bool(forKey: ChildStore.prefix(for: sibling) + "WR_SKILL_1_0_0"))
        XCTAssertEqual(defaults.string(forKey: "VAX_COUNTRY"), "JOR")
        XCTAssertEqual(defaults.string(forKey: "VAX_CUSTOM_JOR"), "{}")
    }

    // MARK: - Mirror

    func testSwitchingChildrenMirrorsTheirBirthDate() {
        let older = ChildStore.add(
            name: "",
            birthDate: Date(timeIntervalSince1970: 1_600_000_000),
            in: defaults
        )
        let younger = ChildStore.add(
            name: "",
            birthDate: Date(timeIntervalSince1970: 1_700_000_000),
            in: defaults
        )

        ChildStore.setActive(younger.id, in: defaults)
        XCTAssertEqual(
            defaults.double(forKey: ChildStore.Keys.liveBirthDate),
            younger.birthDate.timeIntervalSince1970,
            accuracy: 1
        )

        ChildStore.setActive(older.id, in: defaults)
        XCTAssertEqual(
            defaults.double(forKey: ChildStore.Keys.liveBirthDate),
            older.birthDate.timeIntervalSince1970,
            accuracy: 1
        )
    }
}
