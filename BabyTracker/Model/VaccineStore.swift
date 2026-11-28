//
//  VaccineStore.swift
//  BabyTracker
//
//  Which doses the parent has marked taken, and their per-country
//  customisations.
//
//  Storage keys mirror the Android app exactly ("VAX_<ISO>_<code>_<round>",
//  the same key + "_D" for the date, "VAX_CUSTOM_<ISO>" for the overlay). The
//  two apps don't share storage, but keeping one vocabulary means a bug report
//  from either platform reads the same.
//
//  Customisations are an overlay DIFF, never a rewrite of the bundled JSON:
//  the parent's edits survive a data refresh, and a country they never touched
//  costs nothing to store.
//

import Foundation
import SwiftUI

@MainActor
final class VaccineStore: ObservableObject {

    // MARK: - Overlay

    /// Keyed by "code#round", matching Android's `Overlay`.
    struct Overlay: Codable {
        var edits: [String: Edit] = [:]
        var added: [Added] = []
        var removed: [String] = []

        struct Edit: Codable {
            var nameAr: String?
            var ageLabel: String?
            var ageMonths: Double?
        }

        struct Added: Codable {
            var code: String
            var nameAr: String
            var ageLabel: String
            var ageMonths: Double
        }
    }

    /// One effective dose as shown on screen, after the overlay is applied.
    struct Row: Identifiable, Hashable {
        let code: String
        let round: Int
        let nameAr: String
        let nameEn: String
        let ageLabel: String
        let ageMonths: Double
        let dosesCount: Int
        let isCustom: Bool

        /// "code#round" - the overlay's key and a stable list identity.
        var id: String { "\(code)#\(round)" }

        /// Android appends the dose number only for multi-dose vaccines.
        var displayName: String {
            dosesCount > 1 ? "\(nameAr)  (\(L.doseNumber(round)))" : nameAr
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let country = "VAX_COUNTRY"
        /// Set once the parent picks a country by hand, so a later async IP
        /// lookup can never overwrite their choice.
        static let countryIsUserPicked = "VAX_COUNTRY_USER"
        static func overlay(_ iso: String) -> String { "VAX_CUSTOM_\(iso)" }
        static func taken(_ iso: String, _ code: String, _ round: Int) -> String {
            "VAX_\(iso)_\(code)_\(round)"
        }
        static func date(_ iso: String, _ code: String, _ round: Int) -> String {
            taken(iso, code, round) + "_D"
        }
    }

    // MARK: - State

    @Published private(set) var countryIso: String
    @Published private(set) var rows: [Row] = []
    /// Bumped on every write so views reading `isTaken`/`takenDate` directly
    /// are invalidated too.
    @Published private(set) var revision = 0

    private let defaults: UserDefaults
    private let data: VaccineData
    private var overlay = Overlay()
    private var didAttemptIPRefine = false

    /// Namespace of the child whose ticks these are - empty for the first
    /// child, so their existing keys are read unchanged. The country and the
    /// overlay are NOT prefixed: both are family-wide.
    private var keyPrefix: String

    /// `dd/MM/yyyy` in en_US_POSIX on both sides of the round trip. The
    /// pregnancy tracker crashed on Arabic devices by formatting with the
    /// device locale and then failing to parse its own output back.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    init(defaults: UserDefaults = .standard, data: VaccineData = .bundled) {
        self.defaults = defaults
        self.data = data
        // Read straight from storage rather than waiting to be told: the first
        // frame is drawn before any wiring runs, and the home card's summary
        // must already count the active child's doses.
        self.keyPrefix = ChildStore.activePrefix(defaults)

        let saved = defaults.string(forKey: Keys.country) ?? ""
        // A synchronous best guess so the first frame already shows a country;
        // `refineCountryFromIP()` sharpens it when the network answers.
        self.countryIso = saved.isEmpty
            ? CountryDetector.deviceGuess(in: data)
            : saved
        if saved.isEmpty {
            defaults.set(countryIso, forKey: Keys.country)
        }

        reload()
    }

    /// Points the store at another child. Rows are unchanged - they come from
    /// the shared schedule and overlay - but every tick and date now resolves
    /// elsewhere, so observers have to be told.
    func setKeyPrefix(_ prefix: String) {
        guard prefix != keyPrefix else { return }
        keyPrefix = prefix
        revision += 1
    }

    /// Re-reads everything. Needed after a reset, which clears the stored
    /// ticks without going through this object.
    func refresh() {
        reload()
    }

    private func takenKey(_ code: String, _ round: Int) -> String {
        keyPrefix + Keys.taken(countryIso, code, round)
    }

    private func dateKey(_ code: String, _ round: Int) -> String {
        keyPrefix + Keys.date(countryIso, code, round)
    }

    var countries: [VaccineData.Country] { data.countries }
    var countryName: String { data.countryName(countryIso) }

    /// Attribution for the bundled schedules, verbatim from the data file.
    var sourceText: String? {
        data.meta?.source?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// True when this country has no schedule of its own and is reading the
    /// WHO default.
    var usesDefaultSchedule: Bool { !data.hasOwnSchedule(countryIso) }

    // MARK: - Country

    /// An explicit pick is authoritative from here on.
    func selectCountry(_ iso: String) {
        defaults.set(true, forKey: Keys.countryIsUserPicked)
        guard iso != countryIso else { return }
        countryIso = iso
        defaults.set(iso, forKey: Keys.country)
        reload()
    }

    /// Fire-and-forget IP lookup. Skipped entirely once the parent has chosen,
    /// which is the whole point of the `VAX_COUNTRY_USER` flag.
    ///
    /// Runs at most once per launch: home, onboarding and the schedule screen
    /// all ask on appear, and without the latch a cold start would make the
    /// same request three times.
    func refineCountryFromIP() async {
        guard !didAttemptIPRefine else { return }
        didAttemptIPRefine = true
        guard !defaults.bool(forKey: Keys.countryIsUserPicked) else { return }
        guard let iso = await CountryDetector.fromIP(in: data), iso != countryIso else { return }
        countryIso = iso
        defaults.set(iso, forKey: Keys.country)
        reload()
    }

    // MARK: - Reading

    func isTaken(_ row: Row) -> Bool {
        defaults.bool(forKey: takenKey(row.code, row.round))
    }

    /// Whether a dose is ticked for a named child rather than the one on
    /// screen. Reminders are built for the whole family, so they have to ask
    /// about children who are not currently being viewed.
    func isTaken(_ row: Row, childPrefix: String) -> Bool {
        defaults.bool(forKey: childPrefix + Keys.taken(countryIso, row.code, row.round))
    }

    func takenDate(_ row: Row) -> String {
        defaults.string(forKey: dateKey(row.code, row.round)) ?? ""
    }

    /// Doses already due for a baby of `babyMonths`, not yet ticked.
    func isDue(_ row: Row, babyMonths: Double) -> Bool {
        !isTaken(row) && row.ageMonths <= babyMonths
    }

    var completedCount: Int { rows.filter(isTaken).count }
    var totalCount: Int { rows.count }

    // MARK: - Writing

    /// Marking a dose taken records TODAY without asking, so one tap is
    /// enough; the row then offers an edit link to correct the date.
    func setTaken(_ row: Row, _ taken: Bool) {
        defaults.set(taken, forKey: takenKey(row.code, row.round))
        defaults.set(
            taken ? Self.dateFormatter.string(from: Date()) : "",
            forKey: dateKey(row.code, row.round)
        )
        revision += 1
    }

    /// Editing a date keeps the dose marked taken - Android does the same, so
    /// correcting a date can never silently untick a row.
    func setTakenDate(_ row: Row, _ date: Date) {
        defaults.set(true, forKey: takenKey(row.code, row.round))
        defaults.set(
            Self.dateFormatter.string(from: date),
            forKey: dateKey(row.code, row.round)
        )
        revision += 1
    }

    func takenDateValue(_ row: Row) -> Date {
        Self.dateFormatter.date(from: takenDate(row)) ?? Date()
    }

    // MARK: - Customising

    func addVaccine(nameAr: String, ageLabel: String) {
        let name = nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = ageLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !label.isEmpty else { return }

        overlay.added.append(
            Overlay.Added(
                code: "cust_\(Int(Date().timeIntervalSince1970 * 1000))",
                nameAr: name,
                ageLabel: label,
                ageMonths: Self.monthsFromAgeLabel(label)
            )
        )
        saveOverlay()
    }

    func edit(_ row: Row, nameAr: String, ageLabel: String) {
        let name = nameAr.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = ageLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !label.isEmpty else { return }
        let months = Self.monthsFromAgeLabel(label)

        if row.isCustom {
            if let i = overlay.added.firstIndex(where: { $0.code == row.code }) {
                overlay.added[i].nameAr = name
                overlay.added[i].ageLabel = label
                overlay.added[i].ageMonths = months
            }
        } else {
            overlay.edits[row.id] = Overlay.Edit(
                nameAr: name, ageLabel: label, ageMonths: months
            )
        }
        saveOverlay()
    }

    func remove(_ row: Row) {
        if row.isCustom {
            overlay.added.removeAll { $0.code == row.code }
        } else {
            if !overlay.removed.contains(row.id) { overlay.removed.append(row.id) }
            overlay.edits.removeValue(forKey: row.id)
        }
        // Clear its tick too, so re-adding the row later starts clean. Only
        // for the child on screen: a sibling's record of the same dose is
        // theirs, and removing a row from the shared schedule does not unmake
        // the injection they had.
        defaults.set(false, forKey: takenKey(row.code, row.round))
        defaults.set("", forKey: dateKey(row.code, row.round))
        saveOverlay()
    }

    // MARK: - Grouping

    /// One card's worth of rows. A named type rather than a tuple because
    /// Swift has no key paths into tuples, so `ForEach(..., id: \.label)`
    /// would not compile.
    struct AgeGroup: Identifiable {
        let label: String
        let rows: [Row]
        var id: String { label }
    }

    /// Age-label groups in schedule order; each becomes one card.
    var groups: [AgeGroup] {
        var order: [String] = []
        var byLabel: [String: [Row]] = [:]
        for row in rows {
            if byLabel[row.ageLabel] == nil { order.append(row.ageLabel) }
            byLabel[row.ageLabel, default: []].append(row)
        }
        return order.map { AgeGroup(label: $0, rows: byLabel[$0] ?? []) }
    }

    // MARK: - Home summary

    /// Subtitle for the home card: always the soonest dose still to be given,
    /// whether it is already due or still ahead. Showing only overdue doses
    /// left the card blank-looking for an up-to-date baby, which is the common
    /// case and the one where the next date is most useful.
    func summary(babyMonths: Double) -> String {
        guard totalCount > 0 else { return L.vaxCardHint }

        let counts = "\(String.number(completedCount))/\(String.number(totalCount))"

        // Earliest by scheduled age, over the overlay-applied rows, so a
        // removed dose is skipped and an added one takes part.
        let next = rows
            .filter { !isTaken($0) }
            .min { $0.ageMonths < $1.ageMonths }

        guard let next else { return "\(L.vaxAllDone)  •  \(counts)" }

        let label = next.ageMonths <= babyMonths ? L.vaxDueLabel : L.vaxNextDose
        return "\(label): \(next.nameAr)  •  \(counts)"
    }

    // MARK: - Internals

    private func reload() {
        loadOverlay()
        rows = buildRows()
        revision += 1
    }

    private func loadOverlay() {
        guard
            let json = defaults.string(forKey: Keys.overlay(countryIso)),
            !json.isEmpty,
            let decoded = try? JSONDecoder().decode(Overlay.self, from: Data(json.utf8))
        else {
            overlay = Overlay()
            return
        }
        overlay = decoded
    }

    private func saveOverlay() {
        if let encoded = try? JSONEncoder().encode(overlay),
           let json = String(data: encoded, encoding: .utf8) {
            defaults.set(json, forKey: Keys.overlay(countryIso))
        }
        rows = buildRows()
        revision += 1
    }

    private func buildRows() -> [Row] {
        var result: [Row] = []

        for vaccine in data.schedule(for: countryIso) {
            guard let doses = vaccine.doses else { continue }
            for dose in doses {
                let id = "\(vaccine.code)#\(dose.round)"
                if overlay.removed.contains(id) { continue }
                let edit = overlay.edits[id]
                result.append(
                    Row(
                        code: vaccine.code,
                        round: dose.round,
                        nameAr: edit?.nameAr ?? vaccine.nameAr,
                        nameEn: vaccine.nameEn ?? "",
                        ageLabel: edit?.ageLabel ?? dose.ageLabel,
                        ageMonths: edit?.ageMonths ?? dose.ageMonths,
                        dosesCount: doses.count,
                        isCustom: false
                    )
                )
            }
        }

        for added in overlay.added where !overlay.removed.contains("\(added.code)#1") {
            result.append(
                Row(
                    code: added.code,
                    round: 1,
                    nameAr: added.nameAr,
                    nameEn: "",
                    ageLabel: added.ageLabel,
                    ageMonths: added.ageMonths,
                    dosesCount: 1,
                    isCustom: true
                )
            )
        }

        // Stable sort: equal ages keep schedule order, so a card's rows don't
        // shuffle between launches.
        return result.enumerated()
            .sorted {
                $0.element.ageMonths == $1.element.ageMonths
                    ? $0.offset < $1.offset
                    : $0.element.ageMonths < $1.element.ageMonths
            }
            .map(\.element)
    }

    /// Arabic age label to months, for sorting and for "is it due yet".
    /// Ported from Android's `parseAgeLabel`, including its 30.44 / 4.345
    /// divisors so both apps order a custom row identically.
    static func monthsFromAgeLabel(_ label: String) -> Double {
        let s = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return 999 }
        if s.contains("ولادة") { return 0 }

        // The FIRST number only, like Android's `(\d+(?:\.\d+)?)` match.
        // Concatenating every digit would turn a range such as "شهر 12 - 15"
        // into 1215 and sort it to the end of the schedule.
        var digits = ""
        for character in s {
            if character.isNumber || (character == "." && !digits.isEmpty) {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        let n = Double(digits.hasSuffix(".") ? String(digits.dropLast()) : digits) ?? 0

        if s.contains("يوم") { return n / 30.44 }
        if s.contains("أسبوع") || s.contains("اسبوع") { return n / 4.345 }
        if s.contains("سنة") || s.contains("سنوات") || s.contains("عام") { return n * 12 }
        return n   // default: months
    }
}
