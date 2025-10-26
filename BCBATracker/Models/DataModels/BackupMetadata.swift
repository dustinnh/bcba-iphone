//
//  BackupMetadata.swift
//  BCBATracker
//
//  Metadata for Google Drive backup files
//

import Foundation
import UIKit

/// Metadata for a backup stored in Google Drive
struct BackupMetadata: Codable, Identifiable {

    /// Unique identifier for the backup
    let id: String

    /// Date the backup was created
    let createdAt: Date

    /// App version that created the backup
    let appVersion: String

    /// Schema version for compatibility checking
    let schemaVersion: Int

    /// Device name that created the backup
    let deviceName: String

    /// Number of students in backup
    let studentCount: Int

    /// Number of sessions in backup
    let sessionCount: Int

    /// Number of behaviors recorded in backup
    let behaviorCount: Int

    /// Size of backup file in bytes
    let fileSizeBytes: Int

    /// Google Drive file ID
    var driveFileId: String?

    /// Display name for the backup
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Backup \(formatter.string(from: createdAt))"
    }

    /// Human-readable file size
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSizeBytes))
    }

    /// Create metadata for a new backup
    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        appVersion: String = Constants.App.version,
        schemaVersion: Int = Constants.GoogleDrive.currentSchemaVersion,
        deviceName: String = UIDevice.current.name,
        studentCount: Int,
        sessionCount: Int,
        behaviorCount: Int,
        fileSizeBytes: Int = 0,
        driveFileId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.schemaVersion = schemaVersion
        self.deviceName = deviceName
        self.studentCount = studentCount
        self.sessionCount = sessionCount
        self.behaviorCount = behaviorCount
        self.fileSizeBytes = fileSizeBytes
        self.driveFileId = driveFileId
    }
}

/// Complete backup data including metadata and actual data
struct BackupData: Codable {
    let metadata: BackupMetadata
    let students: [StudentBackup]
    let programs: [ProgramBackup]
    let sessions: [SessionBackup]
    let behaviors: [BehaviorBackup]
}

// MARK: - Backup Data Models

/// Student data for backup
struct StudentBackup: Codable {
    let id: String
    let firstName: String
    let lastInitial: String
    let grade: Int16
    let teacherId: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
}

/// Program data for backup
struct ProgramBackup: Codable {
    let id: String
    let name: String
    let type: String
    let targetBehaviors: [String]?
    let masteryCriteria: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let studentId: String
}

/// Session data for backup
struct SessionBackup: Codable {
    let id: String
    let type: String
    let startTime: Date
    let endTime: Date?
    let location: String?
    let notes: String?
    let data: Data?
    let studentId: String
    let programId: String?
}

/// Behavior data for backup
struct BehaviorBackup: Codable {
    let id: String
    let timestamp: Date
    let type: String
    let frequency: Int32
    let duration: Double
    let antecedent: String?
    let consequence: String?
    let interval: String?
    let promptLevel: String?
    let sessionId: String
}
