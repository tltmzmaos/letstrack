import Foundation
import MessageUI
import SwiftUI

// MARK: - Feedback Type

enum FeedbackType: String, CaseIterable, Identifiable {
    case bugReport = "bug_report"
    case featureRequest = "feature_request"
    case generalFeedback = "general_feedback"
    case question = "question"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bugReport:
            return String(localized: "feedback.type.bug_report")
        case .featureRequest:
            return String(localized: "feedback.type.feature_request")
        case .generalFeedback:
            return String(localized: "feedback.type.general_feedback")
        case .question:
            return String(localized: "feedback.type.question")
        }
    }

    var icon: String {
        switch self {
        case .bugReport: return "ladybug"
        case .featureRequest: return "lightbulb"
        case .generalFeedback: return "bubble.left.and.bubble.right"
        case .question: return "questionmark.circle"
        }
    }

    var emailSubjectPrefix: String {
        switch self {
        case .bugReport: return "[Bug Report]"
        case .featureRequest: return "[Feature Request]"
        case .generalFeedback: return "[Feedback]"
        case .question: return "[Question]"
        }
    }
}

// MARK: - Feedback Service

@MainActor
final class FeedbackService: ObservableObject {
    static let shared = FeedbackService()
    static let supportEmail = "tltmzmaos@gmail.com"

    @Published var isShowingMailCompose = false
    @Published var mailResult: Result<MFMailComposeResult, Error>?

    private init() {}

    // MARK: - Email Composition

    var canSendEmail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    func createFeedbackEmailURL(
        type: FeedbackType,
        message: String,
        includeDeviceInfo: Bool = true,
        includeLogs: Bool = false
    ) -> URL? {
        var body = message

        if includeDeviceInfo {
            body += "\n\n" + deviceInfoSection()
        }

        if includeLogs {
            let recentLogs = LoggingService.shared.getRecentLogs(count: 20)
            if !recentLogs.isEmpty {
                body += "\n\n--- Recent Logs ---\n"
                body += recentLogs.map { $0.formattedString }.joined(separator: "\n\n")
            }
        }

        let subject = "\(type.emailSubjectPrefix) LetsTrack"
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        return URL(string: "mailto:\(Self.supportEmail)?subject=\(encodedSubject)&body=\(encodedBody)")
    }

    func createMailComposeData(
        type: FeedbackType,
        message: String,
        includeDeviceInfo: Bool = true,
        includeLogs: Bool = false
    ) -> MailComposeData {
        var body = message

        if includeDeviceInfo {
            body += "\n\n" + deviceInfoSection()
        }

        var attachments: [(Data, String, String)] = []

        if includeLogs {
            if let reportData = LoggingService.shared.generateReportData() {
                attachments.append((reportData, "text/plain", "diagnostic_report.txt"))
            }
        }

        return MailComposeData(
            recipients: [Self.supportEmail],
            subject: "\(type.emailSubjectPrefix) LetsTrack",
            body: body,
            isHTML: false,
            attachments: attachments
        )
    }

    // MARK: - Device Info

    private func deviceInfoSection() -> String {
        """
        --- Device Info ---
        App Version: \(appVersion)
        Build: \(buildNumber)
        iOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Device: \(deviceModel)
        Language: \(Locale.current.language.languageCode?.identifier ?? "Unknown")
        Region: \(Locale.current.region?.identifier ?? "Unknown")
        """
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var deviceModel: String {
        #if targetEnvironment(simulator)
        return "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #endif
    }
}

// MARK: - Mail Compose Data

struct MailComposeData {
    let recipients: [String]
    let subject: String
    let body: String
    let isHTML: Bool
    let attachments: [(Data, String, String)]  // (data, mimeType, fileName)
}

// MARK: - Mail Compose View (UIViewControllerRepresentable)

struct MailComposeView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let data: MailComposeData
    var onResult: ((Result<MFMailComposeResult, Error>) -> Void)?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(data.recipients)
        vc.setSubject(data.subject)
        vc.setMessageBody(data.body, isHTML: data.isHTML)

        for (attachmentData, mimeType, fileName) in data.attachments {
            vc.addAttachmentData(attachmentData, mimeType: mimeType, fileName: fileName)
        }

        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView

        init(_ parent: MailComposeView) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            if let error = error {
                parent.onResult?(.failure(error))
            } else {
                parent.onResult?(.success(result))
            }
            parent.dismiss()
        }
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var feedbackService = FeedbackService.shared

    @State private var selectedType: FeedbackType = .generalFeedback
    @State private var message: String = ""
    @State private var includeDeviceInfo: Bool = true
    @State private var includeLogs: Bool = false
    @State private var showingMailCompose: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(String(localized: "feedback.type"), selection: $selectedType) {
                        ForEach(FeedbackType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                Section(String(localized: "feedback.message")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                }

                Section {
                    Toggle(String(localized: "feedback.include_device_info"), isOn: $includeDeviceInfo)
                    Toggle(String(localized: "feedback.include_logs"), isOn: $includeLogs)
                } footer: {
                    Text(String(localized: "feedback.privacy_note"))
                }

                Section {
                    Button {
                        sendFeedback()
                    } label: {
                        HStack {
                            Spacer()
                            Label(String(localized: "feedback.send"), systemImage: "paperplane.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(String(localized: "feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMailCompose) {
                let data = feedbackService.createMailComposeData(
                    type: selectedType,
                    message: message,
                    includeDeviceInfo: includeDeviceInfo,
                    includeLogs: includeLogs
                )
                MailComposeView(data: data) { result in
                    handleMailResult(result)
                }
            }
            .alert(String(localized: "common.info"), isPresented: $showingAlert) {
                Button(String(localized: "common.ok")) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func sendFeedback() {
        if feedbackService.canSendEmail {
            showingMailCompose = true
        } else {
            // Fallback to mailto URL
            if let url = feedbackService.createFeedbackEmailURL(
                type: selectedType,
                message: message,
                includeDeviceInfo: includeDeviceInfo,
                includeLogs: includeLogs
            ) {
                UIApplication.shared.open(url)
            } else {
                alertMessage = String(localized: "feedback.error.cannot_send_email")
                showingAlert = true
            }
        }
    }

    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case .success(let mailResult):
            switch mailResult {
            case .sent:
                logInfo("Feedback sent successfully", category: "Feedback")
                dismiss()
            case .saved:
                alertMessage = String(localized: "feedback.saved")
                showingAlert = true
            case .cancelled:
                break
            case .failed:
                alertMessage = String(localized: "feedback.error.send_failed")
                showingAlert = true
            @unknown default:
                break
            }
        case .failure(let error):
            logError("Failed to send feedback", error: error, category: "Feedback")
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

#Preview {
    FeedbackView()
}
