import SwiftUI

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    enum Request: Equatable {
        case open(UUID)
        case cook(UUID)
        case cookToday
    }

    @Published var pending: Request?

    func handle(_ url: URL) {
        guard url.scheme == "recipes" else { return }
        let id = url.pathComponents.dropFirst().first.flatMap { UUID(uuidString: $0) }
        switch url.host {
        case "cook":
            if let id { pending = .cook(id) }
        case "recipe":
            if let id { pending = .open(id) }
        case "today":
            pending = .cookToday
        default:
            break
        }
    }
}
