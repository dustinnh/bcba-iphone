//
//  SecurityManager.swift
//  BCBATracker
//
//  Security service for encryption, authentication, and data protection
//  FERPA/COPPA compliant security implementation
//

import Foundation
import Combine
import LocalAuthentication
import CryptoKit
import Security
import OSLog

/// Security manager for the application
/// Handles biometric authentication and data encryption
@MainActor
class SecurityManager: ObservableObject {

    // MARK: - Singleton
    static let shared = SecurityManager()

    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var authenticationError: String?

    // MARK: - Constants
    private let keychainService = "com.bcba.tracker"
    private let encryptionKeyTag = "com.bcba.tracker.encryption.key"

    // MARK: - Logger
    private let logger = Logger.security

    // MARK: - Initialization
    private init() {
        logger.info("SecurityManager initialized")
    }

    // MARK: - Biometric Authentication

    /// Check if biometric authentication is available
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?

        let available = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        if let error = error {
            logger.debug("Biometric not available: \(error.localizedDescription)")
        }

        return available
    }

    /// Get biometric type (Face ID or Touch ID)
    func biometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    /// Authenticate user with biometrics
    func authenticateUser() async -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            logger.error("Cannot evaluate biometric policy: \(error?.localizedDescription ?? "unknown")")
            await MainActor.run {
                authenticationError = "Biometric authentication not available"
                isAuthenticated = false
            }
            return false
        }

        do {
            let biometricType = self.biometricType()
            let reason = "Authenticate to access student data"

            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            await MainActor.run {
                isAuthenticated = success
                authenticationError = nil
            }

            if success {
                logger.info("Authentication successful with \(biometricType.displayName)")
            }

            return success

        } catch let error {
            logger.error("Authentication failed: \(error.localizedDescription)")

            await MainActor.run {
                isAuthenticated = false
                authenticationError = error.localizedDescription
            }

            return false
        }
    }

    /// Authenticate with device passcode as fallback
    func authenticateWithPasscode() async -> Bool {
        let context = LAContext()
        let reason = "Authenticate to access student data"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,  // Includes passcode fallback
                localizedReason: reason
            )

            await MainActor.run {
                isAuthenticated = success
                authenticationError = nil
            }

            if success {
                logger.info("Authentication successful with passcode")
            }

            return success

        } catch let error {
            logger.error("Passcode authentication failed: \(error.localizedDescription)")

            await MainActor.run {
                isAuthenticated = false
                authenticationError = error.localizedDescription
            }

            return false
        }
    }

    /// Logout user
    func logout() {
        isAuthenticated = false
        logger.info("User logged out")
    }

    #if DEBUG
    /// Bypass authentication for development/testing (DEBUG builds only)
    func bypassAuthentication() {
        isAuthenticated = true
        authenticationError = nil
        logger.warning("⚠️ Authentication bypassed (DEBUG mode)")
    }
    #endif

    // MARK: - Data Encryption

    /// Get or create encryption key from Keychain
    private func getEncryptionKey() throws -> SymmetricKey {
        // Try to retrieve existing key
        if let keyData = try? retrieveFromKeychain(tag: encryptionKeyTag) {
            return SymmetricKey(data: keyData)
        }

        // Create new key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        // Store in Keychain
        try storeInKeychain(data: keyData, tag: encryptionKeyTag)

        logger.info("Created new encryption key")
        return key
    }

    /// Encrypt sensitive data
    func encrypt(_ data: Data) -> Data? {
        do {
            let key = try getEncryptionKey()
            let sealedBox = try AES.GCM.seal(data, using: key)

            guard let combined = sealedBox.combined else {
                logger.error("Failed to get combined sealed box data")
                return nil
            }

            logger.debug("Data encrypted successfully")
            return combined

        } catch {
            logger.error("Encryption failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decrypt encrypted data
    func decrypt(_ encryptedData: Data) -> Data? {
        do {
            let key = try getEncryptionKey()
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)

            logger.debug("Data decrypted successfully")
            return decryptedData

        } catch {
            logger.error("Decryption failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Encrypt string
    func encrypt(_ string: String) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        guard let encrypted = encrypt(data) else { return nil }
        return encrypted.base64EncodedString()
    }

    /// Decrypt string
    func decrypt(_ encryptedString: String) -> String? {
        guard let data = Data(base64Encoded: encryptedString) else { return nil }
        guard let decrypted = decrypt(data) else { return nil }
        return String(data: decrypted, encoding: .utf8)
    }

    // MARK: - Keychain Operations

    /// Store data in Keychain
    private func storeInKeychain(data: Data, tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            logger.error("Failed to store in Keychain: \(status)")
            throw KeychainError.storeFailed(status)
        }

        logger.debug("Stored data in Keychain with tag: \(tag)")
    }

    /// Retrieve data from Keychain
    private func retrieveFromKeychain(tag: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            logger.error("Failed to retrieve from Keychain: \(status)")
            throw KeychainError.retrieveFailed(status)
        }

        logger.debug("Retrieved data from Keychain with tag: \(tag)")
        return data
    }

    /// Delete data from Keychain
    func deleteFromKeychain(tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Failed to delete from Keychain: \(status)")
            throw KeychainError.deleteFailed(status)
        }

        logger.debug("Deleted data from Keychain with tag: \(tag)")
    }

    // MARK: - Audit Logging

    /// Log a security event
    func logSecurityEvent(_ event: SecurityEvent, details: String? = nil) {
        let message = details.map { "\(event.description): \($0)" } ?? event.description
        logger.notice("\(message)")
    }
}

// MARK: - Supporting Types

extension SecurityManager {
    /// Biometric authentication type
    enum BiometricType {
        case none
        case touchID
        case faceID
        case opticID

        var displayName: String {
            switch self {
            case .none: return "None"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            case .opticID: return "Optic ID"
            }
        }

        var iconName: String {
            switch self {
            case .none: return "lock.fill"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            case .opticID: return "opticid"
            }
        }
    }

    /// Security events for audit logging
    enum SecurityEvent {
        case authenticationSuccess
        case authenticationFailure
        case dataEncrypted
        case dataDecrypted
        case encryptionKeyCreated
        case logout

        var description: String {
            switch self {
            case .authenticationSuccess: return "Authentication succeeded"
            case .authenticationFailure: return "Authentication failed"
            case .dataEncrypted: return "Data encrypted"
            case .dataDecrypted: return "Data decrypted"
            case .encryptionKeyCreated: return "Encryption key created"
            case .logout: return "User logged out"
            }
        }
    }

    /// Keychain errors
    enum KeychainError: Error {
        case storeFailed(OSStatus)
        case retrieveFailed(OSStatus)
        case deleteFailed(OSStatus)

        var localizedDescription: String {
            switch self {
            case .storeFailed(let status):
                return "Failed to store in Keychain: \(status)"
            case .retrieveFailed(let status):
                return "Failed to retrieve from Keychain: \(status)"
            case .deleteFailed(let status):
                return "Failed to delete from Keychain: \(status)"
            }
        }
    }
}

// MARK: - Logger Extension
extension Logger {
    static let security = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bcba.tracker",
                                 category: "Security")
}
