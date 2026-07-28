//
//  ContentStore.swift
//  BabyTracker
//
//  Loads the bundled article and milestone content once, at first access.
//

import Foundation

/// Read-only access to the app's bundled content.
///
/// Content is Arabic-only: the source articles in the Android app were never
/// translated. `localizedResourceURL` mirrors the pregnancy tracker's
/// convention, so dropping a `weeks_en.json` into the bundle later is enough
/// to serve English without touching this code.
final class ContentStore {
    static let shared = ContentStore()

    private(set) lazy var weeks: [WeekContent] = load("weeks", as: [WeekContent].self) ?? []
    private(set) lazy var skills: [MonthSkills] = load("skills", as: [MonthSkills].self) ?? []

    private init() {}

    /// The week entry for a given index, clamped to the valid range.
    func week(at index: Int) -> WeekContent? {
        guard !weeks.isEmpty else { return nil }
        let clamped = min(max(index, 0), weeks.count - 1)
        return weeks[clamped]
    }

    /// The three milestone tiers for a month of the baby's life (0...11).
    func skills(forMonth month: Int) -> MonthSkills? {
        skills.first { $0.month == month }
    }

    var weekCount: Int { weeks.count }

    // MARK: - Loading

    private func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Self.localizedResourceURL(name) else {
            assertionFailure("missing bundled resource \(name).json")
            return nil
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            assertionFailure("failed to decode \(name).json: \(error)")
            return nil
        }
    }

    /// Prefers a language variant ("weeks_en.json") when the app isn't running
    /// in Arabic, falling back to the Arabic base file.
    private static func localizedResourceURL(_ name: String, ext: String = "json") -> URL? {
        let lang = Locale.preferredLanguages.first?.prefix(2) ?? "ar"
        if lang != "ar",
           let localized = Bundle.main.url(forResource: "\(name)_\(lang)", withExtension: ext) {
            return localized
        }
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
