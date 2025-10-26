//
//  ABCViewModel.swift
//  BCBATracker
//
//  ViewModel for ABC (Antecedent-Behavior-Consequence) recording sessions
//

import Foundation
import SwiftUI
import Combine
import CoreData

@MainActor
class ABCViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var sessionData: ABCData
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
        self.sessionData = ABCData()
    }

    // MARK: - Session Management

    /// Start a new ABC recording session
    func startSession() {
        sessionData = ABCData(startTime: Date())
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

    // MARK: - Observation Management

    /// Add a new ABC observation
    func addObservation(
        antecedent: String,
        behavior: String,
        consequence: String,
        setting: String? = nil,
        duration: TimeInterval? = nil,
        intensity: ABCData.ABCObservation.Intensity? = nil
    ) {
        guard isSessionActive else { return }

        let observation = ABCData.ABCObservation(
            timestamp: Date(),
            antecedent: antecedent,
            behavior: behavior,
            consequence: consequence,
            setting: setting,
            duration: duration,
            intensity: intensity
        )

        sessionData.observations.append(observation)
        HapticManager.lightImpact()
    }

    /// Update an existing observation
    func updateObservation(
        at index: Int,
        antecedent: String? = nil,
        behavior: String? = nil,
        consequence: String? = nil,
        setting: String? = nil,
        duration: TimeInterval? = nil,
        intensity: ABCData.ABCObservation.Intensity? = nil
    ) {
        guard index >= 0 && index < sessionData.observations.count else { return }

        var observation = sessionData.observations[index]

        if let antecedent = antecedent {
            observation.antecedent = antecedent
        }
        if let behavior = behavior {
            observation.behavior = behavior
        }
        if let consequence = consequence {
            observation.consequence = consequence
        }
        if let setting = setting {
            observation.setting = setting
        }
        if let duration = duration {
            observation.duration = duration
        }
        if let intensity = intensity {
            observation.intensity = intensity
        }

        sessionData.observations[index] = observation
    }

    /// Delete a specific observation
    func deleteObservation(at index: Int) {
        guard index >= 0 && index < sessionData.observations.count else { return }
        sessionData.observations.remove(at: index)
        HapticManager.softImpact()
    }

    // MARK: - Data Persistence

    /// Save session to Core Data
    func saveSession(location: String, notes: String? = nil) async throws {
        guard sessionData.count > 0 else {
            throw ABCError.noDataToSave
        }

        let context = dataManager.viewContext

        // Create Session entity
        let session = Session(context: context)
        session.id = UUID()
        session.startTime = sessionData.startTime
        session.endTime = sessionData.endTime ?? Date()
        session.type = "abc"
        session.location = location
        session.notes = notes ?? sessionData.notes
        session.student = student
        session.program = program

        // Encode ABC data as JSON
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
        sessionData = ABCData()
        isSessionActive = false
        HapticManager.rigidImpact()
    }

    // MARK: - Validation

    /// Check if session has unsaved data
    var hasUnsavedData: Bool {
        isSessionActive && sessionData.count > 0
    }

    /// Check if an observation is complete
    func isObservationComplete(_ observation: ABCData.ABCObservation) -> Bool {
        !observation.antecedent.isEmpty &&
        !observation.behavior.isEmpty &&
        !observation.consequence.isEmpty
    }
}

// MARK: - Errors

enum ABCError: LocalizedError {
    case noDataToSave

    var errorDescription: String? {
        switch self {
        case .noDataToSave:
            return "No ABC observations recorded. Record at least one observation before saving."
        }
    }
}
