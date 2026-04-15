import SwiftData
import SwiftUI

@Model
final class ExpenseCategory {
    var id: UUID
    var name: String
    var colorHex: String
    var sfSymbol: String

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]

    init(name: String, colorHex: String, sfSymbol: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.sfSymbol = sfSymbol
        self.expenses = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    // MARK: - Default categories

    static let defaults: [(name: String, colorHex: String, sfSymbol: String)] = [
        ("Alimentação",    "#FF6B6B", "fork.knife"),
        ("Transporte",     "#4ECDC4", "car.fill"),
        ("Saúde",          "#45B7D1", "heart.fill"),
        ("Compras",        "#96CEB4", "bag.fill"),
        ("Entretenimento", "#FFEAA7", "gamecontroller.fill"),
        ("Moradia",        "#DDA0DD", "house.fill"),
        ("Educação",       "#98D8C8", "book.fill"),
        ("Outros",         "#B0BEC5", "ellipsis.circle.fill"),
    ]

    @MainActor
    static func seedDefaultsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<ExpenseCategory>()
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        for item in defaults {
            context.insert(ExpenseCategory(name: item.name, colorHex: item.colorHex, sfSymbol: item.sfSymbol))
        }
        try? context.save()
    }
}

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
