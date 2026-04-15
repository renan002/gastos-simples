import Foundation
import FoundationModels

/// Result of parsing OCR lines from a payment screenshot.
struct ParsedExpense: Sendable {
    var merchantName: String
    var amount: Double?
    var date: Date?
}

// MARK: - Foundation Models structured output

@Generable()
private struct LLMExpenseFields {
    @Guide(description: "Nome do estabelecimento ou loja onde a compra foi feita. Retorne apenas o nome limpo, sem valores monetários, datas ou palavras como 'total', 'pix', 'comprovante', 'recibo'.")
    var merchantName: String

    @Guide(description: "Valor da transação como string numérica com ponto decimal. Exemplos: '59.90' para R$ 59,90 ou '1299.90' para R$ 1.299,90. Retorne null se não houver valor claro no texto.")
    var amountString: String?
}

/// Pure value-type parser — safe to call from any context.
struct ParserService: Sendable {

    static func parse(from lines: [OCRLine]) async -> ParsedExpense {
        // Date uses bounding-box logic (notification timestamp position) — always run locally.
        let date = extractDate(from: lines)

        // Foundation Models path: richer context understanding for merchant + amount.
        if case .available = SystemLanguageModel.default.availability {
            if let llm = try? await extractWithLLM(from: lines) {
                return ParsedExpense(
                    merchantName: llm.merchantName,
                    amount: llm.amountString.flatMap(parseAmountString),
                    date: date
                )
            }
        }

        // Fallback: regex-based extraction when Apple Intelligence is unavailable.
        let ocrText = lines.map(\.text).joined(separator: "\n")
        return ParsedExpense(
            merchantName: extractMerchant(from: lines),
            amount: extractAmount(from: ocrText),
            date: date
        )
    }

    // MARK: - Foundation Models extraction

    private static func extractWithLLM(from lines: [OCRLine]) async throws -> LLMExpenseFields {
        // Exclude notification timestamp lines — they're iOS UI metadata, not receipt data.
        let receiptText = lines
            .filter { !$0.isNotificationTimestamp }
            .map(\.text)
            .joined(separator: "\n")

        let session = LanguageModelSession {
            "Você é um assistente especializado em extrair dados de comprovantes de pagamento brasileiros. Analise o texto fornecido e retorne apenas os dados estruturados solicitados, sem explicações adicionais."
        }

        let prompt = """
        Extraia o nome do estabelecimento e o valor pago do seguinte texto de comprovante de pagamento:

        \(receiptText)
        """

        let response = try await session.respond(to: prompt, generating: LLMExpenseFields.self)
        return response.content
    }

    /// Parses the numeric string returned by the LLM into a Double.
    /// The LLM is instructed to use dot-decimal, but guards against Brazilian format leaking through.
    private static func parseAmountString(_ raw: String) -> Double? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        // Both separators present → Brazilian thousands + decimal (1.299,90)
        if s.contains(".") && s.contains(",") {
            return Double(s.replacingOccurrences(of: ".", with: "")
                          .replacingOccurrences(of: ",", with: "."))
        }
        // Comma-only decimal (59,90) → dot decimal
        if s.contains(",") {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return Double(s)
    }

    // MARK: - Amount (regex fallback)

    private static func extractAmount(from text: String) -> Double? {
        let patterns: [String] = [
            #"R\$\s*(\d{1,3}(?:\.\d{3})*,\d{2})"#,      // R$ 1.299,90
            #"R\$\s*(\d+,\d{2})"#,                        // R$ 59,90
            #"\$\s*(\d{1,3}(?:,\d{3})*\.\d{2})"#,        // $ 1,299.90
            #"\$\s*(\d+\.\d{2})"#,                        // $ 59.90
            #"(?i)(?:total|valor|amount|subtotal)\s*[:\s]+R?\$?\s*(\d[\d.,]+)"#,
        ]

        for pattern in patterns {
            guard let regex = try? Regex(pattern),
                  let match = text.firstMatch(of: regex),
                  let captured = match.output[1].substring else { continue }

            let raw = String(captured)
            let normalised: String
            if raw.contains(",") && !raw.contains(".") {
                normalised = raw.replacingOccurrences(of: ",", with: ".")
            } else if raw.contains(".") && raw.contains(",") {
                normalised = raw.replacingOccurrences(of: ".", with: "")
                              .replacingOccurrences(of: ",", with: ".")
            } else {
                normalised = raw
            }

            if let value = Double(normalised) {
                return value
            }
        }
        return nil
    }

    // MARK: - Date

    private static func extractDate(from lines: [OCRLine]) -> Date? {
        // Priority: notification timestamp in the top-right corner.
        let topRight = lines.filter(\.isNotificationTimestamp)
        for line in topRight {
            if let date = parseNotificationTimestamp(line.text) {
                return date
            }
        }

        // Fallback: NSDataDetector on the full text.
        let fullText = lines.map(\.text).joined(separator: "\n")
        return detectDate(in: fullText)
    }

    private static func parseNotificationTimestamp(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let now = Date()
        let calendar = Calendar.current

        if text == "agora" || text == "now" { return now }

        if text == "ontem" || text == "yesterday" {
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        }

        if let m = firstInt(#"(?:há\s+)?(\d+)\s*min"#, in: text) {
            return now.addingTimeInterval(-Double(m) * 60)
        }

        if let h = firstInt(#"(?:há\s+)?(\d+)\s*h(?:r|s)?"#, in: text) {
            return now.addingTimeInterval(-Double(h) * 3600)
        }

        if let d = firstInt(#"(?:há\s+)?(\d+)\s*dia"#, in: text) ?? firstInt(#"(\d+)\s*day"#, in: text) {
            return calendar.date(byAdding: .day, value: -d, to: calendar.startOfDay(for: now))
        }

        if let match = try? Regex(#"^(\d{1,2}):(\d{2})$"#).firstMatch(in: text),
           let hour   = Int(String(match.output[1].substring ?? "")),
           let minute = Int(String(match.output[2].substring ?? "")) {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps)
        }

        return nil
    }

    private static func detectDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        ) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, options: [], range: range).first?.date
    }

    private static func firstInt(_ pattern: String, in text: String) -> Int? {
        guard let regex = try? Regex(pattern),
              let match = text.firstMatch(of: regex),
              let sub = match.output[1].substring else { return nil }
        return Int(String(sub))
    }

    // MARK: - Merchant (regex fallback)

    private static func extractMerchant(from lines: [OCRLine]) -> String {
        let skipPatterns: [String] = [
            #"R\$"#, #"\$"#,
            #"^\d{2}/\d{2}"#, #"^\d{2}:\d{2}"#,
            #"CPF|CNPJ"#,
            #"(?i)total|subtotal|parcela|comprovante|recibo|fatura|pagamento|transação|transferência|pix|via\s"#,
            #"^[\d\s\.\-\(\)\/\*#]+$"#,
            #"(?i)\b(nubank|itaú|itau|bradesco|santander|banco\s+do\s+brasil|bb|caixa|inter|c6\s*bank|next|neon|original|sicredi|sicoob|banrisul|safra|modal|bmg|pan|picpay|mercado\s*pago|pagseguro|paypal|stone|cielo|getnet|rede\s+credenciadora|pagbank|will\s*bank|digio|bs2|btg|xp\s*investimentos|avenue|wise|nomad)\b"#,
        ]

        let candidateLines = lines
            .filter { !$0.isNotificationTimestamp }
            .map(\.text)
            .filter { line in
                guard line.count >= 3 else { return false }
                return !skipPatterns.contains { pattern in
                    (try? Regex(pattern).firstMatch(in: line)) != nil
                }
            }

        if let allCaps = candidateLines.first(where: { isAllCaps($0) }) {
            return allCaps
        }

        return candidateLines.first ?? lines.first?.text ?? "Unknown"
    }

    private static func isAllCaps(_ line: String) -> Bool {
        let letters = line.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 3 else { return false }
        let uppercased = letters.filter { CharacterSet.uppercaseLetters.contains($0) }
        return Double(uppercased.count) / Double(letters.count) >= 0.85
    }
}
