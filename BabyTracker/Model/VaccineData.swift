//
//  VaccineData.swift
//  BabyTracker
//
//  Codable mirror of the bundled vaccines.json (per-country childhood
//  schedules, Arabic names).
//
//  The JSON is the Android app's res/raw/vaccines.json copied byte for byte -
//  it is the source of truth for both apps and is never regenerated here. It
//  is fully offline; no network call ever fetches a schedule.
//

import Foundation

struct VaccineData: Decodable, Sendable {
    let countries: [Country]
    let schedules: [String: [Vaccine]]
    let defaultSchedule: [Vaccine]

    private enum CodingKeys: String, CodingKey {
        case countries, schedules
        // `default` is a Swift keyword, so it cannot be a property name.
        case defaultSchedule = "default"
    }

    struct Country: Decodable, Identifiable, Hashable, Sendable {
        let iso: String
        let nameAr: String
        let nameEn: String?

        var id: String { iso }

        /// Matches the Android picker's filter: Arabic substring, or English
        /// case-insensitively.
        func matches(_ query: String) -> Bool {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return true }
            if nameAr.contains(q) { return true }
            return nameEn?.lowercased().contains(q.lowercased()) ?? false
        }
    }

    struct Vaccine: Decodable, Sendable {
        let nameAr: String
        let nameEn: String?
        let code: String
        let doses: [Dose]?
    }

    struct Dose: Decodable, Sendable {
        let round: Int
        let ageLabel: String
        let ageMonths: Double
    }

    /// Schedule for a country, falling back to the WHO default when the
    /// country has no entry or an empty one. Mirrors Android's `scheduleFor`.
    func schedule(for iso: String) -> [Vaccine] {
        if let s = schedules[iso], !s.isEmpty { return s }
        return defaultSchedule
    }

    func countryName(_ iso: String) -> String {
        countries.first { $0.iso == iso }?.nameAr ?? iso
    }

    func contains(_ iso: String?) -> Bool {
        guard let iso else { return false }
        return countries.contains { $0.iso == iso }
    }
}

// MARK: - Loading

extension VaccineData {
    /// Bundled data, decoded once. Empty (not nil) on failure so every call
    /// site can stay non-optional; a missing file is a build mistake and trips
    /// the assertion in DEBUG.
    static let bundled: VaccineData = {
        guard let url = Bundle.main.url(forResource: "vaccines", withExtension: "json") else {
            assertionFailure("missing bundled resource vaccines.json")
            return VaccineData(countries: [], schedules: [:], defaultSchedule: [])
        }
        do {
            return try JSONDecoder().decode(VaccineData.self, from: Data(contentsOf: url))
        } catch {
            assertionFailure("failed to decode vaccines.json: \(error)")
            return VaccineData(countries: [], schedules: [:], defaultSchedule: [])
        }
    }()
}
