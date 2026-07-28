//
//  RootView.swift
//  BabyTracker
//
//  TEMPORARY scaffold. This is a content smoke-test, not the real UI - it
//  exists so the first CI build and the first simulator screenshot prove that
//  the ported JSON decodes and renders Arabic correctly on device. It is
//  replaced by the tab shell once the Home and Weeks screens land.
//

import SwiftUI

struct RootView: View {
    private let store = ContentStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summary

                    if let week = store.week(at: 0) {
                        section("أول أسبوع") {
                            Text(week.title).font(.headline)
                            ForEach(week.babyGrowth.prefix(3)) { block in
                                Text(block.text)
                                    .font(block.kind == .heading ? .subheadline.bold() : .body)
                            }
                        }
                    }

                    if let month = store.skills(forMonth: 0) {
                        section("مهارات الشهر الأول") {
                            ForEach(month.tiers) { tier in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tier.title).font(.subheadline.bold())
                                    Text(tier.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(tier.items, id: \.self) { item in
                                        Text("• \(item)").font(.callout)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle("أنا و طفلي")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("فحص المحتوى").font(.title3.bold())
            Text("الأسابيع: \(store.weekCount) — الأشهر: \(store.skills.count)")
                .font(.subheadline)
                .foregroundStyle(store.weekCount == 45 && store.skills.count == 12
                                 ? Color.green : Color.red)
        }
    }

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            content()
        }
    }
}

#Preview {
    RootView()
}
