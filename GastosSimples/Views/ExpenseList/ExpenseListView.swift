import SwiftUI
import SwiftData

struct ExpenseListView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]
    @State private var showAddExpense = false
    @State private var filterCategory: ExpenseCategory?
    @State private var searchText = ""
    @State private var expenseToDelete: Expense?

    private var filtered: [Expense] {
        expenses.filter { expense in
            let matchesCategory = filterCategory == nil || expense.category?.id == filterCategory?.id
            let matchesSearch = searchText.isEmpty ||
                expense.merchantName.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "Nenhum Gasto" : "Nenhum Resultado",
                        systemImage: searchText.isEmpty ? "list.bullet.rectangle" : "magnifyingglass",
                        description: Text(searchText.isEmpty ? "Toque em + para adicionar seu primeiro gasto" : "Tente outro termo de busca")
                    )
                } else {
                    List {
                        ForEach(filtered) { expense in
                            ExpenseRowView(expense: expense)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        expenseToDelete = expense
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Gastos")
            .searchable(text: $searchText, prompt: "Buscar estabelecimento")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Todas as Categorias") {
                            filterCategory = nil
                        }
                        Divider()
                        ForEach(categories) { cat in
                            Button {
                                filterCategory = cat
                            } label: {
                                Label(cat.name, systemImage: cat.sfSymbol)
                            }
                        }
                    } label: {
                        Label(
                            filterCategory?.name ?? "Filtrar",
                            systemImage: filterCategory == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                }
            }
            .sheet(isPresented: $showAddExpense) {
                AddExpenseView()
            }
            .confirmationDialog(
                "Excluir este gasto?",
                isPresented: .constant(expenseToDelete != nil),
                titleVisibility: .visible
            ) {
                Button("Excluir", role: .destructive) {
                    if let expense = expenseToDelete {
                        deleteExpense(expense)
                    }
                    expenseToDelete = nil
                }
                Button("Cancelar", role: .cancel) {
                    expenseToDelete = nil
                }
            } message: {
                if let expense = expenseToDelete {
                    Text("\"\(expense.merchantName)\" será removido permanentemente.")
                }
            }
        }
    }

    @Environment(\.modelContext) private var context

    private func deleteExpense(_ expense: Expense) {
        context.delete(expense)
        try? context.save()
    }
}
