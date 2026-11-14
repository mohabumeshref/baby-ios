//
//  VaccineReminders.swift
//  BabyTracker
//
//  Local reminders for doses still to be given.
//
//  Two per dose, at 10:00 - three days before the due date and on the day -
//  matching the Android scheduler. Everything is derived from the bundled
//  vaccines.json and the parent's overlay via VaccineStore, so no country or
//  vaccine is named here.
//
//  The whole set is rebuilt rather than patched. A dose can change in several
//  ways at once (ticked, re-dated, edited, removed, or the country switched
//  under it), and a stable identifier per reminder means re-adding replaces
//  the old request in place while anything no longer valid simply stops being
//  re-added.
//

import Foundation
import UserNotifications

/// Key in a reminder's payload, deliberately outside `VaccineReminders`:
/// `NotificationDestination.init` reads it from a nonisolated initialiser, and
/// that type is MainActor-isolated.
enum VaccineReminderPayload {
    static let key = "vax_reminder"
}

@MainActor
enum VaccineReminders {

    /// Marks our requests so a rebuild can clear them without touching the
    /// weekly reminder.
    private static let identifierPrefix = "vax_"

    /// Days before the due date for the early nudge.
    private static let leadDays = 3

    /// Local hour both reminders fire at.
    private static let hour = 10

    /// iOS keeps only the 64 soonest pending local notifications per app and
    /// silently drops the rest. A full schedule is far smaller than that, but
    /// a parent who adds many custom vaccines could pass it, and losing the
    /// NEXT reminder to a dose years away would be the worst possible trade.
    private static let maxPending = 32

    private static let center = UNUserNotificationCenter.current()

    /// Rebuilds every vaccine reminder from current state.
    ///
    /// Safe to call as often as state might have changed; it is a cancel and
    /// re-add, so running it twice leaves the same set of requests.
    static func reschedule(store: VaccineStore, birthDate: Date?) async {
        await cancelAll()

        guard let birthDate else { return }

        // The screenshot job seeds a birth date, which would otherwise put the
        // system permission prompt in front of every capture.
        guard !ScreenshotSeed.isDemo else { return }

        // Reuses the app's existing policy: this only prompts when the status
        // is still undetermined, and by the time there is a birth date the
        // parent has been through onboarding.
        guard await NotificationManager.shared.requestAuthorizationIfNeeded() else { return }

        let calendar = Calendar.current
        let now = Date()
        var pending: [Reminder] = []

        for row in store.rows where !store.isTaken(row) {
            guard let due = dueDate(birthDate: birthDate, ageMonths: row.ageMonths, calendar: calendar)
            else { continue }

            for offset in [leadDays, 0] {
                guard
                    let day = calendar.date(byAdding: .day, value: -offset, to: due),
                    let fireDate = fireTime(on: day, calendar: calendar),
                    // An overdue dose gets nothing: its dates are both behind
                    // us, and the schedule screen already flags it.
                    fireDate > now
                else { continue }

                pending.append(
                    Reminder(
                        identifier: identifier(iso: store.countryIso, row: row, offset: offset),
                        fireDate: fireDate,
                        body: offset == 0
                            ? L.vaxReminderToday(row.nameAr)
                            : L.vaxReminderSoon(row.nameAr)
                    )
                )
            }
        }

        // Soonest first, so a truncated schedule keeps the reminders that
        // matter now rather than an arbitrary slice.
        for reminder in pending.sorted(by: { $0.fireDate < $1.fireDate }).prefix(maxPending) {
            await add(reminder, calendar: calendar)
        }
    }

    // MARK: - Internals

    private struct Reminder {
        let identifier: String
        let fireDate: Date
        let body: String
    }

    private static func identifier(iso: String, row: VaccineStore.Row, offset: Int) -> String {
        "\(identifierPrefix)\(iso)_\(row.code)_\(row.round)_\(offset)"
    }

    /// Clears only this app's vaccine requests, by identifier prefix.
    private static func cancelAll() async {
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// The day a dose comes due.
    ///
    /// A whole number of months is added as months, so a dose due "at 2
    /// months" lands on the same day of the month as the birth date however
    /// long those months are. Fractional ages fall back to Android's
    /// `ageMonths × 30.44` days, which is the only sensible reading of a
    /// value like 1.5.
    private static func dueDate(
        birthDate: Date, ageMonths: Double, calendar: Calendar
    ) -> Date? {
        let rounded = ageMonths.rounded()
        if abs(ageMonths - rounded) < 0.001, let months = Int(exactly: rounded) {
            return calendar.date(byAdding: .month, value: months, to: birthDate)
        }
        return calendar.date(byAdding: .day, value: Int((ageMonths * 30.44).rounded()), to: birthDate)
    }

    private static func fireTime(on day: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    private static func add(_ reminder: Reminder, calendar: Calendar) async {
        let content = UNMutableNotificationContent()
        content.title = L.vaxReminderTitle
        content.body = reminder.body
        content.sound = .default
        content.userInfo = [VaccineReminderPayload.key: true]

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: reminder.fireDate
        )

        let request = UNNotificationRequest(
            identifier: reminder.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )

        try? await center.add(request)
    }
}
