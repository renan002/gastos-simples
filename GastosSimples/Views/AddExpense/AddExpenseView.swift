import SwiftUI
import SwiftData
import PhotosUI

/// Multi-step flow: Pick screenshot → Crop area → OCR → Review → Category → Installments → Save
struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \ExpenseCategory.name) private var categories: [ExpenseCategory]

    enum Step { case pickPhoto, cropSelection, processing, review, category, installments }

    @State private var step: Step = .pickPhoto
    @State private var photoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Editable OCR fields
    @State private var merchantName = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var selectedCategory: ExpenseCategory?

    // Installment fields
    @State private var isInstallment = false
    @State private var totalInstallments = 2
    @State private var currentInstallment = 1

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            stepContent
                .navigationTitle(step.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancelar") { dismiss() }
                    }
                    if step.canGoBack {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                withAnimation { step = step.previous }
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                        }
                    }
                }
                .alert("Não foi possível ler a captura", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") {
                        errorMessage = nil
                        step = .pickPhoto
                    }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .pickPhoto:
            PhotoPickStep(photoItem: $photoItem, onPicked: handleImagePicked)

        case .cropSelection:
            if let image = selectedImage {
                CropSelectionView(image: image) { cropped in
                    runOCR(on: cropped)
                } onSkip: {
                    runOCR(on: image)
                }
            }

        case .processing:
            ProcessingView()

        case .review:
            ReviewStep(
                image: selectedImage,
                merchantName: $merchantName,
                amountText: $amountText,
                date: $date
            ) {
                withAnimation { step = .category }
            }

        case .category:
            CategoryPickerView(
                categories: categories,
                selected: $selectedCategory
            ) {
                withAnimation { step = .installments }
            }

        case .installments:
            InstallmentSheet(
                isInstallment: $isInstallment,
                totalInstallments: $totalInstallments,
                currentInstallment: $currentInstallment,
                onSave: saveExpense
            )
        }
    }

    // MARK: - OCR

    /// Called when the user picks a photo — advances to the crop step.
    private func handleImagePicked(_ image: UIImage) {
        selectedImage = image
        withAnimation { step = .cropSelection }
    }

    /// Called with the (possibly cropped) image — runs OCR and advances to review.
    private func runOCR(on image: UIImage) {
        step = .processing
        Task {
            do {
                let lines = try await OCRService.shared.recognizeText(in: image)
                let parsed = await ParserService.parse(from: lines)
                await MainActor.run {
                    merchantName = parsed.merchantName
                    amountText = parsed.amount.map { AddExpenseView.amountFormatter.string(from: NSNumber(value: $0)) ?? "" } ?? ""
                    date = parsed.date ?? Date()
                    withAnimation { step = .review }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.locale = .current
        return f
    }()

    // MARK: - Save

    private func saveExpense() {
        guard let amount = AddExpenseView.amountFormatter.number(from: amountText)?.doubleValue
                        ?? Double(amountText.replacingOccurrences(of: ",", with: "."))
        else { return }

        let thumbnail = selectedImage?
            .preparingThumbnail(of: CGSize(width: 120, height: 160))?
            .jpegData(compressionQuality: 0.7)

        let expense = Expense(
            merchantName: merchantName,
            amount: amount,
            date: date,
            category: selectedCategory,
            isInstallment: isInstallment,
            totalInstallments: isInstallment ? totalInstallments : 1,
            currentInstallment: isInstallment ? currentInstallment : 1,
            screenshotThumbnail: thumbnail
        )
        context.insert(expense)
        try? context.save()
        dismiss()
    }
}

// MARK: - Step metadata

private extension AddExpenseView.Step {
    var title: String {
        switch self {
        case .pickPhoto:     "Novo Gasto"
        case .cropSelection: "Selecionar Área"
        case .processing:    "Lendo Captura"
        case .review:        "Revisar Dados"
        case .category:      "Categoria"
        case .installments:  "Forma de Pagamento"
        }
    }

    var canGoBack: Bool {
        switch self {
        case .pickPhoto, .processing: false
        default: true
        }
    }

    var previous: AddExpenseView.Step {
        switch self {
        case .cropSelection: .pickPhoto
        case .review:        .cropSelection
        case .category:      .review
        case .installments:  .category
        default:             .pickPhoto
        }
    }
}

// MARK: - Photo Pick Step

struct PhotoPickStep: View {
    @Binding var photoItem: PhotosPickerItem?
    let onPicked: (UIImage) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "photo.badge.magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Escolha uma Captura")
                    .font(.title2.bold())
                Text("Selecione um comprovante, recibo ou notificação bancária da sua galeria.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            PhotosPicker(
                selection: $photoItem,
                matching: .images
            ) {
                Label("Escolher Captura", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run { onPicked(image) }
                    }
                }
            }
            Spacer()
        }
        .padding()
    }
}

// MARK: - Processing View

struct ProcessingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Lendo captura de tela…")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Review Step

struct ReviewStep: View {
    let image: UIImage?
    @Binding var merchantName: String
    @Binding var amountText: String
    @Binding var date: Date
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(radius: 4)
                }

                GroupBox("Dados do Gasto") {
                    VStack(spacing: 14) {
                        HStack {
                            Label("Estabelecimento", systemImage: "storefront")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("Nome", text: $merchantName)
                                .multilineTextAlignment(.trailing)
                        }
                        Divider()
                        HStack {
                            Label("Valor", systemImage: "brazilianrealsign")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0,00", text: $amountText)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                                .frame(maxWidth: 120)
                        }
                        Divider()
                        DatePicker(
                            "Data",
                            selection: $date,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .environment(\.locale, Locale(identifier: "pt_BR"))
                    }
                    .padding(.vertical, 4)
                }

                Button(action: onNext) {
                    Text("Continuar")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding()
        }
    }
}
