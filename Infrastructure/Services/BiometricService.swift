import Foundation
import LocalAuthentication
import SwiftUI

// MARK: - Biometric Type

enum BiometricType {
    case none
    case touchID
    case faceID

    var displayName: String {
        switch self {
        case .none:
            return String(localized: "biometric.none")
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "lock.fill"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        }
    }
}

// MARK: - Biometric Error

enum BiometricError: Error, LocalizedError {
    case notAvailable
    case notEnrolled
    case authenticationFailed
    case userCancelled
    case systemCancelled
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return String(localized: "biometric.error.not_available")
        case .notEnrolled:
            return String(localized: "biometric.error.not_enrolled")
        case .authenticationFailed:
            return String(localized: "biometric.error.authentication_failed")
        case .userCancelled:
            return String(localized: "biometric.error.user_cancelled")
        case .systemCancelled:
            return String(localized: "biometric.error.system_cancelled")
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Biometric Service

@MainActor
final class BiometricService {
    static let shared = BiometricService()

    // Cached biometric type - computed once at initialization
    private(set) var biometricType: BiometricType = .none
    private(set) var isBiometricAvailable: Bool = false

    private init() {
        // Cache biometric type at initialization to avoid repeated LAContext calls
        cacheBiometricType()
    }

    // MARK: - Biometric Type Check

    private func cacheBiometricType() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricType = .none
            isBiometricAvailable = false
            return
        }

        switch context.biometryType {
        case .touchID:
            biometricType = .touchID
        case .faceID:
            biometricType = .faceID
        case .opticID:
            biometricType = .faceID  // Treat opticID as faceID for simplicity
        case .none:
            biometricType = .none
        @unknown default:
            biometricType = .none
        }

        isBiometricAvailable = biometricType != .none
    }

    // MARK: - Authentication

    func authenticate() async -> Result<Void, BiometricError> {
        guard isBiometricAvailable else {
            return .failure(.notAvailable)
        }

        let context = LAContext()
        context.localizedCancelTitle = String(localized: "common.cancel")

        let reason = String(localized: "biometric.reason")

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                return .success(())
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }

    func authenticateWithPasscode() async -> Result<Void, BiometricError> {
        let context = LAContext()
        let reason = String(localized: "biometric.reason")

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                return .success(())
            } else {
                return .failure(.authenticationFailed)
            }
        } catch let error as LAError {
            return .failure(mapLAError(error))
        } catch {
            return .failure(.unknown(error))
        }
    }

    // MARK: - Private Methods

    private func mapLAError(_ error: LAError) -> BiometricError {
        switch error.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .authenticationFailed:
            return .authenticationFailed
        case .userCancel:
            return .userCancelled
        case .systemCancel:
            return .systemCancelled
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenView: View {
    @Binding var isLocked: Bool

    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var iconScale: CGFloat = 0.8
    @State private var hasAttemptedAuth: Bool = false
    @State private var isAuthenticating: Bool = false

    // Cache biometric info to avoid repeated LAContext calls
    private let biometricType: BiometricType = BiometricService.shared.biometricType

    var body: some View {
        ZStack {
            // Background blur effect
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Animated lock icon
                Image(systemName: isAuthenticating ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 70, weight: .light))
                    .foregroundStyle(isAuthenticating ? Color.accentColor : .secondary)
                    .scaleEffect(iconScale)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: iconScale)
                    .animation(.easeInOut(duration: 0.3), value: isAuthenticating)

                VStack(spacing: 8) {
                    Text(String(localized: "lock.title"))
                        .font(.title2.bold())

                    Text(String(localized: "lock.description"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    // Main unlock button
                    Button {
                        Task {
                            await authenticate()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: biometricType.icon)
                                    .font(.title3)
                            }
                            Text(isAuthenticating
                                 ? String(localized: "lock.authenticating")
                                 : String(localized: "lock.unlock_with \(biometricType.displayName)"))
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isAuthenticating)
                    .opacity(isAuthenticating ? 0.7 : 1.0)

                    // Passcode fallback button
                    Button {
                        Task {
                            await authenticateWithPasscode()
                        }
                    } label: {
                        Text(String(localized: "lock.use_passcode"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.vertical, 8)
                    }
                    .disabled(isAuthenticating)
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 60)
            }
            .padding()
        }
        .alert(String(localized: "biometric.error.title"), isPresented: $showError) {
            Button(String(localized: "biometric.error.retry")) {
                Task {
                    await authenticate()
                }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Animate icon on appear
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                iconScale = 1.0
            }

            // Auto-authenticate with a slight delay for smoother UX
            if !hasAttemptedAuth {
                hasAttemptedAuth = true
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                    await authenticate()
                }
            }
        }
    }

    private func authenticate() async {
        isAuthenticating = true
        let result = await BiometricService.shared.authenticate()
        isAuthenticating = false

        switch result {
        case .success:
            isLocked = false
        case .failure(let error):
            if case .userCancelled = error { return }
            if case .systemCancelled = error { return }
            errorMessage = error.errorDescription ?? String(localized: "error.unknown")
            showError = true
        }
    }

    private func authenticateWithPasscode() async {
        isAuthenticating = true
        let result = await BiometricService.shared.authenticateWithPasscode()
        isAuthenticating = false

        switch result {
        case .success:
            isLocked = false
        case .failure(let error):
            if case .userCancelled = error { return }
            if case .systemCancelled = error { return }
            errorMessage = error.errorDescription ?? String(localized: "error.unknown")
            showError = true
        }
    }
}
