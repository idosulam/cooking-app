import Foundation
import Supabase

struct ImprovedInstructions: Decodable {
    let steps: [String]
}

struct GeneratedRecipe: Decodable {
    let name: String
    let category: RecipeCategory
    let cookTimeMinutes: Int
    let servings: Int
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let ingredients: [Ingredient]
    let steps: [String]
}

struct NutritionEstimate: Decodable {
    struct PerServing: Decodable {
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }

    struct IngredientBreakdown: Decodable, Identifiable {
        var id: String { ingredient }
        let ingredient: String
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }

    let perServing: PerServing
    let breakdown: [IngredientBreakdown]
    let warnings: [String]
}

private struct AIRequest: Encodable {
    let action: String
    let payload: AnyJSON
}

@MainActor
final class AIService: ObservableObject {
    private let client: SupabaseClient?

    init(client: SupabaseClient?) {
        self.client = client
    }

    func improveInstructions(notes: String, ingredients: [Ingredient]) async throws -> [String] {
        let result: ImprovedInstructions = try await invoke(
            action: "improve_instructions",
            payload: .object([
                "notes": .string(notes),
                "ingredients": .array(ingredients.map { .object($0.aiPayload) })
            ])
        )
        guard !result.steps.isEmpty, result.steps.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AppError.invalidResponse
        }
        return result.steps
    }

    func calculateNutrition(ingredients: [Ingredient], servings: Int) async throws -> NutritionEstimate {
        let result: NutritionEstimate = try await invoke(
            action: "calculate_nutrition",
            payload: .object([
                "ingredients": .array(ingredients.map { .object($0.aiPayload) }),
                "servings": .integer(servings)
            ])
        )
        try NutritionValidator.validate(result)
        return result
    }

    func generateRecipe(description: String, imageData: Data?) async throws -> GeneratedRecipe {
        var payload: [String: AnyJSON] = [
            "description": .string(description),
        ]
        if let imageData {
            payload["imageData"] = .string(imageData.base64EncodedString())
            payload["imageMediaType"] = .string("image/jpeg")
        }

        let result: GeneratedRecipe = try await invoke(
            action: "generate_recipe",
            payload: .object(payload)
        )
        let name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !name.isEmpty,
            (1...999).contains(result.cookTimeMinutes),
            (1...99).contains(result.servings),
            (0...10_000).contains(result.calories),
            result.ingredients.count <= 100,
            !result.ingredients.isEmpty,
            result.ingredients.allSatisfy({
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && ($0.quantity ?? 0).isFinite
                    && ($0.quantity ?? 0) >= 0
                    && !$0.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }),
            !result.steps.isEmpty,
            result.steps.count <= 50,
            result.steps.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
            [result.protein, result.fat, result.carbs].allSatisfy({ $0.isFinite && (0...1000).contains($0) })
        else {
            throw AppError.invalidResponse
        }
        let macroCalories = result.protein * 4 + result.carbs * 4 + result.fat * 9
        guard abs(macroCalories - Double(result.calories)) <= max(25, Double(result.calories) * 0.2) else {
            throw AppError.invalidResponse
        }
        return result
    }

    private func invoke<T: Decodable>(action: String, payload: AnyJSON) async throws -> T {
        guard let client else { throw AppError.unavailable }

        let data = try await client.functions.invoke(
            "ai",
            options: FunctionInvokeOptions(body: AIRequest(action: action, payload: payload))
        ) { data, _ in
            data
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            let path = Self.decodingPath(for: error)
            throw AppError.invalidRecipe(
                "The AI response didn't match the expected format"
                    + (path.isEmpty ? "." : " at \(path).")
                    + " Please try again."
            )
        }
    }

    private static func decodingPath(for error: DecodingError) -> String {
        let codingPath: [any CodingKey]
        switch error {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            codingPath = context.codingPath + {
                if case .keyNotFound(let key, _) = error {
                    return [key]
                }
                return []
            }()
        @unknown default:
            return ""
        }
        return codingPath.map(\.stringValue).joined(separator: ".")
    }
}

private extension Ingredient {
    var aiPayload: [String: AnyJSON] {
        [
            "name": .string(name),
            "quantity": quantity.map(AnyJSON.double) ?? .null,
            "unit": .string(unit)
        ]
    }
}

enum NutritionValidator {
    static func validate(_ estimate: NutritionEstimate) throws {
        let values = [
            estimate.perServing.calories,
            estimate.perServing.protein,
            estimate.perServing.fat,
            estimate.perServing.carbs
        ]
        guard values.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            throw AppError.invalidResponse
        }

        let macroCalories = estimate.perServing.protein * 4
            + estimate.perServing.carbs * 4
            + estimate.perServing.fat * 9
        let tolerance = max(25, estimate.perServing.calories * 0.2)
        guard abs(macroCalories - estimate.perServing.calories) <= tolerance else {
            throw AppError.invalidResponse
        }

        guard estimate.breakdown.allSatisfy({
            [$0.calories, $0.protein, $0.fat, $0.carbs].allSatisfy { $0.isFinite && $0 >= 0 }
        }) else {
            throw AppError.invalidResponse
        }
    }
}
