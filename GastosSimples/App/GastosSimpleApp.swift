import SwiftUI
import SwiftData

@main
struct GastosSimpleApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Expense.self, ExpenseCategory.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            Task { @MainActor [container] in
                ExpenseCategory.seedDefaultsIfNeeded(in: container.mainContext)
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
