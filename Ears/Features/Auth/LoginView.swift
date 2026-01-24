//
//  LoginView.swift
//  Ears
//
//  User authentication view
//

import SwiftUI

/// Login screen for authenticating with the Audiobookshelf server.
///
/// Features:
/// - Username/password authentication
/// - Remember me option
/// - Secure password entry
/// - Clear error handling
struct LoginView: View {
    @Environment(AppState.self) private var appState

    @State private var username = ""
    @State private var password = ""
    @State private var rememberMe = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showPassword = false

    @FocusState private var focusedField: Field?

    enum Field {
        case username
        case password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Server info
                serverInfoSection

                // Login form
                loginFormSection

                // Error message
                if let error = errorMessage {
                    errorView(error)
                }

                // Login button
                loginButton

                // Change server
                changeServerButton
            }
            .padding(24)
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Load saved username if available
            if let savedUsername = UserDefaults.standard.string(forKey: "savedUsername") {
                username = savedUsername
                focusedField = .password
            } else {
                focusedField = .username
            }
        }
    }

    // MARK: - Server Info

    private var serverInfoSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            if let url = appState.serverURL {
                Text(url.host ?? url.absoluteString)
                    .font(.headline)

                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Login Form

    private var loginFormSection: some View {
        VStack(spacing: 16) {
            // Username
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.subheadline.bold())

                TextField("Enter your username", text: $username)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
                    .submitLabel(.next)
                    .onSubmit {
                        focusedField = .password
                    }
            }

            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.subheadline.bold())

                HStack {
                    Group {
                        if showPassword {
                            TextField("Enter your password", text: $password)
                        } else {
                            SecureField("Enter your password", text: $password)
                        }
                    }
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit {
                        login()
                    }

                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
            }

            // Remember me
            Toggle(isOn: $rememberMe) {
                Text("Remember username")
                    .font(.subheadline)
            }
            .tint(Color.accentColor)
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

    // MARK: - Login Button

    private var loginButton: some View {
        Button(action: login) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign In")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.borderedProminent)
        .disabled(username.isEmpty || password.isEmpty || isLoading)
    }

    // MARK: - Change Server

    private var changeServerButton: some View {
        Button {
            // Clear server URL to go back to setup
            appState.serverURL = nil
            UserDefaults.standard.removeObject(forKey: "serverURL")
        } label: {
            Text("Change Server")
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func login() {
        focusedField = nil
        errorMessage = nil
        isLoading = true

        Task {
            do {
                try await appState.login(username: username, password: password)

                // Save username if remember me is on
                if rememberMe {
                    UserDefaults.standard.set(username, forKey: "savedUsername")
                } else {
                    UserDefaults.standard.removeObject(forKey: "savedUsername")
                }

            } catch {
                errorMessage = error.localizedDescription
            }

            isLoading = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LoginView()
            .environment(AppState())
    }
}
