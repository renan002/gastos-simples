import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail or category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(expense.category?.color.opacity(0.15) ?? Color.gray.opacity(0.15))
                    .frame(width: 48, height: 48)

                if let data = expense.screenshotThumbnail, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: expense.category?.sfSymbol ?? "questionmark.circle")
                        .foregroundStyle(expense.category?.color ?? .gray)
                        .font(.title3)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.merchantName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let cat = expense.category {
                        Text(cat.name)
                            .font(.caption)
                            .foregroundStyle(cat.color)
                    }
                    Text(Self.dateFormatter.string(from: expense.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.amount, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                    .font(.body.weight(.semibold))

                if let label = expense.installmentLabel {
                    Text(label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
