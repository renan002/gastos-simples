import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @State private var selectedMonth: Date = Calendar.current.startOfMonth(for: .now)
    @State private var showAddExpense = false
    @State private var selectedCategory: ExpenseCategory?

    private var monthlyExpenses: [Expense] {
        expenses.filter {
            Calendar.current.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    private var totalSpend: Double {
        monthlyExpenses.reduce(0) { $0 + $1.amount }
    }

    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        categories.compactMap { cat in
            let total = monthlyExpenses
                .filter { $0.category?.id == cat.id }
                .reduce(0) { $0 + $1.amount }
            return total > 0 ? (cat, total) : nil
        }
        .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    MonthSelectorView(selectedMonth: $selectedMonth)

                    TotalCardView(total: totalSpend)

                    if categoryTotals.isEmpty {
                        ContentUnavailableView(
                            "Nenhum gasto ainda",
                            systemImage: "tray",
                            description: Text("Toque em + para adicionar seu primeiro gasto")
                        )
                        .padding(.top, 40)
                    } else {
                        CategoryChartView(categoryTotals: categoryTotals)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(categoryTotals, id: \.category.id) { item in
                                Button {
                                    selectedCategory = item.category
                                } label: {
                                    CategoryRowView(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Resumo")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
            .navigationDestination(item: $selectedCategory) { cat in
                CategoryDetailView(category: cat, month: selectedMonth)
            }
        }
    }
}

// MARK: - Month Selector

struct MonthSelectorView: View {
    @Binding var selectedMonth: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private var canGoForward: Bool {
        let next = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)!
        return next <= Date()
    }

    var body: some View {
        HStack {
            Button {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth)!
            } label: {
                Image(systemName: "chevron.left")
                    .padding(8)
            }
            Spacer()
            Text(Self.formatter.string(from: selectedMonth))
                .font(.headline)
            Spacer()
            Button {
                if canGoForward {
                    selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth)!
                }
            } label: {
                Image(systemName: "chevron.right")
                    .padding(8)
                    .opacity(canGoForward ? 1 : 0.3)
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal)
    }
}

// MARK: - Total Card

struct TotalCardView: View {
    let total: Double

    var body: some View {
        VStack(spacing: 4) {
            Text("Total Gasto")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(total, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                .font(.system(size: 38, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

// MARK: - Donut Chart

struct CategoryChartView: View {
    let categoryTotals: [(category: ExpenseCategory, total: Double)]

    var body: some View {
        Chart(categoryTotals, id: \.category.id) { item in
            SectorMark(
                angle: .value("Valor", item.total),
                innerRadius: .ratio(0.55),
                outerRadius: .ratio(0.9)
            )
            .foregroundStyle(item.category.color)
            .cornerRadius(4)
        }
        .frame(height: 220)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Category Row

struct CategoryRowView: View {
    let item: (category: ExpenseCategory, total: Double)

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(item.category.color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: item.category.sfSymbol)
                    .foregroundStyle(item.category.color)
            }
            Text(item.category.name)
                .foregroundStyle(.primary)
            Spacer()
            Text(item.total, format: .currency(code: Locale.current.currency?.identifier ?? "BRL"))
                .foregroundStyle(.secondary)
                .fontWeight(.medium)
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Calendar helper

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps)!
    }
}
