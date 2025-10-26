//
//  GoogleDriveManager.swift
//  BCBATracker
//
//  Service for Google Drive authentication and file operations
//  Handles backup upload, download, and management
//

import Foundation
import GoogleSignIn
import GTMSessionFetcherCore
import OSLog
import Combine

/// Manager for Google Drive operations
@MainActor
class GoogleDriveManager: ObservableObject {

    // MARK: - Singleton
    static let shared = GoogleDriveManager()

    // MARK: - Published Properties
    @Published var isSignedIn = false
    @Published var userEmail: String?
    @Published var isUploading = false
    @Published var isDownloading = false
    @Published var uploadProgress: Double = 0.0
    @Published var downloadProgress: Double = 0.0
    @Published var availableBackups: [BackupMetadata] = []
    @Published var lastError: Error?

    // MARK: - Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bcba.tracker", category: "GoogleDriveManager")

    // MARK: - Private Properties
    private var currentUser: GIDGoogleUser?
    private let exportManager = ExportManager.shared

    // Base Google Drive API URL
    private let driveAPIBaseURL = "https://www.googleapis.com/drive/v3"
    private let uploadAPIBaseURL = "https://www.googleapis.com/upload/drive/v3"

    // MARK: - Initialization
    private init() {
        checkSignInStatus()
    }

    // MARK: - Authentication

    /// Check if user is already signed in
    func checkSignInStatus() {
        if let user = GIDSignIn.sharedInstance.currentUser {
            currentUser = user
            isSignedIn = true
            userEmail = user.profile?.email
            logger.info("User already signed in: \(self.userEmail ?? "unknown")")
        } else {
            isSignedIn = false
            currentUser = nil
            userEmail = nil
        }
    }

    /// Sign in to Google account
    func signIn() async throws {
        logger.info("Starting Google Sign-In")

        guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = await windowScene.windows.first?.rootViewController else {
            throw GoogleDriveError.noViewController
        }

        let configuration = GIDConfiguration(clientID: Constants.GoogleDrive.clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: rootViewController,
                hint: nil,
                additionalScopes: Constants.GoogleDrive.scopes
            )

            currentUser = result.user
            isSignedIn = true
            userEmail = result.user.profile?.email

            logger.info("Sign-In successful: \(self.userEmail ?? "unknown")")
        } catch {
            logger.error("Sign-In failed: \(error.localizedDescription)")
            throw GoogleDriveError.authenticationFailed(error.localizedDescription)
        }
    }

    /// Sign out from Google account
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isSignedIn = false
        userEmail = nil
        availableBackups = []
        logger.info("User signed out")
    }

    /// Refresh access token if needed
    private func refreshTokenIfNeeded() async throws {
        guard let user = currentUser else {
            throw GoogleDriveError.notSignedIn
        }

        // Check if token needs refresh
        if user.accessToken.expirationDate?.timeIntervalSinceNow ?? 0 < 300 { // 5 minutes buffer
            logger.info("Refreshing access token")
            try await user.refreshTokensIfNeeded()
        }
    }

    // MARK: - Backup Operations

    /// Upload backup to Google Drive
    func uploadBackup() async throws -> BackupMetadata {
        guard isSignedIn else {
            throw GoogleDriveError.notSignedIn
        }

        isUploading = true
        uploadProgress = 0.0
        defer {
            isUploading = false
            uploadProgress = 0.0
        }

        logger.info("Starting backup upload")

        // Refresh token if needed
        try await refreshTokenIfNeeded()

        // Export data to JSON
        uploadProgress = 0.2
        let fileURL = try await exportManager.exportToJSON()

        // Get or create backup folder
        uploadProgress = 0.3
        let folderId = try await getOrCreateBackupFolder()

        // Upload file
        uploadProgress = 0.5
        let driveFileId = try await uploadFile(fileURL: fileURL, toFolder: folderId)

        // Create metadata
        let fileData = try Data(contentsOf: fileURL)
        var metadata = BackupMetadata(
            studentCount: 0, // Will be populated from backup data
            sessionCount: 0,
            behaviorCount: 0,
            fileSizeBytes: fileData.count
        )
        metadata.driveFileId = driveFileId

        uploadProgress = 0.9

        // Clean up old backups
        try await cleanupOldBackups()

        uploadProgress = 1.0
        logger.info("Backup uploaded successfully: \(driveFileId)")

        // Refresh available backups
        try await fetchAvailableBackups()

        return metadata
    }

    /// Download and restore backup from Google Drive
    func downloadAndRestoreBackup(_ backup: BackupMetadata) async throws {
        guard isSignedIn else {
            throw GoogleDriveError.notSignedIn
        }

        guard let driveFileId = backup.driveFileId else {
            throw GoogleDriveError.invalidBackup
        }

        isDownloading = true
        downloadProgress = 0.0
        defer {
            isDownloading = false
            downloadProgress = 0.0
        }

        logger.info("Downloading backup: \(backup.displayName)")

        // Refresh token if needed
        try await refreshTokenIfNeeded()

        // Download file
        downloadProgress = 0.3
        let fileURL = try await downloadFile(driveFileId: driveFileId)

        // Import data
        downloadProgress = 0.6
        try await exportManager.importFromJSON(url: fileURL, strategy: .merge)

        downloadProgress = 1.0
        logger.info("Backup restored successfully")
    }

    /// Fetch list of available backups from Google Drive
    func fetchAvailableBackups() async throws {
        guard isSignedIn else {
            throw GoogleDriveError.notSignedIn
        }

        logger.info("Fetching available backups")

        try await refreshTokenIfNeeded()

        // Get backup folder
        let folderId = try await getOrCreateBackupFolder()

        // List files in backup folder
        let files = try await listFilesInFolder(folderId)

        // Parse metadata from files
        var backups: [BackupMetadata] = []

        for file in files {
            // Download and parse each backup to get metadata
            if let metadata = try? await fetchBackupMetadata(driveFileId: file.id) {
                backups.append(metadata)
            }
        }

        // Sort by date, newest first
        backups.sort { $0.createdAt > $1.createdAt }

        await MainActor.run {
            self.availableBackups = backups
        }

        logger.info("Found \(backups.count) available backups")
    }

    /// Delete a backup from Google Drive
    func deleteBackup(_ backup: BackupMetadata) async throws {
        guard isSignedIn else {
            throw GoogleDriveError.notSignedIn
        }

        guard let driveFileId = backup.driveFileId else {
            throw GoogleDriveError.invalidBackup
        }

        logger.info("Deleting backup: \(backup.displayName)")

        try await refreshTokenIfNeeded()

        try await deleteFile(driveFileId: driveFileId)

        // Refresh available backups
        try await fetchAvailableBackups()

        logger.info("Backup deleted successfully")
    }

    // MARK: - Private Google Drive API Methods

    /// Get or create the backup folder in Google Drive
    private func getOrCreateBackupFolder() async throws -> String {
        guard let accessToken = currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.noAccessToken
        }

        // Search for existing folder
        let query = "name='\(Constants.GoogleDrive.backupFolderName)' and mimeType='application/vnd.google-apps.folder' and trashed=false"
        let searchURL = "\(driveAPIBaseURL)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        var request = URLRequest(url: URL(string: searchURL)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(FileListResponse.self, from: data)

        // Return existing folder if found
        if let existingFolder = response.files.first {
            logger.info("Found existing backup folder: \(existingFolder.id)")
            return existingFolder.id
        }

        // Create new folder
        logger.info("Creating backup folder")

        let createURL = "\(driveAPIBaseURL)/files"
        var createRequest = URLRequest(url: URL(string: createURL)!)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let folderMetadata: [String: Any] = [
            "name": Constants.GoogleDrive.backupFolderName,
            "mimeType": "application/vnd.google-apps.folder"
        ]

        createRequest.httpBody = try JSONSerialization.data(withJSONObject: folderMetadata)

        let (createData, _) = try await URLSession.shared.data(for: createRequest)
        let folder = try JSONDecoder().decode(DriveFile.self, from: createData)

        logger.info("Created backup folder: \(folder.id)")
        return folder.id
    }

    /// Upload a file to Google Drive
    private func uploadFile(fileURL: URL, toFolder folderId: String) async throws -> String {
        guard let accessToken = currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.noAccessToken
        }

        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent

        // Create metadata
        let metadata: [String: Any] = [
            "name": fileName,
            "parents": [folderId]
        ]

        let metadataData = try JSONSerialization.data(withJSONObject: metadata)

        // Create multipart body
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        // Add metadata part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)

        // Add file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // End boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        // Create request
        let uploadURL = "\(uploadAPIBaseURL)/files?uploadType=multipart"
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: request)
        let file = try JSONDecoder().decode(DriveFile.self, from: data)

        return file.id
    }

    /// Download a file from Google Drive
    private func downloadFile(driveFileId: String) async throws -> URL {
        guard let accessToken = currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.noAccessToken
        }

        let downloadURL = "\(driveAPIBaseURL)/files/\(driveFileId)?alt=media"
        var request = URLRequest(url: URL(string: downloadURL)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)

        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("restore_\(UUID().uuidString).json")
        try data.write(to: tempURL)

        return tempURL
    }

    /// List files in a folder
    private func listFilesInFolder(_ folderId: String) async throws -> [DriveFile] {
        guard let accessToken = currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.noAccessToken
        }

        let query = "'\(folderId)' in parents and trashed=false"
        let listURL = "\(driveAPIBaseURL)/files?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&fields=files(id,name,createdTime,size)"

        var request = URLRequest(url: URL(string: listURL)!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(FileListResponse.self, from: data)

        return response.files
    }

    /// Delete a file from Google Drive
    private func deleteFile(driveFileId: String) async throws {
        guard let accessToken = currentUser?.accessToken.tokenString else {
            throw GoogleDriveError.noAccessToken
        }

        let deleteURL = "\(driveAPIBaseURL)/files/\(driveFileId)"
        var request = URLRequest(url: URL(string: deleteURL)!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GoogleDriveError.deleteFailed
        }
    }

    /// Fetch metadata for a specific backup
    private func fetchBackupMetadata(driveFileId: String) async throws -> BackupMetadata {
        let fileURL = try await downloadFile(driveFileId: driveFileId)

        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        var metadata = backupData.metadata
        metadata.driveFileId = driveFileId

        // Clean up temp file
        try? FileManager.default.removeItem(at: fileURL)

        return metadata
    }

    /// Clean up old backups, keeping only the most recent ones
    private func cleanupOldBackups() async throws {
        guard isSignedIn else { return }

        try await fetchAvailableBackups()

        guard availableBackups.count > Constants.GoogleDrive.maxBackupsToKeep else {
            return
        }

        // Sort by date, oldest first
        let sortedBackups = availableBackups.sorted { $0.createdAt < $1.createdAt }

        // Delete oldest backups beyond the limit
        let backupsToDelete = sortedBackups.prefix(sortedBackups.count - Constants.GoogleDrive.maxBackupsToKeep)

        for backup in backupsToDelete {
            do {
                try await deleteBackup(backup)
                logger.info("Cleaned up old backup: \(backup.displayName)")
            } catch {
                logger.error("Failed to delete old backup: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Google Drive Models

private struct DriveFile: Codable {
    let id: String
    let name: String?
    let createdTime: String?
    let size: String?
}

private struct FileListResponse: Codable {
    let files: [DriveFile]
}

// MARK: - Errors

enum GoogleDriveError: LocalizedError {
    case notSignedIn
    case noAccessToken
    case noViewController
    case authenticationFailed(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case deleteFailed
    case invalidBackup
    case folderNotFound

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "You must sign in to Google Drive first"
        case .noAccessToken:
            return "No access token available. Please sign in again."
        case .noViewController:
            return "Cannot present sign-in. No view controller available."
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .deleteFailed:
            return "Failed to delete backup"
        case .invalidBackup:
            return "Invalid backup data"
        case .folderNotFound:
            return "Backup folder not found"
        }
    }
}
