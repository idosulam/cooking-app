import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
        guard let client else {
            isLoading = false
            return
        }

        Task {
            do {
                session = try await client.auth.session
            } catch {
                errorMessage = error.localizedDescription
            }

            for await (_, updatedSession) in client.auth.authStateChanges {
                if updatedSession?.isExpired == true {
                    isLoading = false
                    continue
                }
                session = updatedSession
                isLoading = false
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        guard let client else { throw AppError.unavailable }
        errorMessage = nil
        do {
            _ = try await client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signUp(email: String, password: String) async throws {
        guard let client else { throw AppError.unavailable }
        errorMessage = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signOut() async -> Bool {
        guard let client else {
            errorMessage = AppError.unavailable.localizedDescription
            return false
        }
        do {
            try await client.auth.signOut()
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
