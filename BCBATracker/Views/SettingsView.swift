//
//  SettingsView.swift
//  BCBATracker
//
//  Settings screen with Google Drive backup/restore functionality
//

import SwiftUI

struct AppSettingsView: View {

    // MARK: - Environment
    @EnvironmentObject var googleDriveManager: GoogleDriveManager
    @EnvironmentObject var exportManager: ExportManager
    @Environment(\.dismiss) var dismiss

    // MARK: - State
    @State private var showingBackupConfirmation = false
    @State private var showingRestoreSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var successMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Google Drive Section
                Section {
                    if googleDriveManager.isSignedIn {
                        // Signed In State
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Constants.Colors.success)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Signed in as")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text(googleDriveManager.userEmail ?? "Unknown")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Button("Sign Out") {
                                signOut()
                            }
                            .font(.subheadline)
                            .foregroundColor(Constants.Colors.error)
                        }
                    } else {
                        // Signed Out State
                        Button(action: signIn) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.title3)

                                Text("Sign in to Google Drive")
                                    .fontWeight(.semibold)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Google Drive Backup")
                } footer: {
                    Text("Sign in to back up and restore your data to Google Drive. Your data is stored in your personal Google Drive account.")
                }

                // MARK: - Backup Section
                if googleDriveManager.isSignedIn {
                    Section {
                        // Backup Button
                        Button(action: { showingBackupConfirmation = true }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.title3)
                                    .foregroundColor(Constants.Colors.primary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Backup to Google Drive")
                                        .fontWeight(.semibold)

                                    if googleDriveManager.availableBackups.first != nil {
                                        Text("Last backup: \(formatDate(googleDriveManager.availableBackups.first!.createdAt))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if googleDriveManager.isUploading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(googleDriveManager.isUploading)

                        // Restore Button
                        Button(action: { showingRestoreSheet = true }) {
                            HStack {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.title3)
                                    .foregroundColor(Constants.Colors.accent)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Restore from Google Drive")
                                        .fontWeight(.semibold)

                                    if !googleDriveManager.availableBackups.isEmpty {
                                        Text("\(googleDriveManager.availableBackups.count) backup(s) available")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                if googleDriveManager.isDownloading {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(googleDriveManager.isDownloading || googleDriveManager.availableBackups.isEmpty)

                    } header: {
                        Text("Backup & Restore")
                    } footer: {
                        Text("Create a backup of all your student data, programs, and sessions. Backups are stored as JSON files in your Google Drive.")
                    }
                }

                // MARK: - App Information Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Constants.App.version)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Build")
                        Spacer()
                        Text(Constants.App.buildNumber)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("App Information")
                }

                // MARK: - Support Section
                Section {
                    Link(destination: Constants.URLs.documentation) {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("Documentation")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: Constants.URLs.support) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                            Text("Support")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link(destination: Constants.URLs.privacyPolicy) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Support & Legal")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Create Backup?", isPresented: $showingBackupConfirmation, titleVisibility: .visible) {
                Button("Backup Now") {
                    performBackup()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will create a new backup of all your data and upload it to Google Drive.")
            }
            .sheet(isPresented: $showingRestoreSheet) {
                RestoreBackupSheet()
                    .environmentObject(googleDriveManager)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {}
            } message: {
                Text(successMessage)
            }
        }
        .task {
            if googleDriveManager.isSignedIn {
                await fetchBackups()
            }
        }
    }

    // MARK: - Actions

    private func signIn() {
        Task {
            do {
                try await googleDriveManager.signIn()
                await fetchBackups()
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                HapticManager.error()
            }
        }
    }

    private func signOut() {
        googleDriveManager.signOut()
        HapticManager.success()
    }

    private func performBackup() {
        Task {
            do {
                let metadata = try await googleDriveManager.uploadBackup()
                successMessage = "Backup completed successfully!\n\(metadata.displayName)"
                showingSuccess = true
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                HapticManager.error()
            }
        }
    }

    private func fetchBackups() async {
        do {
            try await googleDriveManager.fetchAvailableBackups()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Restore Backup Sheet

struct RestoreBackupSheet: View {
    @EnvironmentObject var googleDriveManager: GoogleDriveManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedBackup: BackupMetadata?
    @State private var showingConfirmation = false
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List(googleDriveManager.availableBackups) { backup in
                BackupRow(backup: backup, isSelected: selectedBackup?.id == backup.id)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedBackup = backup
                        showingConfirmation = true
                    }
            }
            .navigationTitle("Restore Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if googleDriveManager.availableBackups.isEmpty {
                    ContentUnavailableView {
                        Label("No Backups", systemImage: "icloud.slash")
                    } description: {
                        Text("You don't have any backups yet. Create a backup to get started.")
                    }
                }
            }
            .confirmationDialog("Restore Backup?", isPresented: $showingConfirmation, titleVisibility: .visible) {
                Button("Restore") {
                    if let backup = selectedBackup {
                        performRestore(backup)
                    }
                }
                Button("Delete Backup", role: .destructive) {
                    if let backup = selectedBackup {
                        deleteBackup(backup)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let backup = selectedBackup {
                    Text("This will merge \(backup.studentCount) students, \(backup.sessionCount) sessions, and \(backup.behaviorCount) behaviors with your current data.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func performRestore(_ backup: BackupMetadata) {
        Task {
            do {
                try await googleDriveManager.downloadAndRestoreBackup(backup)
                HapticManager.success()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                HapticManager.error()
            }
        }
    }

    private func deleteBackup(_ backup: BackupMetadata) {
        Task {
            do {
                try await googleDriveManager.deleteBackup(backup)
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
                HapticManager.error()
            }
        }
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: BackupMetadata
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.displayName)
                        .font(.headline)

                    Text("\(backup.studentCount) students • \(backup.sessionCount) sessions • \(backup.behaviorCount) behaviors")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Constants.Colors.primary)
                }
            }

            HStack {
                Label(backup.deviceName, systemImage: "iphone")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(backup.formattedFileSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview("Settings - Signed Out") {
    AppSettingsView()
        .environmentObject(GoogleDriveManager.shared)
        .environmentObject(ExportManager.shared)
}

#Preview("Settings - Signed In") {
    let manager = GoogleDriveManager.shared
    // Simulate signed-in state for preview
    AppSettingsView()
        .environmentObject(manager)
        .environmentObject(ExportManager.shared)
        .onAppear {
            // Note: Preview simulation only
            manager.isSignedIn = true
            manager.userEmail = "teacher@example.com"
        }
}

#Preview("Restore Backup Sheet") {
    RestoreBackupSheet()
        .environmentObject(GoogleDriveManager.shared)
}
