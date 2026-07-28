//
//  AuthView.swift
//  BabyTracker
//
//  Sign in / register for the shared community.
//
//  Worth surfacing to the user: this account is shared with the pregnancy
//  tracker. Someone arriving here from that app should sign in rather than
//  create a duplicate, which is why the note is shown rather than buried.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var auth: ForumAuth

    private enum Mode {
        case signIn
        case register
    }

    @State private var mode: Mode = .signIn
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    private var canSubmit: Bool {
        guard !isWorking,
              email.contains("@"),
              password.count >= 6 else { return false }
        if mode == .register {
            return !name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                WarmCard {
                    VStack(spacing: 12) {
                        if mode == .register {
                            field(L.fieldName, text: $name, content: .name)
                        }
                        field(L.fieldEmail, text: $email, content: .emailAddress, keyboard: .emailAddress)
                        secureField(L.fieldPassword, text: $password)

                        if let errorMessage {
                            message(errorMessage, color: Warm.brandDeep)
                        }
                        if let infoMessage {
                            message(infoMessage, color: Warm.green)
                        }

                        submitButton

                        if mode == .signIn {
                            Button(L.forgotPassword) { Task { await resetPassword() } }
                                .font(WarmFont.caption)
                                .foregroundStyle(Warm.mutedSub)
                                .disabled(isWorking)
                        }
                    }
                }

                Button(mode == .signIn ? L.noAccountYet : L.haveAccount) {
                    withAnimation {
                        mode = mode == .signIn ? .register : .signIn
                        errorMessage = nil
                        infoMessage = nil
                    }
                }
                .font(WarmFont.caption)
                .foregroundStyle(Warm.brand)
            }
            .padding(WarmMetrics.screenPadding)
        }
        .warmBackground()
    }

    // MARK: - Pieces

    /// No title here - the navigation bar already shows "مجتمعي", and having it
    /// twice on one screen just reads as a mistake.
    private var header: some View {
        Text(L.sharedAccountNote)
            .font(WarmFont.caption)
            .foregroundStyle(Warm.mutedSub)
            .multilineTextAlignment(.center)
            .padding(.top, 20)
            .padding(.horizontal, 8)
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        content: UITextContentType,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(label, text: text)
            .textContentType(content)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(WarmFont.body)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                    .fill(Warm.chipOff)
            )
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .textContentType(.password)
            .font(WarmFont.body)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                    .fill(Warm.chipOff)
            )
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(WarmFont.caption)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            ZStack {
                if isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(mode == .signIn ? L.signIn : L.register)
                        .font(WarmFont.heading)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: WarmMetrics.chipRadius, style: .continuous)
                    // A muted grey disabled state read as a dead slab against
                    // the cream card. Tinting it with the brand at low opacity
                    // keeps it clearly inactive but still part of the palette.
                    .fill(canSubmit ? AnyShapeStyle(Warm.brandGradient)
                                    : AnyShapeStyle(Warm.brandBright.opacity(0.28)))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
    }

    // MARK: - Actions

    private func submit() async {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            switch mode {
            case .signIn:
                try await auth.signIn(email: email, password: password)
            case .register:
                try await auth.register(name: name, email: email, password: password)
            }
            // Claim the FCM token slot as soon as there's a uid to attach it to.
            await NotificationManager.shared.syncFCMToken()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetPassword() async {
        guard email.contains("@") else {
            errorMessage = L.fieldEmail
            return
        }
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }

        do {
            try await auth.sendPasswordReset(email: email)
            infoMessage = L.resetEmailSent
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
