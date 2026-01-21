//
//  KeychainManager.swift
//  Ears
//
//  Secure storage for authentication tokens using the iOS Keychain
//

import Foundation
import Security

/// Manages secure storage of sensitive data in the iOS Keychain.
///
/// Used for storing:
/// - Authentication tokens
/// - Server credentials (if needed)
final class KeychainManager {
    // MARK: - Singleton

    static let shared = KeychainManager()

    // MARK: - Constants

    private let service = "com.ears.audiobookshelf"
    private let tokenKey = "authToken"

    // MARK: - Initialization

    private init() {}

    // MARK: - Token Management

    /// Store the authentication token
    func setToken(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        set(data, forKey: tokenKey)
    }

    /// Retrieve the authentication token
    func getToken() -> String? {
        guard let data = get(forKey: tokenKey) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Clear the authentication token
    func clearToken() {
        delete(forKey: tokenKey)
    }

    // MARK: - Generic Keychain Operations

    /// Store data in the Keychain
    private func set(_ data: Data, forKey key: String) {
        // First, delete any existing item
        delete(forKey: key)

        // Create the query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        // Add the item
        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("Keychain: Failed to store item for key '\(key)', status: \(status)")
        }
    }

    /// Retrieve data from the Keychain
    private func get(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    /// Delete data from the Keychain
    private func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        SecItemDelete(query as CFDictionary)
    }

    /// Clear all items stored by this app
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]

        SecItemDelete(query as CFDictionary)
    }
}
