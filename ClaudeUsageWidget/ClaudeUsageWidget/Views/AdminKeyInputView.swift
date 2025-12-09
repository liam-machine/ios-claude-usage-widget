import SwiftUI

struct AdminKeyInputView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var isValidating: Bool = false
    @State private var validationState: ValidationState = .idle
    @State private var errorMessage: String = ""

    private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    private let retroBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

    enum ValidationState {
        case idle
        case validating
        case success
        case error
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("Admin API Key Required")
                    .font(.system(.title2, design: .monospaced))
                    .foregroundColor(retroGray)
                    .fontWeight(.semibold)

                Text("Enter your Anthropic Admin API key to access team usage data")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Key Input Section
            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.6))

                SecureField("sk-ant-admin...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disabled(isValidating)
                    .accessibilityLabel("Admin API Key")
                    .accessibilityHint("Enter your Anthropic Admin API key starting with sk-ant-admin")

                // Validation indicator
                if validationState != .idle {
                    HStack(spacing: 6) {
                        switch validationState {
                        case .validating:
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                            Text("Validating...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(retroGray.opacity(0.6))
                        case .success:
                            Text("✓")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                            Text("Key validated successfully")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.green)
                        case .error:
                            Text("✗")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.red)
                        case .idle:
                            EmptyView()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }

                // Help text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Requirements:")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.5))

                    Text("• Must start with 'sk-ant-admin'")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.5))

                    Text("• Get yours at console.anthropic.com")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(retroGray.opacity(0.5))
                }
                .padding(.top, 4)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 12) {
                Button("Back") {
                    dismiss()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(retroGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(retroBorder, lineWidth: 1)
                )
                .disabled(isValidating)
                .accessibilityLabel("Go back")
                .accessibilityHint("Returns to the setup screen")

                Button("Test Connection") {
                    testApiKey()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isValidKey && !isValidating ? Color.blue.opacity(0.7) : retroGray.opacity(0.3))
                .disabled(!isValidKey || isValidating)
                .accessibilityLabel("Test API key connection")
                .accessibilityHint("Validates the API key by connecting to Anthropic's API")

                Button("Continue") {
                    saveAndContinue()
                }
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(canContinue ? retroGray : retroGray.opacity(0.3))
                .disabled(!canContinue)
                .accessibilityLabel("Continue with this API key")
                .accessibilityHint("Saves the API key and completes setup")
            }
        }
        .padding(24)
        .frame(width: 500, height: 400)
        .background(retroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(retroBorder, lineWidth: 2)
        )
        .onAppear {
            // Pre-fill if key exists
            apiKey = settings.adminApiKey
        }
    }

    // MARK: - Computed Properties

    private var isValidKey: Bool {
        apiKey.hasPrefix("sk-ant-admin") && apiKey.count > 20
    }

    private var canContinue: Bool {
        isValidKey && (validationState == .success || !apiKey.isEmpty)
    }

    // MARK: - Actions

    private func testApiKey() {
        guard isValidKey else { return }

        isValidating = true
        validationState = .validating
        errorMessage = ""

        // Simulate API validation (replace with actual API call in production)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // For now, just validate the format
            // In production, make actual API call to test the key
            if apiKey.hasPrefix("sk-ant-admin") {
                validationState = .success
            } else {
                validationState = .error
                errorMessage = "Invalid key format"
            }
            isValidating = false
        }
    }

    private func saveAndContinue() {
        guard isValidKey else { return }
        settings.adminApiKey = apiKey
        dismiss()
    }
}

#Preview {
    AdminKeyInputView(settings: AppSettings.shared)
}
