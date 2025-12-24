import Foundation
import Speech
import AVFoundation

// MARK: - Voice Transaction Service

@MainActor
final class VoiceTransactionService: NSObject, ObservableObject {
    static let shared = VoiceTransactionService()

    @Published var isListening: Bool = false
    @Published var recognizedText: String = ""
    @Published var errorMessage: String?
    @Published var isAuthorized: Bool = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override private init() {
        super.init()
        setupSpeechRecognizer()
    }

    // MARK: - Setup

    private func setupSpeechRecognizer() {
        let locale = Locale.current.language.languageCode?.identifier == "ko"
            ? Locale(identifier: "ko-KR")
            : Locale(identifier: "en-US")

        speechRecognizer = SFSpeechRecognizer(locale: locale)
        speechRecognizer?.delegate = self
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.isAuthorized = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }

    // MARK: - Recording

    func startListening() async throws {
        // Prevent multiple simultaneous sessions
        guard !isListening else {
            return
        }

        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = String(localized: "voice.error.not_available")
            throw VoiceError.notAvailable
        }

        // Request microphone permission
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw VoiceError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Remove any existing tap before installing new one
        inputNode.removeTap(onBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.recognizedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self?.stopListening()
                }
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isListening = true
            recognizedText = ""
        } catch {
            // Clean up on error - remove tap and deactivate audio session
            inputNode.removeTap(onBus: 0)
            self.recognitionRequest?.endAudio()
            self.recognitionTask?.cancel()
            self.recognitionRequest = nil
            self.recognitionTask = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        isListening = false
    }

    // MARK: - Parsing

    func parseVoiceInput(_ text: String) -> ParsedTransaction {
        var result = ParsedTransaction()

        let lowercasedText = text.lowercased()

        // 1. Determine transaction type
        if lowercasedText.contains("수입") || lowercasedText.contains("받") ||
           lowercasedText.contains("income") || lowercasedText.contains("월급") ||
           lowercasedText.contains("용돈") {
            result.type = .income
        } else {
            result.type = .expense
        }

        // 2. Extract amount (Korean and English patterns)
        result.amount = extractAmount(from: text)

        // 3. Extract date references
        result.date = extractDate(from: lowercasedText)

        // 4. Extract category keyword
        result.suggestedCategoryKeyword = extractCategoryKeyword(from: lowercasedText)

        // 5. Set the original text as note
        result.note = cleanNoteText(text)

        return result
    }

    // MARK: - Private Parsing Methods

    private func extractAmount(from text: String) -> Decimal? {
        var workingText = text.lowercased()

        // Korean currency patterns: 5천원, 1만원, 10만5천원, 5000원
        let koreanPatterns: [(pattern: String, multiplier: Decimal)] = [
            ("(\\d+)억", 100_000_000),
            ("(\\d+)천만", 10_000_000),
            ("(\\d+)백만", 1_000_000),
            ("(\\d+)만", 10_000),
            ("(\\d+)천", 1_000),
            ("(\\d+)백", 100)
        ]

        var totalAmount: Decimal = 0

        for (pattern, multiplier) in koreanPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }

            while let match = regex.firstMatch(
                in: workingText,
                options: [],
                range: NSRange(workingText.startIndex..., in: workingText)
            ) {
                guard let numberRange = Range(match.range(at: 1), in: workingText),
                      let number = Decimal(string: String(workingText[numberRange])),
                      let fullRange = Range(match.range(at: 0), in: workingText) else {
                    break
                }

                totalAmount += number * multiplier
                workingText.replaceSubrange(fullRange, with: "")
            }
        }

        if totalAmount > 0 {
            return totalAmount
        }

        // Simple number extraction (e.g., "5000원", "$50", "50 dollars")
        let numberPattern = "(\\d+\\.?\\d*)"
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []),
           let match = regex.firstMatch(in: workingText, options: [], range: NSRange(workingText.startIndex..., in: workingText)),
           let range = Range(match.range(at: 1), in: workingText),
           let amount = Decimal(string: String(workingText[range])) {
            return amount
        }

        return nil
    }

    private func extractDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let today = Date()

        // Korean date references
        let koreanDateMap: [String: Int] = [
            "오늘": 0,
            "어제": -1,
            "그제": -2,
            "그저께": -2,
            "이틀전": -2,
            "삼일전": -3,
            "사일전": -4,
            "오일전": -5,
            "일주일전": -7,
            "저번주": -7
        ]

        // English date references
        let englishDateMap: [String: Int] = [
            "today": 0,
            "yesterday": -1,
            "day before": -2,
            "last week": -7
        ]

        for (keyword, offset) in koreanDateMap {
            if text.contains(keyword) {
                return calendar.date(byAdding: .day, value: offset, to: today)
            }
        }

        for (keyword, offset) in englishDateMap {
            if text.contains(keyword) {
                return calendar.date(byAdding: .day, value: offset, to: today)
            }
        }

        return today
    }

    private func extractCategoryKeyword(from text: String) -> String? {
        // Korean category keywords
        let koreanCategoryKeywords: [String: String] = [
            // Food
            "커피": "food",
            "카페": "food",
            "밥": "food",
            "점심": "food",
            "저녁": "food",
            "아침": "food",
            "식사": "food",
            "음식": "food",
            "치킨": "food",
            "피자": "food",
            "편의점": "food",
            "마트": "food",
            "배달": "food",

            // Shopping
            "쇼핑": "shopping",
            "옷": "shopping",
            "신발": "shopping",
            "구매": "shopping",
            "백화점": "shopping",

            // Transport
            "택시": "transport",
            "버스": "transport",
            "지하철": "transport",
            "교통": "transport",
            "기름": "transport",
            "주유": "transport",

            // Housing
            "월세": "housing",
            "관리비": "housing",
            "전기세": "housing",
            "가스": "housing",

            // Telecom
            "통신": "telecom",
            "핸드폰": "telecom",
            "인터넷": "telecom",

            // Medical
            "병원": "medical",
            "약": "medical",
            "의료": "medical",

            // Education
            "학원": "education",
            "교육": "education",
            "책": "education",

            // Entertainment
            "영화": "entertainment",
            "게임": "entertainment",
            "노래방": "entertainment",
            "술": "entertainment",

            // Income
            "월급": "salary",
            "급여": "salary",
            "보너스": "salary",
            "용돈": "side_income",
            "투자": "investment"
        ]

        // English category keywords
        let englishCategoryKeywords: [String: String] = [
            "coffee": "food",
            "cafe": "food",
            "lunch": "food",
            "dinner": "food",
            "breakfast": "food",
            "food": "food",
            "grocery": "food",

            "shopping": "shopping",
            "clothes": "shopping",
            "shoes": "shopping",

            "taxi": "transport",
            "bus": "transport",
            "subway": "transport",
            "gas": "transport",

            "rent": "housing",
            "utility": "housing",

            "phone": "telecom",
            "internet": "telecom",

            "hospital": "medical",
            "medicine": "medical",

            "education": "education",
            "book": "education",

            "movie": "entertainment",
            "game": "entertainment",

            "salary": "salary",
            "income": "salary",
            "bonus": "salary"
        ]

        for (keyword, category) in koreanCategoryKeywords {
            if text.contains(keyword) {
                return category
            }
        }

        for (keyword, category) in englishCategoryKeywords {
            if text.contains(keyword) {
                return category
            }
        }

        return nil
    }

    private func cleanNoteText(_ text: String) -> String {
        // Remove common words and keep meaningful content
        var note = text

        // Remove amount-related words
        let removePatterns = ["원", "달러", "dollar", "won"]
        for pattern in removePatterns {
            note = note.replacingOccurrences(of: pattern, with: "")
        }

        // Remove date references
        let dateWords = ["오늘", "어제", "그제", "today", "yesterday"]
        for word in dateWords {
            note = note.replacingOccurrences(of: word, with: "")
        }

        // Clean up whitespace
        note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        note = note.replacingOccurrences(of: "  ", with: " ")

        return note.isEmpty ? text : note
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceTransactionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.errorMessage = String(localized: "voice.error.not_available")
            }
        }
    }
}

// MARK: - Voice Error

enum VoiceError: Error, LocalizedError {
    case notAvailable
    case notAuthorized
    case requestCreationFailed
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return String(localized: "voice.error.not_available")
        case .notAuthorized:
            return String(localized: "voice.error.not_authorized")
        case .requestCreationFailed:
            return String(localized: "voice.error.request_failed")
        case .recognitionFailed:
            return String(localized: "voice.error.recognition_failed")
        }
    }
}
