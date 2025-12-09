import SwiftUI

struct SetupView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode: UsageMode?
    @State private var showingAdminKeyInput = false
    @State private var isHoveringMode: UsageMode?

    private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
    private let retroBackground = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Welcome to Claude Usage")
                    .font(.system(.title, design: .monospaced))
                    .foregroundColor(retroGray)
                    .fontWeight(.bold)

                Text("How would you like to use this widget?")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(retroGray.opacity(0.7))
            }
            .padding(.top, 8)

            // Mode Selection Cards
            VStack(spacing: 12) {
                ForEach(UsageMode.allCases, id: \.self) { mode in
                    ModeCard(
                        mode: mode,
                        isSelected: selectedMode == mode,
                        isHovering: isHoveringMode == mode,
                        action: { selectMode(mode) }
                    )
                    .onHover { hovering in
                        isHoveringMode = hovering ? mode : nil
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(mode.displayName) mode")
                    .accessibilityHint(mode.description + (mode.details.isEmpty ? "" : ". " + mode.details))
                    .accessibilityAddTraits(selectedMode == mode ? [.isSelected, .isButton] : .isButton)
                }
            }

            Spacer()

            // Continue Button
            Button(action: handleContinue) {
                Text("Continue")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedMode != nil ? retroGray : retroGray.opacity(0.3))
            }
            .disabled(selectedMode == nil)
            .buttonStyle(.plain)
            .accessibilityLabel("Continue with selected mode")
            .accessibilityHint("Proceeds to the next step of setup")
        }
        .padding(24)
        .frame(width: 500, height: 550)
        .background(retroBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(retroBorder, lineWidth: 2)
        )
        .sheet(isPresented: $showingAdminKeyInput) {
            AdminKeyInputView(settings: settings)
                .onDisappear {
                    // Check if admin key was saved
                    if settings.hasAdminKey {
                        completeSetup()
                    }
                }
        }
    }

    // MARK: - Subviews

    struct ModeCard: View {
        let mode: UsageMode
        let isSelected: Bool
        let isHovering: Bool
        let action: () -> Void

        private let retroGray = Color(red: 0.75, green: 0.75, blue: 0.75)
        private let retroBorder = Color(red: 0.3, green: 0.3, blue: 0.3)

        var body: some View {
            Button(action: action) {
                HStack(spacing: 16) {
                    // Icon
                    Text(mode.icon)
                        .font(.system(size: 32))
                        .frame(width: 50)

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mode.displayName)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(retroGray)

                        Text(mode.description)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(retroGray.opacity(0.7))

                        if !mode.details.isEmpty {
                            Text(mode.details)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(retroGray.opacity(0.5))
                                .padding(.top, 2)
                        }
                    }

                    Spacer()

                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(retroGray.opacity(0.3))
                            .font(.system(size: 20))
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? retroBorder.opacity(0.3) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isSelected ? retroGray : (isHovering ? retroBorder.opacity(0.6) : retroBorder),
                            lineWidth: isSelected ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func selectMode(_ mode: UsageMode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMode = mode
        }
    }

    private func handleContinue() {
        guard let mode = selectedMode else { return }

        // If team or both mode selected, require admin key
        if mode == .team || mode == .both {
            showingAdminKeyInput = true
        } else {
            // Personal mode doesn't need admin key
            completeSetup()
        }
    }

    private func completeSetup() {
        guard let mode = selectedMode else { return }

        // Validate requirements
        if (mode == .team || mode == .both) && !settings.hasAdminKey {
            // Admin key required but not provided
            return
        }

        settings.completeSetup(mode: mode)
        dismiss()
    }
}

#Preview {
    SetupView(settings: AppSettings.shared)
}
