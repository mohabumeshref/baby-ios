//
//  CountryPickerView.swift
//  BabyTracker
//
//  Searchable country list, shared by the vaccine screen's "change" link and
//  by onboarding step 2, so both filter and mark the selection identically.
//
//  The search box is an ordinary field rather than `.searchable`: that
//  modifier only renders inside a navigation container, and onboarding embeds
//  this list directly in its own step. Android puts an EditText above the list
//  here too.
//
//  184 rows, so the list is a `List` (UITableView underneath, with real cell
//  recycling) rather than a ScrollView of rows.
//

import SwiftUI

struct CountryPickerView: View {
    let countries: [VaccineData.Country]
    let selected: String
    let onSelect: (String) -> Void

    /// Onboarding supplies its own title and navigation, so it turns the
    /// sheet chrome off.
    var showsChrome = true

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [VaccineData.Country] {
        countries.filter { $0.matches(query) }
    }

    var body: some View {
        if showsChrome {
            NavigationStack {
                content
                    .navigationTitle(L.vaxPickCountry)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L.cancel) { dismiss() }
                                .tint(Warm.mutedSub)
                        }
                    }
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 10) {
            searchField
            list
        }
        .warmBackground()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Warm.muted)

            WarmTextField(placeholder: L.vaxSearchCountry, text: $query)

            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Warm.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, WarmMetrics.screenPadding)
        .padding(.top, 10)
    }

    private var list: some View {
        List(filtered) { country in
            Button {
                onSelect(country.iso)
                if showsChrome { dismiss() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Warm.green)
                        // Hidden rather than absent, so the names stay on one
                        // vertical line as the selection moves.
                        .opacity(country.iso == selected ? 1 : 0)

                    Text(country.nameAr)
                        .font(country.iso == selected ? WarmFont.heading : WarmFont.body)
                        .foregroundStyle(country.iso == selected ? Warm.green : Warm.ink)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(Warm.dotIdle)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
    }
}

/// The compact "الدولة <name> [تغيير]" line at the top of the schedule.
struct CountryLine: View {
    let name: String
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(L.vaxCountry)
                .font(WarmFont.caption)
                .foregroundStyle(Warm.muted)

            Text(name)
                .font(WarmFont.chip)
                .foregroundStyle(Warm.ink)

            Button(action: onChange) {
                Text(L.vaxChangeCountry)
                    .font(WarmFont.caption)
                    .foregroundStyle(Warm.brand)
                    .underline()
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }
}
