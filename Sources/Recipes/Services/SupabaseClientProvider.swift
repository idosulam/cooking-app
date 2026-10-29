import Foundation
import Supabase

enum SupabaseClientProvider {
    static func makeClient() throws -> SupabaseClient {
        guard
            let urlValue = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
            let url = URL(string: urlValue),
            url.scheme == "https",
            !key.isEmpty,
            !urlValue.contains("your-project")
        else {
            throw AppError.configuration
        }

        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}

enum AppError: LocalizedError {
    case configuration
    case unavailable
    case invalidResponse
    case invalidRecipe(String)

    var errorDescription: String? {
        switch self {
        case .configuration:
            "Add your Supabase URL and anon key to Config/Secrets.xcconfig, then rebuild."
        case .unavailable:
            "The service is unavailable. Check your connection and try again."
        case .invalidResponse:
            "The server returned a response we couldn't use. Please try again."
        case .invalidRecipe(let message):
            message
        }
    }
}
