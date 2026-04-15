import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Resumo", systemImage: "chart.pie.fill") {
                DashboardView()
            }
            Tab("Gastos", systemImage: "list.bullet.rectangle") {
                ExpenseListView()
            }
        }
    }
}
