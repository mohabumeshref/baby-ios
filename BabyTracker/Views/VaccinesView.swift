//
//  VaccinesView.swift
//  BabyTracker
//
//  The childhood vaccine schedule for the selected country.
//
//  Rows come from the bundled JSON with the parent's per-country overlay
//  applied (see VaccineStore). Ticking a dose records today's date in one tap;
//  an edit link then corrects it, which is the Android behaviour and avoids
//  putting a date picker in front of the common case.
//

import SwiftUI

struct VaccinesView: View {
    @EnvironmentObject private var profile: BabyProfile
    @EnvironmentObject private var vaccines: VaccineStore

    @State private var showCountryPicker = false
    @State private var rowPendingDelete: VaccineStore.Row?
    @State private var rowBeingEdited: VaccineStore.Row?
    @State private var isAddingVaccine = false
    @State private var rowPendingDate: VaccineStore.Row?

    /// Android divides elapsed days by 30.44; kept identical so a dose is
    /// "due" on the same day in both apps.
    private var babyMonths: Double {
        guard let birth = profile.birthDate else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: birth, to: Date()).day ?? 0
        return Double(days) / 30.44
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                addButton
                ForEach(vaccines.groups) { group in
                    groupCard(group.label, group.rows)
                }
                hint
            }
            .padding(.horizontal, WarmMetrics.screenPadding)
            .padding(.vertical, 16)
        }
        .warmBackground()
        .navigationTitle(L.vaxTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await vaccines.refineCountryFromIP() }
        .modifier(
            VaccineSheets(
                vaccines: vaccines,
                showCountryPicker: $showCountryPicker,
                rowBeingEdited: $rowBeingEdited,
                isAddingVaccine: $isAddingVaccine,
                rowPendingDate: $rowPendingDate
            )
        )
        .alert(
            L.vaxDeleteTitle,
            // A real binding, never `.constant(...)`: the constant form left
            // the forum's dialogs anchored to the wrong view on device.
            isPresented: Binding(
                get: { rowPendingDelete != nil },
                set: { if !$0 { rowPendingDelete = nil } }
            ),
            presenting: rowPendingDelete
        ) { row in
            Button(L.delete, role: .destructive) { vaccines.remove(row) }
            Button(L.cancel, role: .cancel) {}
        } message: { row in
            Text(L.vaxDeleteMessage(row.nameAr))
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            CountryLine(name: vaccines.countryName) { showCountryPicker = true }

            Text(L.vaxProgress(done: vaccines.completedCount, total: vaccines.totalCount))
                .font(WarmFont.heading)
                .foregroundStyle(Warm.brand)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addButton: some View {
        Button { isAddingVaccine = true } label: {
            Text("＋  \(L.vaxAdd)")
                .font(WarmFont.chip)
                .foregroundStyle(Warm.brand)
                .frame(maxWidth: .infinity)
                .frame(minHeight: WarmMetrics.chipMinHeight)
                .background(
                    RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                        .fill(Warm.chipOff)
                )
        }
        .buttonStyle(.plain)
    }

    private var hint: some View {
        Text(L.vaxLongPressHint)
            .font(WarmFont.caption)
            .foregroundStyle(Warm.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    // MARK: - Groups

    private func groupCard(_ label: String, _ rows: [VaccineStore.Row]) -> some View {
        WarmCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(WarmFont.articleHeading)
                    .foregroundStyle(Warm.brand)
                    .padding(.bottom, 8)

                ForEach(rows) { row in
                    VaccineRowView(
                        row: row,
                        isTaken: vaccines.isTaken(row),
                        isDue: vaccines.isDue(row, babyMonths: babyMonths),
                        takenDate: vaccines.takenDate(row),
                        onToggle: { vaccines.setTaken(row, !vaccines.isTaken(row)) },
                        onEditDate: { rowPendingDate = row },
                        onEdit: { rowBeingEdited = row },
                        onDelete: { rowPendingDelete = row }
                    )
                }
            }
        }
    }
}

// MARK: - Row

private struct VaccineRowView: View {
    let row: VaccineStore.Row
    let isTaken: Bool
    let isDue: Bool
    let takenDate: String
    let onToggle: () -> Void
    let onEditDate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            marker
            VStack(alignment: .leading, spacing: 2) {
                Text(row.displayName)
                    .font(WarmFont.body)
                    .foregroundStyle(isDue ? Warm.brand : Warm.ink)
                    .multilineTextAlignment(.leading)
                subtitle
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .contextMenu {
            Button { onEdit() } label: { Label(L.edit, systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: {
                Label(L.delete, systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isTaken ? [.isButton, .isSelected] : .isButton)
    }

    private var marker: some View {
        Group {
            if isTaken {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Warm.green)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isDue ? Warm.brand : Warm.muted)
            }
        }
        .frame(width: 22)
    }

    @ViewBuilder
    private var subtitle: some View {
        if isTaken {
            HStack(spacing: 10) {
                Text("✓ \(takenDate)")
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.green)

                Button(action: onEditDate) {
                    Text(L.vaxEditDate)
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.brand)
                        .underline()
                }
                .buttonStyle(.plain)
            }
        } else if isDue {
            Text(L.vaxDueNow)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.brand)
        } else {
            Text(row.isCustom ? L.vaxCustomRow : row.nameEn)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.muted)
        }
    }
}

// MARK: - Sheets
//
// Split into a ViewModifier to keep `body` inside the type-checker's budget;
// four inline sheet modifiers on one view pushed it over.

private struct VaccineSheets: ViewModifier {
    @ObservedObject var vaccines: VaccineStore
    @Binding var showCountryPicker: Bool
    @Binding var rowBeingEdited: VaccineStore.Row?
    @Binding var isAddingVaccine: Bool
    @Binding var rowPendingDate: VaccineStore.Row?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showCountryPicker) {
                CountryPickerView(
                    countries: vaccines.countries,
                    selected: vaccines.countryIso
                ) { iso in
                    vaccines.selectCountry(iso)
                }
            }
            .sheet(isPresented: $isAddingVaccine) {
                VaccineEditSheet(title: L.vaxAdd) { name, age in
                    vaccines.addVaccine(nameAr: name, ageLabel: age)
                }
            }
            .sheet(item: $rowBeingEdited) { row in
                VaccineEditSheet(
                    title: L.vaxEditVaccine,
                    name: row.nameAr,
                    ageLabel: row.ageLabel
                ) { name, age in
                    vaccines.edit(row, nameAr: name, ageLabel: age)
                }
            }
            .sheet(item: $rowPendingDate) { row in
                VaccineDateSheet(initial: vaccines.takenDateValue(row)) { date in
                    vaccines.setTakenDate(row, date)
                }
            }
    }
}

/// Add or edit a vaccine: Arabic name plus a free-text age label, which
/// `VaccineStore.monthsFromAgeLabel` turns into a sort position.
private struct VaccineEditSheet: View {
    let title: String
    var name: String = ""
    var ageLabel: String = ""
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var nameDraft = ""
    @State private var ageDraft = ""
    @State private var didLoad = false

    private var canSave: Bool {
        !nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !ageDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                WarmTextField(placeholder: L.vaxNameHint, text: $nameDraft)
                WarmTextField(placeholder: L.vaxAgeHint, text: $ageDraft)
                Spacer()
            }
            .padding(WarmMetrics.screenPadding)
            .warmBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .tint(Warm.mutedSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) {
                        onSave(nameDraft, ageDraft)
                        dismiss()
                    }
                    .tint(Warm.brand)
                    .disabled(!canSave)
                }
            }
            .task {
                guard !didLoad else { return }
                didLoad = true
                nameDraft = name
                ageDraft = ageLabel
            }
        }
    }
}

/// Corrects the date a dose was actually given. A sheet rather than an alert
/// because an alert cannot host a date picker.
private struct VaccineDateSheet: View {
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(initial: Date, onSave: @escaping (Date) -> Void) {
        self.onSave = onSave
        _date = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    // The wheel reads right-to-left otherwise, which puts the
                    // day column where Arabic readers expect the year.
                    .environment(\.layoutDirection, .leftToRight)
                Spacer()
            }
            .padding(WarmMetrics.screenPadding)
            .warmBackground()
            .navigationTitle(L.vaxDateTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .tint(Warm.mutedSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.done) {
                        onSave(date)
                        dismiss()
                    }
                    .tint(Warm.brand)
                }
            }
        }
    }
}
