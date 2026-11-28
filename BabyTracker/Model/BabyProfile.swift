//
//  BabyProfile.swift
//  BabyTracker
//
//  The active child and their birth date - the input the whole app derives
//  from.
//
//  One mother can follow several children (see ChildStore), but every screen
//  still reads a single `birthDate`: this object publishes the ACTIVE child's.
//  Switching children re-points what "active" means and republishes, so the
//  age, weeks, milestone and vaccine screens need no idea that siblings exist.
//

import Foundation
import SwiftUI

@MainActor
final class BabyProfile: ObservableObject {

    private let defaults: UserDefaults

    /// Every child, in the order they were added.
    @Published private(set) var children: [ChildStore.Child] = []

    /// Id of the child the app is currently showing.
    @Published private(set) var activeChildId: String?

    /// The active child's birth date.
    ///
    /// Read-only from outside; changes go through `setBirthDate`.
    ///
    /// This used to be a settable `@Published` with a `didSet` that persisted.
    /// Assigning through the property wrapper in `init` fires that observer, so
    /// the DEBUG screenshot seed was writing a fake birth date into UserDefaults
    /// - which then survived into later launches and skipped onboarding
    /// entirely. Persisting explicitly instead of as a side effect makes
    /// "load" and "save" impossible to confuse.
    @Published private(set) var birthDate: Date?

    /// A seeded date (DEBUG screenshot runs only) wins for the whole launch
    /// but is deliberately never written back.
    private let seededBirthDate: Date?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.seededBirthDate = ScreenshotSeed.birthDate

        // An install that predates multi-child has a birth date and no child
        // records. This wraps one around it before anything reads either.
        ChildStore.migrateIfNeeded(defaults)
        reload()
    }

    // MARK: - Reading

    var isOnboarded: Bool { birthDate != nil }

    /// Derived age, or nil until a birth date is set.
    var age: BabyAge? {
        birthDate.map { BabyAge(birthDate: $0) }
    }

    var activeChild: ChildStore.Child? {
        children.first { $0.id == activeChildId }
    }

    /// The namespace the per-child stores read and write under.
    var activeChildPrefix: String {
        ChildStore.prefix(for: activeChild)
    }

    var hasMultipleChildren: Bool { children.count > 1 }

    /// What to call a child: their name, or "طفلي" on its own when they are an
    /// only child, or "طفلي 2" by position once there are several.
    func label(for child: ChildStore.Child) -> String {
        let name = child.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        guard
            children.count > 1,
            let index = children.firstIndex(where: { $0.id == child.id })
        else { return L.childDefaultName }
        return "\(L.childDefaultName) \(String.number(index + 1))"
    }

    var activeChildLabel: String {
        activeChild.map(label(for:)) ?? L.childDefaultName
    }

    // MARK: - Writing

    /// Sets and persists the active child's birth date, creating the first
    /// child when there is none - which is what onboarding does on a brand-new
    /// install.
    func setBirthDate(_ date: Date?) {
        guard let date else {
            // Clearing the date is only meaningful with no children left; a
            // child always has one.
            birthDate = nil
            defaults.removeObject(forKey: ChildStore.Keys.liveBirthDate)
            return
        }

        if var child = activeChild {
            child.birthDate = date
            ChildStore.update(child, in: defaults)
            ChildStore.mirror(child, in: defaults)
        } else {
            let child = ChildStore.add(name: "", birthDate: date, in: defaults)
            ChildStore.setActive(child.id, in: defaults)
        }
        reload()
    }

    /// Adds a child and switches to them, which is what the add-child sheet
    /// wants: the mother is adding the baby she is about to look at.
    func addChild(name: String, birthDate: Date) {
        let child = ChildStore.add(name: name, birthDate: birthDate, in: defaults)
        ChildStore.setActive(child.id, in: defaults)
        reload()
    }

    func switchTo(childId: String) {
        guard childId != activeChildId else { return }
        ChildStore.setActive(childId, in: defaults)
        reload()
    }

    func rename(childId: String, to name: String) {
        guard var child = children.first(where: { $0.id == childId }) else { return }
        child.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        ChildStore.update(child, in: defaults)
        reload()
    }

    func removeChild(_ childId: String) {
        _ = ChildStore.remove(childId, in: defaults)
        reload()
    }

    /// Clears the active child's vaccine ticks and milestone checks, keeping
    /// the child and their birth date.
    ///
    /// Android relaunches its intro here. This does not: with siblings on file,
    /// dropping the whole app back to onboarding to reset one of them would
    /// throw away the context the mother is working in.
    func resetActiveChildProgress() {
        ChildStore.clearScopedData(prefix: activeChildPrefix, in: defaults)
        reload()
    }

    /// Removes every child and all their progress, which returns the app to
    /// its first-run state. The shared country and any custom vaccines stay.
    func removeAllChildren() {
        ChildStore.removeAll(in: defaults)
        reload()
    }

    // MARK: - Internals

    private func reload() {
        children = ChildStore.all(defaults)
        activeChildId = ChildStore.active(defaults)?.id

        if let seededBirthDate {
            birthDate = seededBirthDate
            return
        }
        birthDate = ChildStore.active(defaults)?.birthDate
    }
}
