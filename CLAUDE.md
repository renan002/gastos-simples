# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

The `.xcodeproj` is generated from `project.yml` via **xcodegen** — never edit `project.pbxproj` directly.

```bash
# Regenerate .xcodeproj after editing project.yml or adding/removing files
xcodegen generate

# Build from the command line (simulator)
xcodebuild -project GastosSimples.xcodeproj -scheme GastosSimples \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Open in Xcode
open GastosSimples.xcodeproj
```

**Important:** The photo picker and Vision OCR only work on a **physical device**. The simulator cannot access real screenshots from the photo library.

There are no automated tests yet. Manual testing on device is the verification path described in the plan.

## Project Configuration

- **Target:** iOS 18+, Swift 6, Xcode 16+
- **Concurrency:** `SWIFT_STRICT_CONCURRENCY = targeted` (not `complete`) to allow SwiftData models without pervasive `@MainActor` annotations
- **Bundle ID:** `com.gastossimples.app`
- **Orientation:** Portrait only (`UISupportedInterfaceOrientations`)
- To add a new file: create the `.swift` file in the right folder, then run `xcodegen generate`

## Architecture

**Pattern:** MVVM-lite — views own their state via `@State`; SwiftData's `@Query` replaces a dedicated ViewModel layer for reads.

### Data layer (`Models/`)
- `Expense` — SwiftData `@Model`. Stores amount, merchant, date, optional thumbnail (`Data`), and installment fields (`isInstallment`, `totalInstallments`, `currentInstallment`). `installmentAmount` divides total by installments; `installmentLabel` returns `"2/12"` strings for UI badges.
- `ExpenseCategory` — SwiftData `@Model`. Owns the inverse relationship to `Expense`. Seeds 8 default categories on first launch via `seedDefaultsIfNeeded(in:)` called from `GastosSimpleApp.init`. Color is stored as a hex string (`colorHex`); `Color(hex:)` is a failable initialiser in `ExpenseCategory.swift`.

### Services layer (`Services/`)
- `OCRService` — Swift `actor` singleton. Wraps `VNRecognizeTextRequest` (revision 3, `.accurate`, `["pt-BR", "en-US"]`) in `withCheckedThrowingContinuation`. Vision observations are sorted top-to-bottom before joining (Vision's y-axis is inverted).
- `ParserService` — `Sendable` struct with only static methods. Tries amount patterns in specificity order (Brazilian `R$` with thousands separator first, then bare `R$`, then USD, then labeled fields like "Total:"). Normalises Brazilian format (`1.299,90` → `1299.90`). Uses `NSDataDetector` for dates. Merchant extraction skips lines matching a deny-list of patterns (currency symbols, CPF/CNPJ, boilerplate words).

### Add Expense flow (`Views/AddExpense/`)
`AddExpenseView` drives a 5-step state machine via `enum Step`. Each step is a separate view; navigation is handled by swapping `stepContent` with `withAnimation`. The step enum's `previous` computed property defines the back-navigation path. OCR fires in a `Task` from `processImage(_:)` and writes results back on `MainActor`.

Steps: `pickPhoto → processing → review → category → installments → (save & dismiss)`

### Dashboard (`Views/Dashboard/`)
`DashboardView` uses two `@Query` properties (all expenses + all categories) and filters in-memory by the selected month. `categoryTotals` is a computed property that pairs each category with its monthly sum, excluding zero-total categories. Tapping a category row sets `selectedCategory` which drives `navigationDestination(item:)` to `CategoryDetailView`.

### Category Detail (`Views/CategoryDetail/`)
`CategoryDetailView` receives a category and month as init parameters. It fetches all expenses via `@Query` then filters in a computed property (rather than using a `#Predicate` on the relationship, which has SwiftData limitations). Includes a `SpendingBarChart` that groups expenses by day-of-month.

### Shared conventions
- Currency display uses `Locale.current.currency?.identifier ?? "BRL"` — respects device locale while defaulting to Brazilian Real.
- All `@Model` context saves use `try? context.save()` (non-throwing) since SwiftData failures at this layer are non-recoverable in the current design.
- `Color(hex:)` is defined once in `ExpenseCategory.swift`; do not add a second definition elsewhere.
