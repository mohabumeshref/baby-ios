//
//  ChildSwitcher.swift
//  BabyTracker
//
//  The child chip and everything behind it: switching, adding, renaming,
//  removing, and resetting.
//
//  A sheet rather than a `Menu`, for the same reason the community screen
//  presents its own: UIKit exposes no font API on a UIMenu's elements, so a
//  menu here would be the only Latin-metric system font in an app that is
//  otherwise entirely Cairo.
//
//  Actions are deferred to the sheet's dismissal (`pending`) rather than run
//  inside it. Presenting a second sheet while the first is still dismissing
//  drops it - the same trap the account menu hit.
//

import SwiftUI

struct ChildSwitcherChip: View {
    @EnvironmentObject private var profile: BabyProfile

    /// Where the chip sits, which decides whether it draws light on the
    /// vaccine card's gradient or dark on the cream background.
    enum Style {
        case onCream
        case onGradient
    }

    var style: Style = .onCream

    @State private var showChildren = false
    @State private var pending: PendingAction?
    @State private var isAddingChild = false
    @State private var renameTarget: ChildStore.Child?
    @State private var removeTarget: ChildStore.Child?
    @State private var showResetOptions = false
    @State private var showResetConfirm = false

    enum PendingAction {
        case add
        case rename(ChildStore.Child)
        case remove(ChildStore.Child)
        case reset
    }

    var body: some View {
        Button { showChildren = true } label: {
            HStack(spacing: 6) {
                Text("👶")
                    .font(.system(size: 14))

                Text(profile.activeChildLabel)
                    .font(WarmFont.chip)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(background)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L.childrenTitle): \(profile.activeChildLabel)")
        .modifier(
            ChildSwitcherSheets(
                showChildren: $showChildren,
                pending: $pending,
                isAddingChild: $isAddingChild,
                renameTarget: $renameTarget,
                removeTarget: $removeTarget,
                showResetOptions: $showResetOptions,
                showResetConfirm: $showResetConfirm,
                runPending: runPending
            )
        )
    }

    private var foreground: Color {
        style == .onGradient ? .white : Warm.brand
    }

    private var background: Color {
        style == .onGradient ? Warm.vaxIconCircle : Warm.chipOff
    }

    /// Runs whatever the list sheet asked for, now that it has gone.
    private func runPending() {
        guard let action = pending else { return }
        pending = nil

        switch action {
        case .add:
            isAddingChild = true
        case .rename(let child):
            renameTarget = child
        case .remove(let child):
            removeTarget = child
        case .reset:
            // One child gets the plain confirm; a family gets the choice
            // between this child and starting over.
            if profile.hasMultipleChildren {
                showResetOptions = true
            } else {
                showResetConfirm = true
            }
        }
    }
}

// MARK: - Sheets
//
// Extracted to a ViewModifier to keep the chip's `body` inside the
// type-checker's budget - four sheets, an alert and a dialog on one view push
// it over.

private struct ChildSwitcherSheets: ViewModifier {
    @EnvironmentObject private var profile: BabyProfile
    // A reset clears stored keys directly, so the two stores that read them
    // have to be told; nothing they own changed.
    @EnvironmentObject private var milestones: MilestoneStore
    @EnvironmentObject private var vaccines: VaccineStore

    @Binding var showChildren: Bool
    @Binding var pending: ChildSwitcherChip.PendingAction?
    @Binding var isAddingChild: Bool
    @Binding var renameTarget: ChildStore.Child?
    @Binding var removeTarget: ChildStore.Child?
    @Binding var showResetOptions: Bool
    @Binding var showResetConfirm: Bool
    let runPending: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showChildren, onDismiss: runPending) {
                ChildrenSheet(
                    onSelect: { id in
                        profile.switchTo(childId: id)
                        showChildren = false
                    },
                    onAction: { action in
                        pending = action
                        showChildren = false
                    }
                )
                .environmentObject(profile)
            }
            .sheet(isPresented: $isAddingChild) {
                AddChildSheet { name, date in
                    profile.addChild(name: name, birthDate: date)
                }
            }
            .sheet(item: $renameTarget) { child in
                RenameChildSheet(initial: child.name) { name in
                    profile.rename(childId: child.id, to: name)
                }
            }
            .alert(
                L.childRemove,
                // A real binding, never `.constant(...)`: the constant form
                // left the forum's dialogs anchored to the wrong view.
                isPresented: Binding(
                    get: { removeTarget != nil },
                    set: { if !$0 { removeTarget = nil } }
                ),
                presenting: removeTarget
            ) { child in
                Button(L.delete, role: .destructive) {
                    profile.removeChild(child.id)
                }
                Button(L.cancel, role: .cancel) {}
            } message: { _ in
                Text(L.childRemoveConfirm)
            }
            .confirmationDialog(
                L.resetTitle,
                isPresented: $showResetOptions,
                titleVisibility: .visible
            ) {
                Button(L.resetThisChild) { resetActiveChild() }
                Button(L.resetAllChildren, role: .destructive) {
                    profile.removeAllChildren()
                    refreshStores()
                }
                Button(L.cancel, role: .cancel) {}
            }
            .alert(L.reset, isPresented: $showResetConfirm) {
                Button(L.reset, role: .destructive) { resetActiveChild() }
                Button(L.cancel, role: .cancel) {}
            } message: {
                Text(L.resetConfirm)
            }
    }

    /// The active child's prefix does not change here, so the stores' own
    /// prefix observer cannot notice; they are refreshed explicitly.
    private func resetActiveChild() {
        profile.resetActiveChildProgress()
        refreshStores()
    }

    private func refreshStores() {
        milestones.refresh()
        vaccines.refresh()
    }
}

// MARK: - The list

private struct ChildrenSheet: View {
    let onSelect: (String) -> Void
    let onAction: (ChildSwitcherChip.PendingAction) -> Void

    @EnvironmentObject private var profile: BabyProfile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(profile.children) { child in
                        row(child)
                    }

                    addRow

                    if let active = profile.activeChild {
                        actionRow(L.childRename, icon: "pencil") {
                            onAction(.rename(active))
                        }

                        // Only with a sibling to fall back to: removing the
                        // last child is what "start over" is for, and it lives
                        // in the reset dialog with its warning.
                        if profile.hasMultipleChildren {
                            actionRow(L.childRemove, icon: "trash", isDestructive: true) {
                                onAction(.remove(active))
                            }
                        }
                    }

                    actionRow(L.reset, icon: "arrow.counterclockwise") {
                        onAction(.reset)
                    }
                }
                .padding(WarmMetrics.screenPadding)
            }
            .warmBackground()
            .navigationTitle(L.childrenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                        .tint(Warm.brand)
                }
            }
        }
    }

    private func row(_ child: ChildStore.Child) -> some View {
        Button { onSelect(child.id) } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Self.tint(child.colorIndex))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.label(for: child))
                        .font(WarmFont.body)
                        .foregroundStyle(Warm.ink)

                    Text(Self.dateFormatter.string(from: child.birthDate))
                        .font(WarmFont.caption)
                        .foregroundStyle(Warm.muted)
                        // A date reads left-to-right in both languages.
                        .environment(\.layoutDirection, .leftToRight)
                }

                Spacer(minLength: 0)

                if child.id == profile.activeChildId {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Warm.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                    .fill(Warm.card)
            )
        }
        .buttonStyle(.plain)
    }

    private var addRow: some View {
        Button { onAction(.add) } label: {
            Text("＋  \(L.childAdd)")
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

    private func actionRow(
        _ title: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(WarmFont.chip)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isDestructive ? Color.red : Warm.mutedSub)
            .padding(.horizontal, 14)
            .frame(minHeight: WarmMetrics.chipMinHeight)
        }
        .buttonStyle(.plain)
    }

    private static func tint(_ index: Int) -> Color {
        let palette: [Color] = [
            Warm.brand, Warm.green, Warm.brandDeep,
            Warm.articleInk, Warm.eyebrow, Warm.mutedSub,
        ]
        return palette[abs(index) % palette.count]
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "dd / MM / yyyy"
        return f
    }()
}

// MARK: - Add

/// Birth date and an optional name, and nothing else: the mother has already
/// told the app where she lives, and asking again per child would imply the
/// country is per child when it is shared.
private struct AddChildSheet: View {
    let onSave: (String, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var birthDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                WarmTextField(placeholder: L.childNameHint, text: $name)

                Text(L.onboardingBirthDateTitle)
                    .font(WarmFont.chip)
                    .foregroundStyle(Warm.mutedSub)
                    .frame(maxWidth: .infinity, alignment: .leading)

                DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    // The wheel reads right-to-left otherwise, which puts the
                    // day column where Arabic readers expect the year.
                    .environment(\.layoutDirection, .leftToRight)

                Spacer()
            }
            .padding(WarmMetrics.screenPadding)
            .warmBackground()
            .navigationTitle(L.childAdd)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .tint(Warm.mutedSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) {
                        onSave(name, birthDate)
                        dismiss()
                    }
                    .tint(Warm.brand)
                }
            }
        }
    }
}

// MARK: - Rename

private struct RenameChildSheet: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(initial: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _name = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                WarmTextField(placeholder: L.childNameHint, text: $name)
                Spacer()
            }
            .padding(WarmMetrics.screenPadding)
            .warmBackground()
            .navigationTitle(L.childRename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                        .tint(Warm.mutedSub)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save) {
                        onSave(name)
                        dismiss()
                    }
                    .tint(Warm.brand)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}
