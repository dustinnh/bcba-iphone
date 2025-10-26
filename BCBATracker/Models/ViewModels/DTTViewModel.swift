//
//  DTTViewModel.swift
//  BCBATracker
//
//  ViewModel for DTT (Discrete Trial Training) sessions
//

import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class DTTViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessionData: DTTData
    @Published var isSessionActive: Bool = false
    @Published var currentTrialNumber: Int = 0
    @Published var showingSaveConfirmation: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies
    private let dataManager = DataManager.shared

    // MARK: - Session Context
    private let student: Student
    private let program: Program?

    // MARK: - Initialization
    init(student: Student, program: Program? = nil, target: String = "") {
        self.student = student
        self.program = program
        self.sessionData = DTTData(target: target)
    }

    // MARK: - Session Management

    /// Start a new DTT session
    func startSession(target: String) {
        sessionData = DTTData(
            startTime: Date(),
            target: target
        )
        isSessionActive = true
        currentTrialNumber = 0
        HapticManager.mediumImpact()
    }

    /// End the current session
    func endSession() {
        sessionData.endTime = Date()
        isSessionActive = false
        showingSaveConfirmation = true
        HapticManager.mediumImpact()
    }

    // MARK: - Trial Management

    /// Add a new trial with response and prompt level
    func addTrial(
        response: DTTData.DTTTrial.TrialResponse,
        promptLevel: DTTData.DTTTrial.PromptLevel,
        notes: String? = nil
    ) {
        guard isSessionActive else { return }

        currentTrialNumber += 1

        let trial = DTTData.DTTTrial(
            trialNumber: currentTrialNumber,
            timestamp: Date(),
            response: response,
            promptLevel: promptLevel,
            notes: notes
        )

        sessionData.trials.append(trial)

        // Provide different haptic feedback based on response
        switch response {
        case .correct:
            HapticManager.success()
        case .incorrect, .noResponse:
            HapticManager.softImpact()
        case .approximation:
            HapticManager.lightImpact()
        }
    }

    /// Delete the last trial
    func deleteLastTrial() {
        guard !sessionData.trials.isEmpty else { return }

        sessionData.trials.removeLast()
        currentTrialNumber = sessionData.trials.count

        HapticManager.softImpact()
    }

    /// Update the target skill
    func updateTarget(_ target: String) {
        sessionData.target = target
    }

    // MARK: - Data Persistence

    /// Save session to Core Data
    func saveSession(location: String, notes: String? = nil) async throws {
        guard !sessionData.target.isEmpty else {
            throw DTTError.noTargetSpecified
        }

        guard sessionData.totalTrials > 0 else {
            throw DTTError.noDataToSave
        }

        let context = dataManager.viewContext

        // Create Session entity
        let session = Session(context: context)
        session.id = UUID()
        session.startTime = sessionData.startTime
        session.endTime = sessionData.endTime ?? Date()
        session.type = "dtt"
        session.location = location
        session.notes = notes ?? sessionData.notes
        session.student = student
        session.program = program

        // Encode DTT data as JSON
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
        sessionData = DTTData(target: sessionData.target)
        isSessionActive = false
        currentTrialNumber = 0
        HapticManager.rigidImpact()
    }

    // MARK: - Validation

    /// Check if session has unsaved data
    var hasUnsavedData: Bool {
        isSessionActive && sessionData.totalTrials > 0
    }

    /// Check if target is specified
    var hasTarget: Bool {
        !sessionData.target.isEmpty
    }
}

// MARK: - Errors

enum DTTError: LocalizedError {
    case noDataToSave
    case noTargetSpecified

    var errorDescription: String? {
        switch self {
        case .noDataToSave:
            return "No trials recorded. Complete at least one trial before saving."
        case .noTargetSpecified:
            return "Please specify a target skill before starting the session."
        }
    }
}
