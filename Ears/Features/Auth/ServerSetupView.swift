//
//  ServerSetupView.swift
//  Ears
//
//  Server URL configuration with validation and discovery
//

import SwiftUI

/// First screen shown to new users to configure their Audiobookshelf server.
///
/// Features:
/// - URL validation and auto-correction
/// - Server discovery on local network (future)
/// - Clear error messaging
struct ServerSetupView: View {
    @Environment(AppState.self) private var appState

    @State private var serverURL = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showAdvanced = false

    @FocusState private var isURLFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Logo and welcome
                headerSection

                // URL input
                urlInputSection

                // Error message
                if let error = errorMessage {
                    errorView(error)
                }

                // Continue button
                continueButton

                Spacer(minLength: 40)

                // Help text
                helpSection
            }
            .padding(24)
        }
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            Text("Ears")
                .font(.largeTitle.bold())

            Text("Connect to your Audiobookshelf server to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - URL Input

    private var urlInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Server Address")
                .font(.headline)

            TextField("https://audiobooks.example.com", text: $serverURL)
                .textFieldStyle(.roundedBorder)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isURLFocused)
                .submitLabel(.continue)
                .onSubmit {
                    validateAndContinue()
                }

            Text("Enter the full URL of your Audiobookshelf server")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: validateAndContinue) {
            Group {
                if isValidating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Continue")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(serverURL.isEmpty || isValidating)
    }

    // MARK: - Help Section

    private var helpSection: some View {
        VStack(spacing: 12) {
            Text("Don't have a server?")
                .font(.subheadline.bold())

            Link(destination: URL(string: "https://www.audiobookshelf.org/")!) {
                Label("Learn about Audiobookshelf", systemImage: "safari")
            }
            .font(.subheadline)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func validateAndContinue() {
        isURLFocused = false
        errorMessage = nil

        // Normalize URL
        var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)

        // Add https if no scheme
        if !urlString.contains("://") {
            urlString = "https://\(urlString)"
        }

        // Remove trailing slash
        while urlString.hasSuffix("/") {
            urlString.removeLast()
        }

        // Validate URL format
        guard let url = URL(string: urlString),
              url.scheme != nil,
              url.host != nil else {
            errorMessage = "Please enter a valid URL"
            return
        }

        isValidating = true

        Task {
            do {
                // Test connection to server
                try await validateServer(url: url)

                // Success - save and continue
                appState.setServerURL(url)

            } catch {
                errorMessage = error.localizedDescription
            }

            isValidating = false
        }
    }

    private func validateServer(url: URL) async throws {
        // Try to reach the server's ping endpoint
        let pingURL = url.appendingPathComponent("/ping")
        var request = URLRequest(url: pingURL)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServerError.invalidResponse
        }

        // Check for valid response
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ServerError.serverError(httpResponse.statusCode)
        }

        // Optionally verify it's an Audiobookshelf server
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           success {
            // Valid Audiobookshelf server
            return
        }

        // Still accept if we got a 200
        if httpResponse.statusCode == 200 {
            return
        }

        throw ServerError.notAudiobookshelf
    }
}

// MARK: - Errors

enum ServerError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case notAudiobookshelf
    case connectionFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server returned error \(code)"
        case .notAudiobookshelf:
            return "This doesn't appear to be an Audiobookshelf server"
        case .connectionFailed:
            return "Could not connect to server. Check the URL and try again."
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ServerSetupView()
            .environment(AppState())
    }
}
