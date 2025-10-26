//
//  FrequencyViewModel.swift
//  BCBATracker
//
//  ViewModel for frequency recording sessions
//

import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class FrequencyViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessionData: FrequencyData
    @Published var isSessionActive: Bool = false
    @Published var showingSaveConfirmation: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let dataManager = DataManager.shared

    // MARK: - Session Context
    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil) {
        self.student = student
        self.program = program
        self.sessionData = FrequencyData()
    }

    // MARK: - Session Management

    /// Start a new frequency recording session
    func startSession() {
        sessionData = FrequencyData(startTime: Date())
        isSessionActive = true
        HapticManager.mediumImpact()
    }

    /// End the current session
    func endSession() {
        sessionData.endTime = Date()
        isSessionActive = false
        showingSaveConfirmation = true
        HapticManager.mediumImpact()
    }

    // MARK: - Behavior Recording

    /// Record a behavior occurrence
    func recordBehavior() {
        guard isSessionActive else { return }

        let event = FrequencyData.BehaviorEvent(timestamp: Date())
        sessionData.behaviors.append(event)
        sessionData.count += 1

        HapticManager.lightImpact()
    }

    /// Undo the last recorded behavior
    func undoLastBehavior() {
        guard !sessionData.behaviors.isEmpty else { return }

        sessionData.behaviors.removeLast()
        sessionData.count = max(0, sessionData.count - 1)

        HapticManager.softImpact()
    }

    // MARK: - Data Persistence

    /// Save session to Core Data
    func saveSession(location: String, notes: String? = nil) async throws {
        guard sessionData.count > 0 else {
            throw FrequencyError.noDataToSave
        }

        let context = dataManager.viewContext

        // Create Session entity
        let session = Session(context: context)
        session.id = UUID()
        session.startTime = sessionData.startTime
        session.endTime = sessionData.endTime ?? Date()
        session.type = "frequency"
        session.location = location
        session.notes = notes ?? sessionData.notes
        session.student = student
        session.program = program

        // Encode frequency data as JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        session.data = try encoder.encode(sessionData)

        // Save context
        dataManager.save()

        // Post notification
        NotificationCenter.default.post(
            name: Notification.Name(Constants.Notifications.sessionEnded),
            object: nil,
            userInfo: ["sessionId": session.id]
        )

        HapticManager.success()
    }

    /// Discard current session without saving
    func discardSession() {
        sessionData = FrequencyData()
        isSessionActive = false
        HapticManager.rigidImpact()
    }

    // MARK: - Validation

    /// Check if session has unsaved data
    var hasUnsavedData: Bool {
        isSessionActive && sessionData.count > 0
    }
}

// MARK: - Errors

enum FrequencyError: LocalizedError {
    case noDataToSave

    var errorDescription: String? {
        switch self {
        case .noDataToSave:
            return "No behaviors recorded. Record at least one behavior before saving."
        }
    }
}
