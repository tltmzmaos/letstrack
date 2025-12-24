import Foundation
@preconcurrency import Vision
import UIKit

// MARK: - OCR Result

struct ReceiptOCRResult: Sendable {
    let extractedAmount: Decimal?
    let allAmounts: [Decimal]
    let rawText: String
    let confidence: Float

    var hasAmount: Bool {
        extractedAmount != nil
    }
}

// MARK: - Receipt OCR Service

@MainActor
final class ReceiptOCRService {
    static let shared = ReceiptOCRService()

    private init() {}

    /// Extract amount from receipt image
    func extractAmount(from imageData: Data) async -> ReceiptOCRResult {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            return ReceiptOCRResult(extractedAmount: nil, allAmounts: [], rawText: "", confidence: 0)
        }

        return await performOCR(on: cgImage)
    }

    /// Extract amount from UIImage
    func extractAmount(from image: UIImage) async -> ReceiptOCRResult {
        guard let cgImage = image.cgImage else {
            return ReceiptOCRResult(extractedAmount: nil, allAmounts: [], rawText: "", confidence: 0)
        }

        return await performOCR(on: cgImage)
    }

    // MARK: - Private Methods

    nonisolated private func performOCR(on cgImage: CGImage) async -> ReceiptOCRResult {
        await withCheckedContinuation { continuation in
            var recognizedObservations: [VNRecognizedTextObservation] = []

            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                recognizedObservations = observations
            }

            // Configure for receipt text recognition
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                let result = processObservations(recognizedObservations)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(returning: ReceiptOCRResult(extractedAmount: nil, allAmounts: [], rawText: "", confidence: 0))
            }
        }
    }

    nonisolated private func processObservations(_ observations: [VNRecognizedTextObservation]) -> ReceiptOCRResult {
        var allText = ""
        var priceRelatedAmounts: [(amount: Decimal, confidence: Float, priority: Int)] = []
        var totalConfidence: Float = 0
        var observationCount = 0

        // Keywords that indicate total/final amount (highest priority)
        let totalKeywords = [
            "합계", "총액", "총합", "결제금액", "결제 금액", "카드결제", "카드 결제",
            "total", "grand total", "합 계", "청구금액", "청구 금액", "받을금액",
            "실결제", "실 결제", "최종금액", "최종 금액", "승인금액", "승인 금액",
            "payment", "amount due", "balance due", "총 결제"
        ]

        // Keywords that indicate price-related context (medium priority)
        let priceKeywords = [
            "금액", "가격", "단가", "소계", "price", "subtotal", "sub total",
            "부가세", "vat", "tax", "할인", "discount", "적립", "포인트",
            "현금", "cash", "card", "카드", "수량", "qty", "원"
        ]

        // Keywords to EXCLUDE (dates, phone numbers, etc.)
        let excludeKeywords = [
            "tel", "전화", "fax", "팩스", "사업자", "등록번호", "대표",
            "주소", "address", "date", "일시", "시간", "time",
            "no.", "번호", "order", "주문", "영수증", "receipt"
        ]

        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }

            let text = topCandidate.string
            allText += text + "\n"
            totalConfidence += topCandidate.confidence
            observationCount += 1

            let lowercasedText = text.lowercased()

            // Skip lines that likely contain non-price numbers
            let shouldExclude = excludeKeywords.contains { lowercasedText.contains($0.lowercased()) }
            if shouldExclude && !priceKeywords.contains(where: { lowercasedText.contains($0.lowercased()) }) {
                continue
            }

            // Extract amounts from this line
            let amounts = extractAmounts(from: text)

            for amount in amounts {
                var priority = 0

                // Check for total keywords (highest priority)
                if totalKeywords.contains(where: { lowercasedText.contains($0.lowercased()) }) {
                    priority = 3
                }
                // Check for price keywords (medium priority)
                else if priceKeywords.contains(where: { lowercasedText.contains($0.lowercased()) }) {
                    priority = 2
                }
                // Has currency symbol (low-medium priority)
                else if text.contains("원") || text.contains("₩") || text.contains("$") {
                    priority = 1
                }

                priceRelatedAmounts.append((amount: amount, confidence: topCandidate.confidence, priority: priority))
            }
        }

        // Sort by priority first, then by amount (descending)
        let sortedAmounts = priceRelatedAmounts.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority > rhs.priority
            }
            return lhs.amount > rhs.amount
        }

        // Get unique amounts preserving order
        var seenAmounts = Set<Decimal>()
        let uniqueAmounts = sortedAmounts.compactMap { item -> Decimal? in
            if seenAmounts.contains(item.amount) {
                return nil
            }
            seenAmounts.insert(item.amount)
            return item.amount
        }

        // Determine the best amount to return
        let finalAmount: Decimal?
        let finalConfidence: Float

        if let bestMatch = sortedAmounts.first, bestMatch.priority >= 2 {
            // We have a high-priority match (total or price keyword)
            finalAmount = bestMatch.amount
            finalConfidence = bestMatch.confidence
        } else if let highPriorityAmount = sortedAmounts.first(where: { $0.priority >= 1 }) {
            // We have a medium-priority match (currency symbol)
            finalAmount = highPriorityAmount.amount
            finalConfidence = highPriorityAmount.confidence
        } else if let largest = uniqueAmounts.first, largest >= 100 {
            // Fallback to largest amount only if it's reasonably large
            finalAmount = largest
            finalConfidence = observationCount > 0 ? totalConfidence / Float(observationCount) : 0
        } else {
            finalAmount = nil
            finalConfidence = 0
        }

        return ReceiptOCRResult(
            extractedAmount: finalAmount,
            allAmounts: uniqueAmounts,
            rawText: allText,
            confidence: finalConfidence
        )
    }

    nonisolated private func extractAmounts(from text: String) -> [Decimal] {
        var amounts: [Decimal] = []

        // Pattern for Korean Won amounts: 1,000원, 10,000, ₩5000, etc.
        // Also matches: $10.00, 10.50, etc.
        let patterns: [String] = [
            // Korean style with 원: 1,234원 or 1,234 원 (highest priority - explicit currency)
            #"[\d,]+\s*원"#,
            // Currency symbol prefix: ₩1,234 or $ 10.00 (high priority)
            #"[₩$€¥]\s*[\d,.]+"#,
            // Decimal numbers for USD style: 10.00, 123.45 (medium priority)
            #"\b\d+\.\d{2}\b"#,
            // Numbers with commas (Korean style): 1,000 or 10,000 (medium priority)
            #"\b\d{1,3}(?:,\d{3})+\b"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    if let matchRange = Range(match.range, in: text) {
                        let matchedString = String(text[matchRange])
                        if let amount = parseAmount(from: matchedString) {
                            amounts.append(amount)
                        }
                    }
                }
            }
        }

        return amounts
    }

    nonisolated private func parseAmount(from string: String) -> Decimal? {
        // Remove currency symbols and whitespace
        let cleaned = string
            .replacingOccurrences(of: "원", with: "")
            .replacingOccurrences(of: "₩", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let decimal = Decimal(string: cleaned), decimal > 0 else {
            return nil
        }

        // Filter out unreasonable amounts
        // Minimum: 100 (to avoid matching small numbers like dates, quantities)
        // Maximum: 100,000,000 (100 million)
        if decimal < 100 || decimal > 100_000_000 {
            return nil
        }

        // Skip numbers that look like dates (e.g., 2024, 1225)
        if decimal >= 1900 && decimal <= 2100 {
            return nil
        }

        // Skip numbers that look like times or short codes
        if cleaned.count <= 4 && decimal < 1000 {
            return nil
        }

        return decimal
    }
}
