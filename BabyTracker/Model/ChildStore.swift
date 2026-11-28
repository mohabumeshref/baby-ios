//
//  ChildStore.swift
//  BabyTracker
//
//  Where the family's children live on disk.
//
//  A mirror layer, so the rest of the app stays single-child: one child is
//  ACTIVE, and the live keys the existing screens read always hold that
//  child's values. Switching re-points "active" and re-mirrors; nothing else
//  in the app has to know that more than one child exists.
//
//  Per-child data that must not collide - vaccine ticks and milestone checks -
//  is namespaced by `prefix`. The first child keeps id "0" and an EMPTY
//  prefix, so an existing single-child install keeps every key it already
//  wrote and needs no migration of data, only a record wrapped around it.
//
//  What is NOT per child: the vaccine country and the custom-vaccine overlay.
//  Those are family-wide - a mother does not live in two countries, and her
//  edits to the schedule are a library rather than a child's progress.
//
//  Plain functions over UserDefaults rather than an ObservableObject:
//  `BabyProfile` is the one published source of truth, and a second
//  observable holding the same facts would need keeping in sync with it.
//

import Foundation

enum ChildStore {

    struct Child: Codable, Identifiable, Hashable {
        var id: String
        var name: String
        var birthDate: Date
        /// Index into the switcher's tint palette, not a colour value, so the
        /// palette can change without rewriting stored records.
        var colorIndex: Int
    }

    enum Keys {
        static let list = "CHILDREN"
        static let active = "ACTIVE_CHILD_ID"
        /// The live birth date, written by the single-child code since the
        /// first version. It is the mirror: always the active child's date.
        static let liveBirthDate = "baby_birth_date"
    }

    /// The first child's id. Its prefix is empty, which is what makes an
    /// existing install's data carry over untouched.
    static let legacyId = "0"

    /// Family-wide keys a per-child wipe must never touch, even though they
    /// share the "VAX_" prefix.
    private static let sharedVaccineKeys = ["VAX_COUNTRY", "VAX_COUNTRY_USER"]

    // MARK: - List

    static func all(_ defaults: UserDefaults) -> [Child] {
        guard
            let data = defaults.data(forKey: Keys.list),
            let decoded = try? JSONDecoder().decode([Child].self, from: data)
        else { return [] }
        return decoded
    }

    static func saveAll(_ children: [Child], in defaults: UserDefaults) {
        guard let encoded = try? JSONEncoder().encode(children) else { return }
        defaults.set(encoded, forKey: Keys.list)
    }

    // MARK: - Active

    /// The active child, falling back to the first one when the pointer is
    /// stale - a child can be removed on one launch and pointed at on the next.
    static func active(_ defaults: UserDefaults) -> Child? {
        let children = all(defaults)
        guard !children.isEmpty else { return nil }
        if let id = defaults.string(forKey: Keys.active),
           let match = children.first(where: { $0.id == id }) {
            return match
        }
        defaults.set(children[0].id, forKey: Keys.active)
        return children[0]
    }

    static func setActive(_ id: String, in defaults: UserDefaults) {
        guard let child = all(defaults).first(where: { $0.id == id }) else { return }
        defaults.set(id, forKey: Keys.active)
        mirror(child, in: defaults)
    }

    /// Copies the active child's birth date into the live key. The country is
    /// deliberately absent: it is shared, so switching children must not
    /// change it.
    static func mirror(_ child: Child, in defaults: UserDefaults) {
        defaults.set(child.birthDate.timeIntervalSince1970, forKey: Keys.liveBirthDate)
    }

    // MARK: - Writing

    /// Appends a child and returns it. The first one gets the legacy id, so a
    /// brand-new install and an upgraded one end up with the same key layout.
    static func add(
        name: String,
        birthDate: Date,
        in defaults: UserDefaults
    ) -> Child {
        var children = all(defaults)
        let child = Child(
            id: children.isEmpty ? legacyId : newId(notIn: children),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDate: birthDate,
            colorIndex: children.count
        )
        children.append(child)
        saveAll(children, in: defaults)
        return child
    }

    /// Random rather than a timestamp, which is what Android uses: two adds
    /// inside the same millisecond would share an id, and an id is what a
    /// child's whole namespace is built from.
    private static func newId(notIn children: [Child]) -> String {
        var candidate = String(UUID().uuidString.prefix(8))
        while children.contains(where: { $0.id == candidate }) {
            candidate = String(UUID().uuidString.prefix(8))
        }
        return candidate
    }

    static func update(_ child: Child, in defaults: UserDefaults) {
        var children = all(defaults)
        guard let index = children.firstIndex(where: { $0.id == child.id }) else { return }
        children[index] = child
        saveAll(children, in: defaults)
    }

    /// Removes a child with its scoped data and returns whoever is active
    /// afterwards, or nil once none are left.
    static func remove(_ id: String, in defaults: UserDefaults) -> String? {
        var children = all(defaults)
        guard let index = children.firstIndex(where: { $0.id == id }) else {
            return defaults.string(forKey: Keys.active)
        }
        let removed = children.remove(at: index)
        clearScopedData(prefix: prefix(for: removed), in: defaults)
        saveAll(children, in: defaults)

        guard let first = children.first else {
            defaults.removeObject(forKey: Keys.active)
            defaults.removeObject(forKey: Keys.liveBirthDate)
            return nil
        }

        let current = defaults.string(forKey: Keys.active)
        let nextId = (current == id || current == nil) ? first.id : current!
        setActive(nextId, in: defaults)
        return nextId
    }

    /// Everyone goes, with all their progress, and the app is back to a
    /// first-run state. The shared country and the custom-vaccine overlay
    /// stay: they are settings, not a child's history.
    static func removeAll(in defaults: UserDefaults) {
        for child in all(defaults) {
            clearScopedData(prefix: prefix(for: child), in: defaults)
        }
        defaults.removeObject(forKey: Keys.list)
        defaults.removeObject(forKey: Keys.active)
        defaults.removeObject(forKey: Keys.liveBirthDate)
    }

    // MARK: - Key scoping

    static func prefix(for child: Child?) -> String {
        guard let child, child.id != legacyId else { return "" }
        return "C\(child.id)_"
    }

    static func activePrefix(_ defaults: UserDefaults) -> String {
        prefix(for: active(defaults))
    }

    /// Wipes one child's vaccine ticks and milestone checks, and nothing else.
    ///
    /// Note the empty-prefix case: "VAX_" and "WR_SKILL_" match the legacy
    /// child's keys, while a sibling's "C17..._VAX_" begins with neither, so a
    /// legacy wipe cannot reach another child's data.
    static func clearScopedData(prefix: String, in defaults: UserDefaults) {
        let doomed = defaults.dictionaryRepresentation().keys.filter { key in
            if sharedVaccineKeys.contains(key) { return false }
            if key.hasPrefix("VAX_CUSTOM_") { return false }
            return key.hasPrefix(prefix + "VAX_") || key.hasPrefix(prefix + "WR_SKILL_")
        }
        for key in doomed { defaults.removeObject(forKey: key) }
    }

    // MARK: - Migration

    /// Wraps an existing single-child install into child "0", once.
    ///
    /// No-op for a brand-new user - onboarding creates their first child - and
    /// no-op once a list exists. Nothing is copied or renamed: the record
    /// simply names the data that is already there.
    static func migrateIfNeeded(_ defaults: UserDefaults) {
        guard all(defaults).isEmpty else { return }
        let stored = defaults.double(forKey: Keys.liveBirthDate)
        guard stored > 0 else { return }

        let child = Child(
            id: legacyId,
            name: "",
            birthDate: Date(timeIntervalSince1970: stored),
            colorIndex: 0
        )
        saveAll([child], in: defaults)
        defaults.set(legacyId, forKey: Keys.active)
    }
}
