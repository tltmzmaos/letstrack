import SwiftUI
import SwiftData
import AVFoundation

struct VoiceTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Preloaded data for faster initialization
    var preloadedCategories: [Category] = []

    @State private var parsedTransaction: ParsedTransaction?
    @State private var selectedCategory: Category?
    @State private var categories: [Category] = []
    @State private var showPermissionAlert: Bool = false
    @State private var permissionMessage: String = String(localized: "voice.permission_message")
    @State private var showSaveErrorAlert: Bool = false
    @State private var saveErrorMessage: String = ""
    @State private var isProcessing: Bool = false
    @State private var waveformPhase: CGFloat = 0
    @State private var isLoadingCategories: Bool = true
    @State private var isListening: Bool = false
    @State private var recognizedText: String = ""
    @State private var selectedCurrency: Currency = CurrencySettings.shared.defaultCurrency

    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let successFeedback = UINotificationFeedbackGenerator()
    private let voiceService = VoiceTransactionService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Waveform animation
                waveformView

                // Status text
                statusText

                // Recognized text display
                if !recognizedText.isEmpty {
                    recognizedTextView
                }

                // Parsed result
                if let parsed = parsedTransaction, parsed.isValid {
                    parsedResultView(parsed)
                }

                Spacer()

                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle(String(localized: "voice.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        voiceService.stopListening()
                        isListening = false
                        dismiss()
                    }
                }
            }
            .task {
                await loadCategoriesAsync()
                await checkAuthorization()
            }
            .alert(String(localized: "voice.permission_required"), isPresented: $showPermissionAlert) {
                Button(String(localized: "common.ok")) {
                    dismiss()
                }
            } message: {
                Text(permissionMessage)
            }
            .alert(String(localized: "error.save_failed"), isPresented: $showSaveErrorAlert) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Subviews

    private var waveformView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(isListening ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                .frame(width: 160, height: 160)

            // Animated waves
            if isListening {
                ForEach(0..<3) { index in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                        .frame(width: 160 + CGFloat(index) * 30, height: 160 + CGFloat(index) * 30)
                        .scaleEffect(1 + sin(waveformPhase + Double(index) * 0.5) * 0.1)
                }
            }

            // Microphone icon
            Image(systemName: isListening ? "waveform" : "mic.fill")
                .font(.system(size: 50))
                .foregroundStyle(isListening ? Color.accentColor : .secondary)
                .symbolEffect(.variableColor, isActive: isListening)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                waveformPhase = .pi * 2
            }
        }
    }

    private var statusText: some View {
        Text(isListening
             ? String(localized: "voice.listening")
             : String(localized: "voice.tap_to_start"))
            .font(.headline)
            .foregroundStyle(isListening ? Color.accentColor : .secondary)
    }

    private var recognizedTextView: some View {
        VStack(spacing: 8) {
            Text(String(localized: "voice.recognized"))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recognizedText)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    private func parsedResultView(_ parsed: ParsedTransaction) -> some View {
        VStack(spacing: 16) {
            Divider()

            Text(String(localized: "voice.parsed_result"))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                // Amount
                if let amount = parsed.amount {
                    HStack {
                        Text(String(localized: "transactions.amount"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(selectedCurrency.format(amount))
                            .font(.title2.bold())
                            .foregroundStyle(parsed.type == .income ? .green : .primary)
                    }
                }

                // Type
                HStack {
                    Text(String(localized: "transactions.type.expense"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(parsed.type == .income
                         ? String(localized: "transactions.type.income")
                         : String(localized: "transactions.type.expense"))
                        .foregroundStyle(parsed.type == .income ? .green : .red)
                }

                // Category
                if let category = selectedCategory {
                    HStack {
                        Text(String(localized: "transactions.category"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(category.name, systemImage: category.icon)
                            .foregroundStyle(category.color)
                    }
                }

                // Date
                if let date = parsed.date {
                    HStack {
                        Text(String(localized: "transactions.date"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Main action button (Listen or Save)
            if let parsed = parsedTransaction, parsed.isValid, !isListening {
                Button {
                    saveTransaction(parsed)
                } label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text(String(localized: "common.save"))
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isProcessing)
            }

            // Listen/Stop button
            Button {
                toggleListening()
            } label: {
                HStack {
                    Image(systemName: isListening ? "stop.circle.fill" : "mic.circle.fill")
                    Text(isListening
                         ? String(localized: "voice.stop")
                         : String(localized: "voice.start"))
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isListening ? Color.red : Color(.systemGray5))
                .foregroundStyle(isListening ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }

    // MARK: - Private Methods

    @MainActor
    private func loadCategoriesAsync() async {
        let preloader = AppDataPreloader.shared

        // Use preloaded categories if available, otherwise fetch
        if !preloadedCategories.isEmpty {
            categories = preloadedCategories
        } else if !preloader.categories.isEmpty {
            categories = preloader.categories
        } else {
            let repository = CategoryRepository(modelContext: modelContext)
            categories = (try? repository.fetchAll()) ?? []
            preloader.updateCategories(categories)
        }
        isLoadingCategories = false
    }

    private func checkAuthorization() async {
        let authorized = await voiceService.requestAuthorization()
        if !authorized {
            permissionMessage = String(localized: "voice.permission_message")
            showPermissionAlert = true
        }
    }

    private func toggleListening() {
        haptic.impactOccurred()

        if isListening {
            voiceService.stopListening()
            isListening = false
        } else {
            guard voiceService.isAuthorized else {
                permissionMessage = String(localized: "voice.permission_message")
                showPermissionAlert = true
                return
            }

            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                break
            case .denied:
                permissionMessage = String(localized: "voice.permission_message")
                showPermissionAlert = true
                return
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    Task { @MainActor in
                        if granted {
                            toggleListening()
                        } else {
                            permissionMessage = String(localized: "voice.permission_message")
                            showPermissionAlert = true
                        }
                    }
                }
                return
            @unknown default:
                permissionMessage = String(localized: "voice.permission_message")
                showPermissionAlert = true
                return
            }

            Task {
                do {
                    try await voiceService.startListening()
                    isListening = true
                    // Poll for recognized text updates
                    await pollRecognizedText()
                } catch {
                    isListening = false
                }
            }
        }
    }

    private func pollRecognizedText() async {
        while isListening {
            let currentText = voiceService.recognizedText
            if currentText != recognizedText {
                recognizedText = currentText
                if !currentText.isEmpty {
                    parsedTransaction = voiceService.parseVoiceInput(currentText)
                    updateSelectedCategory()
                }
            }
            // Check if service stopped listening
            if !voiceService.isListening {
                isListening = false
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms polling
        }
    }

    private func updateSelectedCategory() {
        guard let keyword = parsedTransaction?.suggestedCategoryKeyword else {
            selectedCategory = nil
            return
        }

        // Map keyword to icon (icon is language-independent)
        let categoryIconMap: [String: String] = [
            "food": "fork.knife",
            "shopping": "bag.fill",
            "transport": "car.fill",
            "housing": "house.fill",
            "telecom": "phone.fill",
            "medical": "cross.case.fill",
            "education": "book.fill",
            "entertainment": "gamecontroller.fill",
            "salary": "banknote.fill",
            "side_income": "plus.circle.fill",
            "investment": "chart.line.uptrend.xyaxis"
        ]

        // Match by icon (language-independent)
        if let icon = categoryIconMap[keyword] {
            selectedCategory = categories.first { $0.icon == icon }
        }

        // If no category found, try to match by type
        if selectedCategory == nil, let parsed = parsedTransaction {
            selectedCategory = categories.first { $0.type == parsed.type }
        }
    }

    private func saveTransaction(_ parsed: ParsedTransaction) {
        guard let amount = parsed.amount else { return }

        isProcessing = true
        defer { isProcessing = false }

        let repository = TransactionRepository(modelContext: modelContext)
        do {
            _ = try repository.create(
                amount: amount,
                type: parsed.type,
                category: selectedCategory,
                note: parsed.note ?? recognizedText,
                date: parsed.date ?? Date(),
                currency: selectedCurrency,
                receiptImageData: nil,
                tagNames: []
            )
            successFeedback.notificationOccurred(.success)
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveErrorAlert = true
        }
    }
}

#Preview {
    VoiceTransactionView()
        .modelContainer(for: [Transaction.self, Category.self], inMemory: true)
}
