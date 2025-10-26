//
//  Constants.swift
//  BCBATracker
//
//  App-wide constants and configuration values
//

import Foundation
import SwiftUI

/// App-wide constants
enum Constants {

    // MARK: - App Information
    enum App {
        static let name = "BCBA Behavior Tracker"
        static let bundleId = "com.bcba.tracker"
        static let version = "1.0.0"
        static let buildNumber = "1"
    }

    // MARK: - Google Drive Configuration
    enum GoogleDrive {
        // Google OAuth Client ID from Google Cloud Console
        // Get from: https://console.cloud.google.com/apis/credentials
        static let clientID = "984583875270-86oivq4d797drjs1kjgai5jr550ul2il.apps.googleusercontent.com"

        // Google Drive folder where backups are stored
        static let backupFolderName = "BCBA Tracker Backups"

        // Backup file naming
        static let backupFilePrefix = "bcba_backup_"
        static let backupFileExtension = "json"

        // Schema version for backward compatibility
        static let currentSchemaVersion = 1

        // OAuth scopes needed
        static let scopes = [
            "https://www.googleapis.com/auth/drive.file",  // Create/access app-created files
            "https://www.googleapis.com/auth/drive.appdata" // App data folder
        ]

        // Maximum number of backups to keep
        static let maxBackupsToKeep = 10
    }

    // MARK: - Security
    enum Security {
        static let keychainService = "com.bcba.tracker"
        static let sessionTimeout: TimeInterval = 900 // 15 minutes
        static let maxAuthAttempts = 3
    }

    // MARK: - Data Limits
    enum DataLimits {
        static let maxTargetsPerStudent = 25
        static let minTargetsPerStudent = 1
        static let maxStudentsPerTeacher = 100
        static let maxSessionDuration: TimeInterval = 28800 // 8 hours
        static let maxNotesLength = 1000
        static let maxNameLength = 100
    }

    // MARK: - UI Configuration
    enum UI {
        // Touch targets (WCAG compliant)
        static let minTouchTarget: CGFloat = 44
        static let preferredTouchTarget: CGFloat = 56

        // Spacing
        static let paddingSmall: CGFloat = 8
        static let paddingMedium: CGFloat = 16
        static let paddingLarge: CGFloat = 24
        static let paddingXLarge: CGFloat = 32

        // Corner radius
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16

        // Animation
        static let animationDuration: TimeInterval = 0.3
        static let animationSpring: CGFloat = 0.8
    }

    // MARK: - Colors
    enum Colors {
        // Brand colors
        static let primary = Color.blue
        static let secondary = Color.indigo
        static let accent = Color.green

        // Semantic colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue

        // Behavior types
        static let targetBehavior = Color.blue
        static let replacementBehavior = Color.green
        static let interferingBehavior = Color.red
        static let skillAcquisition = Color.purple
    }

    // MARK: - Icons
    enum Icons {
        // Session types
        static let frequency = "number.circle.fill"
        static let duration = "timer"
        static let abc = "list.bullet.clipboard"
        static let interval = "clock.arrow.2.circlepath"
        static let dtt = "checkmark.square.fill"
        static let taskAnalysis = "list.number"

        // Actions
        static let add = "plus.circle.fill"
        static let edit = "pencil"
        static let delete = "trash"
        static let save = "checkmark.circle.fill"
        static let cancel = "xmark.circle.fill"
        static let export = "square.and.arrow.up"
        static let sync = "arrow.triangle.2.circlepath"

        // Navigation
        static let students = "person.3.fill"
        static let sessions = "chart.bar.fill"
        static let settings = "gear"
        static let help = "questionmark.circle"

        // Data
        static let chart = "chart.line.uptrend.xyaxis"
        static let note = "note.text"
        static let calendar = "calendar"
        static let location = "location.fill"
    }

    // MARK: - Date Formats
    enum DateFormat {
        static let fullDate = "EEEE, MMMM d, yyyy"
        static let shortDate = "MM/dd/yyyy"
        static let time = "h:mm a"
        static let dateTime = "MM/dd/yyyy h:mm a"
        static let timestamp = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    }

    // MARK: - Defaults
    enum Defaults {
        static let defaultGrade: Int16 = 1
        static let defaultSessionLocation = "Classroom"
        static let defaultIntervalDuration: TimeInterval = 60 // 1 minute
    }

    // MARK: - Notifications
    enum Notifications {
        static let studentCreated = "studentCreated"
        static let sessionStarted = "sessionStarted"
        static let sessionEnded = "sessionEnded"
        static let behaviorRecorded = "behaviorRecorded"
        static let syncCompleted = "syncCompleted"
    }

    // MARK: - User Defaults Keys
    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let preferredSessionType = "preferredSessionType"
        static let enableHaptics = "enableHaptics"
        static let autoSyncEnabled = "autoSyncEnabled"
        static let lastSyncDate = "lastSyncDate"
        static let currentTeacherId = "currentTeacherId"
    }

    // MARK: - Accessibility
    enum Accessibility {
        static let minimumContrastRatio: CGFloat = 4.5 // WCAG AA standard
        static let largeTextMinimumContrast: CGFloat = 3.0 // WCAG AA for large text
    }

    // MARK: - Export
    enum Export {
        static let csvFileName = "bcba_data_export"
        static let pdfFileName = "bcba_report"
        static let jsonFileName = "bcba_backup"
        static let dateFormat = "yyyy-MM-dd_HHmmss"
    }

    // MARK: - URLs
    enum URLs {
        static let privacyPolicy = URL(string: "https://bcbatracker.com/privacy")!
        static let termsOfService = URL(string: "https://bcbatracker.com/terms")!
        static let support = URL(string: "https://bcbatracker.com/support")!
        static let documentation = URL(string: "https://bcbatracker.com/docs")!
    }
}
