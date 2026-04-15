import SwiftUI

struct CategoryPickerView: View {
    let categories: [ExpenseCategory]
    @Binding var selected: ExpenseCategory?
    let onNext: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(categories) { cat in
                        CategoryCell(
                            category: cat,
                            isSelected: selected?.id == cat.id
                        ) {
                            selected = cat
                        }
                    }
                }
                .padding()
            }

            Button(action: onNext) {
                Text(selected == nil ? "Pular Categoria" : "Continuar")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
    }
}

private struct CategoryCell: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(isSelected ? 1 : 0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: category.sfSymbol)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : category.color)
                }
                Text(category.name)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? AnyShapeStyle(category.color.opacity(0.12))
                    : AnyShapeStyle(.regularMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? category.color : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
