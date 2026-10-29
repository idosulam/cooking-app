import Foundation

struct Ingredient: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var quantity: Double?
    var unit: String

    private enum CodingKeys: String, CodingKey {
        case name
        case quantity
        case unit
    }

    init(name: String, quantity: Double?, unit: String) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decodeIfPresent(Double.self, forKey: .quantity)
        unit = try container.decode(String.self, forKey: .unit)
    }
}
