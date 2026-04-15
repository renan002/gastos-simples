import SwiftData
import Foundation

@Model
final class Expense {
    var id: UUID
    var merchantName: String
    var amount: Double
    var date: Date
    var isInstallment: Bool
    var totalInstallments: Int
    var currentInstallment: Int
    var screenshotThumbnail: Data?
    var createdAt: Date

    @Relationship(deleteRule: .nullify)
    var category: ExpenseCategory?

    init(
        merchantName: String,
        amount: Double,
        date: Date,
        category: ExpenseCategory? = nil,
        isInstallment: Bool = false,
        totalInstallments: Int = 1,
        currentInstallment: Int = 1,
        screenshotThumbnail: Data? = nil
    ) {
        self.id = UUID()
        self.merchantName = merchantName
        self.amount = amount
        self.date = date
        self.category = category
        self.isInstallment = isInstallment
        self.totalInstallments = totalInstallments
        self.currentInstallment = currentInstallment
        self.screenshotThumbnail = screenshotThumbnail
        self.createdAt = Date()
    }

    var installmentLabel: String? {
        guard isInstallment else { return nil }
        return "\(currentInstallment)/\(totalInstallments)"
    }
}
