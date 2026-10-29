import SwiftUI

struct AuthView: View {
    @ObservedObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 40)
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 53, weight: .light))
                .symbolRenderingMode(.palette)
                .foregroundStyle(RecipeTheme.leaf, RecipeTheme.butter)
                .padding(.bottom, 28)

            Text(isSignUp ? "Make room\nat your table." : "A little more\ndelicious, daily.")
                .font(.system(.largeTitle, design: .serif).weight(.regular))
                .tracking(-1.3)
                .lineSpacing(-1)
                .padding(.bottom, 12)
            Text(isSignUp ? "Start a collection worth coming back to." : "Your recipes, ready whenever you are.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.bottom, 34)

            VStack(spacing: 13) {
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .authField()

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { Task { await authenticate() } }
                    .authField()
            }

            if let visibleMessage = errorMessage ?? statusMessage ?? authService.errorMessage {
                Text(visibleMessage)
                    .font(.footnote)
                    .foregroundStyle(errorMessage == nil && authService.errorMessage == nil ? RecipeTheme.leaf : .red)
                    .padding(.top, 12)
                    .accessibilityLabel(visibleMessage)
            }

            Button {
                Task { await authenticate() }
            } label: {
                HStack(spacing: 9) {
                    if isWorking { ProgressView().tint(.white) }
                    Text(isSignUp ? "Create account" : "Sign in")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .foregroundStyle(.white)
                .background(RecipeTheme.accent, in: Capsule())
            }
            .disabled(isWorking || email.isEmpty || password.isEmpty)
            .opacity(email.isEmpty || password.isEmpty ? 0.55 : 1)
            .padding(.top, 21)

            Button {
                withAnimation(.snappy(duration: 0.24)) {
                    isSignUp.toggle()
                    errorMessage = nil
                    statusMessage = nil
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "New to Recipes?")
                        .foregroundStyle(.secondary)
                    Text(isSignUp ? "Sign in" : "Create one")
                        .foregroundStyle(RecipeTheme.accent)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 28)
        .background(RecipeTheme.canvas.ignoresSafeArea())
    }

    private func authenticate() async {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        statusMessage = nil
        defer { isWorking = false }
        do {
            if isSignUp {
                try await authService.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
                statusMessage = "If email confirmation is on, check your inbox before signing in."
            } else {
                try await authService.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension View {
    func authField() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RecipeTheme.card, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .textInputAutocapitalization(.never)
    }
}
