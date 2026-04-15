import SwiftUI

struct InstallmentSheet: View {
    @Binding var isInstallment: Bool
    @Binding var totalInstallments: Int
    @Binding var currentInstallment: Int
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: isInstallment ? "calendar.badge.clock" : "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .padding(.top, 8)
                    .animation(.spring, value: isInstallment)

                VStack(spacing: 8) {
                    Text("Como você pagou?")
                        .font(.title2.bold())
                    Text("Informe se a compra foi parcelada para registrarmos cada parcela.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                // Payment type picker
                Picker("Forma de pagamento", selection: $isInstallment) {
                    Text("À vista").tag(false)
                    Text("Parcelado").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if isInstallment {
                    GroupBox("Detalhes do Parcelamento") {
                        VStack(spacing: 16) {
                            Stepper("Total de parcelas: \(totalInstallments)x",
                                    value: $totalInstallments, in: 2...60)
                            .onChange(of: totalInstallments) { _, new in
                                if currentInstallment > new { currentInstallment = new }
                            }

                            Divider()

                            Stepper("Parcela \(currentInstallment) de \(totalInstallments)",
                                    value: $currentInstallment, in: 1...totalInstallments)
                        }
                        .padding(.vertical, 4)
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                Button(action: onSave) {
                    Text("Salvar Gasto")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .animation(.spring(response: 0.35), value: isInstallment)
        }
    }
}
