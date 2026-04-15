import SwiftUI
import SwiftData
import Charts

struct CategoryDetailView: View {
    let category: ExpenseCategory
    let month: Date

    @Query(sort: \Expense.date, order: .reverse) private var allExpenses: [Expense]
    @Environment(\.modelContext) private var context
    @State private var expenseToDelete: Expense?

    private var expenses: [Expense] {
        allExpenses.filter { expense in
            expense.category?.id == category.id &&
            Calendar.current.isDate(expense.date, equalTo: month, toGranularity: .month)
        }
    }

    private var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        List {
            // Header section
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: category.sfSymbol)
                            .font(.system(size: 32))
                            .foregroundStyle(category.color)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text(Self.monthFormatter.string(from: month))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if expenses.count > 1 {
                        SpendingBarChart(expenses: expenses, color: category.color)
                            .frame(height: 120)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Expense rows
            Section("Transações (\(expenses.count))") {
                if expenses.isEmpty {
                    Text("Nenhum gasto neste mês")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(expenses) { expense in
                        ExpenseRowView(expense: expense)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    expenseToDelete = expense
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Excluir este gasto?",
            isPresented: .constant(expenseToDelete != nil),
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                if let expense = expenseToDelete {
                    context.delete(expense)
                    try? context.save()
                }
                expenseToDelete = nil
            }
            Button("Cancelar", role: .cancel) { expenseToDelete = nil }
        }
    }
}

// MARK: - Daily bar chart

private struct SpendingBarChart: View {
    let expenses: [Expense]
    let color: Color

    private var dailyTotals: [(day: Int, total: Double)] {
        let grouped = Dictionary(grouping: expenses) {
            Calendar.current.component(.day, from: $0.date)
        }
        return grouped.map { (day: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.day < $1.day }
    }

    var body: some View {
        Chart(dailyTotals, id: \.day) { item in
            BarMark(
                x: .value("Dia", item.day),
                y: .value("Valor", item.total)
            )
            .foregroundStyle(color.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) {
                AxisValueLabel()
            }
        }
        .chartYAxis(.hidden)
    }
}
